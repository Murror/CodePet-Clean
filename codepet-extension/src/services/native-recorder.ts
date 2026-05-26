/**
 * Native audio recording via ffmpeg / sox with real-time level metering.
 *
 * Cursor's webview iframe blocks microphone access via Permissions-Policy, so
 * we record audio at the extension host (Node.js) level. PCM samples stream
 * through Node's stdout so we can compute RMS per chunk (for the UI's live
 * orb / waveform animation) AND accumulate the full PCM for the final WAV
 * blob sent to the STT provider.
 */
import * as cp from "child_process";
import { EventEmitter } from "events";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

export type RecorderTool = "ffmpeg" | "sox" | null;

export interface RecorderInfo {
  tool: RecorderTool;
  binPath?: string;
  searched: string[];
}

const EXTRA_SEARCH_DIRS = [
  "/opt/homebrew/bin",
  "/opt/homebrew/sbin",
  "/usr/local/bin",
  "/usr/local/sbin",
  "/opt/local/bin",
  "/usr/bin",
  "/bin",
  path.join(os.homedir(), ".local/bin"),
  path.join(os.homedir(), "bin"),
];

function existsExecutable(p: string): boolean {
  try {
    fs.accessSync(p, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function findBinary(name: string): { found: string | null; searched: string[] } {
  const searched: string[] = [];
  for (const dir of EXTRA_SEARCH_DIRS) {
    const p = path.join(dir, name);
    searched.push(p);
    if (existsExecutable(p)) return { found: p, searched };
  }
  const PATH = process.env.PATH || "";
  for (const dir of PATH.split(path.delimiter).filter(Boolean)) {
    const p = path.join(dir, name);
    searched.push(p);
    if (existsExecutable(p)) return { found: p, searched };
  }
  return { found: null, searched };
}

export async function detectRecorderInfo(): Promise<RecorderInfo> {
  const ff = findBinary("ffmpeg");
  if (ff.found) return { tool: "ffmpeg", binPath: ff.found, searched: ff.searched };
  const sx = findBinary("sox");
  if (sx.found) return { tool: "sox", binPath: sx.found, searched: [...ff.searched, ...sx.searched] };
  return { tool: null, searched: [...ff.searched, ...sx.searched] };
}

export async function detectRecorder(): Promise<RecorderTool> {
  return (await detectRecorderInfo()).tool;
}

/** Sample rate & bit depth we feed to the PCM pipe (and into the final WAV). */
const SAMPLE_RATE = 16000;
const CHANNELS = 1;
const BITS_PER_SAMPLE = 16;

/**
 * Wraps an ffmpeg/sox child process that pipes s16le PCM to stdout.
 * Emits:
 *   - "level" { rms } — RMS value (0..1) per ~60ms chunk
 *   - "error" Error
 */
export class ActiveRecording extends EventEmitter {
  public readonly tool: RecorderTool;
  public readonly startedAt: number;
  public stderr: string = "";
  private readonly proc: cp.ChildProcess;
  private readonly pcmChunks: Buffer[] = [];
  private lastLevel = 0;
  private stopping = false;

  constructor(info: RecorderInfo) {
    super();
    if (!info.tool || !info.binPath) throw new Error("No recorder tool available");
    this.tool = info.tool;
    this.startedAt = Date.now();

    const args =
      info.tool === "ffmpeg"
        ? [
            "-hide_banner",
            "-nostdin",
            "-loglevel", "error",
            "-f", "avfoundation",
            "-i", ":0",
            "-ar", String(SAMPLE_RATE),
            "-ac", String(CHANNELS),
            "-f", "s16le",      // PCM 16-bit signed little-endian
            "pipe:1",
          ]
        : [
            "-q",
            "-d",              // default input device
            "-c", String(CHANNELS),
            "-r", String(SAMPLE_RATE),
            "-b", String(BITS_PER_SAMPLE),
            "-e", "signed-integer",
            "-t", "raw",
            "-",                // stdout
          ];

    this.proc = cp.spawn(info.binPath, args, {
      stdio: ["pipe", "pipe", "pipe"],
    });

    this.proc.stdout?.on("data", (chunk: Buffer) => {
      this.pcmChunks.push(chunk);
      // Compute RMS for this chunk (per ~60ms of audio at 16kHz mono)
      const n = chunk.length >> 1; // number of int16 samples
      if (n > 0) {
        let sum = 0;
        for (let i = 0; i < chunk.length - 1; i += 2) {
          const s = chunk.readInt16LE(i) / 32768;
          sum += s * s;
        }
        const rms = Math.sqrt(sum / n);
        // Smoothly filter the level (exponential moving average)
        this.lastLevel = this.lastLevel * 0.55 + rms * 0.45;
        const normalized = Math.min(1, this.lastLevel * 3.2);
        this.emit("level", { rms: normalized });
      }
    });

    this.proc.stderr?.on("data", (chunk: Buffer) => {
      this.stderr += chunk.toString();
      if (this.stderr.length > 4000) this.stderr = this.stderr.slice(-4000);
    });

    this.proc.on("error", (err) => {
      if (!this.stopping) this.emit("error", err);
    });
  }

  /** Total bytes of PCM captured so far. */
  bytesCaptured(): number {
    let t = 0;
    for (const c of this.pcmChunks) t += c.length;
    return t;
  }

  /** Stop recording and return a WAV file buffer. */
  stop(): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      this.stopping = true;
      let settled = false;
      const settle = (fn: () => void) => { if (!settled) { settled = true; fn(); } };

      const build = () => {
        try {
          const pcm = Buffer.concat(this.pcmChunks);
          if (pcm.length === 0) {
            reject(new Error("No audio captured. " + this.stderr.slice(0, 200)));
            return;
          }
          const wav = pcmToWav(pcm, SAMPLE_RATE, CHANNELS, BITS_PER_SAMPLE);
          resolve(wav);
        } catch (err) {
          reject(err);
        }
      };

      this.proc.on("exit", () => settle(build));

      try {
        if (this.tool === "ffmpeg") {
          this.proc.stdin?.write("q\n");
          this.proc.stdin?.end();
        } else {
          this.proc.kill("SIGINT");
        }
      } catch (err) {
        settle(() => reject(err));
      }

      // Safety hard-kill
      setTimeout(() => {
        if (!settled) {
          try { this.proc.kill("SIGKILL"); } catch {}
          // Build WAV from whatever we already captured
          settle(build);
        }
      }, 1500);
    });
  }

  /** Abort without returning audio. */
  abort(): void {
    this.stopping = true;
    try { this.proc.kill("SIGKILL"); } catch {}
    this.pcmChunks.length = 0;
  }
}

/** Start a new recording. Returns the emitter or null if no tool found. */
export function startRecording(info: RecorderInfo): ActiveRecording | null {
  if (!info.tool || !info.binPath) return null;
  return new ActiveRecording(info);
}

/** Legacy-shaped stop/abort for backward compat with existing callers. */
export function stopRecording(rec: ActiveRecording): Promise<Buffer> {
  return rec.stop();
}
export function abortRecording(rec: ActiveRecording): void {
  rec.abort();
}

/** Build a WAV file buffer around raw PCM samples. */
function pcmToWav(
  pcm: Buffer,
  sampleRate: number,
  channels: number,
  bitsPerSample: number
): Buffer {
  const byteRate = (sampleRate * channels * bitsPerSample) / 8;
  const blockAlign = (channels * bitsPerSample) / 8;
  const dataSize = pcm.length;
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write("data", 36);
  header.writeUInt32LE(dataSize, 40);
  return Buffer.concat([header, pcm]);
}
