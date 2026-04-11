/**
 * WelcomePanel — Full-screen welcome overlay shown on editor startup
 *
 * Shows a personalized morning greeting with:
 *   - Pet character pixel-art avatar (SVG)
 *   - Time-aware greeting ("Good morning, Mona!")
 *   - Yesterday's stats recap
 *   - Today's goals / motivational message
 *   - Quick action buttons (Start Coding, View Dashboard, Open Codepet App)
 *
 * Follows Atomic Habits principle: "Make it Obvious" — the first thing you see
 * when opening your editor sets the tone for your coding session.
 */

import * as vscode from "vscode";

export class WelcomePanel {
  public static readonly viewType = "codepet.welcome";
  private static currentPanel: WelcomePanel | undefined;
  private panel: vscode.WebviewPanel;
  private disposables: vscode.Disposable[] = [];

  private constructor(
    panel: vscode.WebviewPanel,
    private extensionUri: vscode.Uri,
    private petName: string,
    private userName: string,
    private stats: WelcomeStats
  ) {
    this.panel = panel;
    this.panel.webview.html = this.getHtml();

    // Listen for panel disposal
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);

    // Listen for messages from webview
    this.panel.webview.onDidReceiveMessage(
      (msg) => {
        switch (msg.command) {
          case "startCoding":
            this.panel.dispose();
            break;
          case "openDashboard":
            // Reveal the sidebar container first, then focus the dashboard view
            // Use setTimeout to let the panel dispose before switching focus
            this.panel.dispose();
            setTimeout(() => {
              vscode.commands.executeCommand("workbench.view.extension.codepet-sidebar").then(
                () => vscode.commands.executeCommand("codepet.dashboard.focus"),
                () => vscode.commands.executeCommand("codepet.dashboard.focus")
              );
            }, 200);
            break;
          case "openApp":
            vscode.env.openExternal(vscode.Uri.parse("codepet://home"));
            break;
          case "dismiss":
            this.panel.dispose();
            break;
        }
      },
      null,
      this.disposables
    );

    // Auto-dismiss after 60 seconds
    const autoClose = setTimeout(() => {
      if (this.panel) {
        this.panel.dispose();
      }
    }, 60000);
    this.disposables.push({ dispose: () => clearTimeout(autoClose) });
  }

  /** Show the welcome panel (singleton — only one at a time) */
  public static show(
    extensionUri: vscode.Uri,
    petName: string,
    userName: string,
    stats: WelcomeStats
  ): void {
    // If panel already exists, focus it
    if (WelcomePanel.currentPanel) {
      WelcomePanel.currentPanel.panel.reveal(vscode.ViewColumn.One);
      return;
    }

    const panel = vscode.window.createWebviewPanel(
      WelcomePanel.viewType,
      `Welcome — Codepet`,
      { viewColumn: vscode.ViewColumn.One, preserveFocus: false },
      {
        enableScripts: true,
        localResourceRoots: [extensionUri],
        retainContextWhenHidden: false,
      }
    );

    WelcomePanel.currentPanel = new WelcomePanel(
      panel,
      extensionUri,
      petName,
      userName,
      stats
    );
  }

  /** Check if the welcome panel should show (once per day, or on version update) */
  public static shouldShow(context: vscode.ExtensionContext): boolean {
    const lastShown = context.globalState.get<string>("codepet.lastWelcome");
    const lastVersion = context.globalState.get<string>("codepet.lastVersion");
    const today = new Date().toDateString();

    // Read real version from extension manifest (no more hardcoded strings)
    const ext = vscode.extensions.getExtension("NguyenTruong.codepet");
    const currentVersion = ext?.packageJSON?.version ?? "unknown";

    // Always show on first install or version update
    if (!lastVersion || lastVersion !== currentVersion) {
      context.globalState.update("codepet.lastVersion", currentVersion);
      return true;
    }

    return lastShown !== today;
  }

  /** Mark that we showed the welcome today */
  public static markShown(context: vscode.ExtensionContext): void {
    context.globalState.update("codepet.lastWelcome", new Date().toDateString());
  }

  private getTimeGreeting(): string {
    const hour = new Date().getHours();
    if (hour < 5) return "Burning the midnight oil";
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    if (hour < 21) return "Good evening";
    return "Late night coding";
  }

  private getMotivationalMessage(): string {
    const petKey = this.petName.toLowerCase();
    const messages: Record<string, string[]> = {
      byte: [
        "Every function you write adds to your codebase. Let's analyze what we can build today.",
        "Your coding patterns are evolving. I've been tracking the data — you're improving.",
        "Logic is beautiful. Let's write some today.",
      ],
      nova: [
        "Every line of code you write is a step forward. I believe in you!",
        "You showed up today — that's already a win. Let's make it count!",
        "Small progress is still progress. Let's build something amazing together!",
      ],
      crash: [
        "Let's break things and build them back stronger. Ready?",
        "No time for hesitation — let's ship some code!",
        "Bugs don't stand a chance when we're together. Let's go!",
      ],
      luna: [
        "Take a breath. Center yourself. Then let's write something meaningful.",
        "The best code comes from a calm mind. I'm here whenever you're ready.",
        "Today is a blank canvas. What shall we create?",
      ],
      sage: [
        "Patience and practice — that's how skills compound over time.",
        "Every expert was once a beginner. Today you're one day closer.",
        "The journey matters more than the destination. Let's enjoy the process.",
      ],
      glitch: [
        "Yo! Ready to zap some bugs and write some wild code?!",
        "Let's gooo! I've got so much energy today — hope you do too!",
        "Experiments lead to discoveries. Let's try something fun!",
      ],
      zero: [
        "The void holds infinite possibilities. What shall we summon today?",
        "Between the ones and zeros, great software takes shape.",
        "I sense interesting code in your future today...",
      ],
      null: [
        "Another day, another chance to prove null !== nothing. Let's code!",
        "They said I'm nothing... but watch us build something great today.",
        "Undefined? Not for long. Let's define what today looks like.",
      ],
    };
    const petMessages = messages[petKey] || messages["nova"];
    return petMessages[Math.floor(Math.random() * petMessages.length)];
  }

  private getHtml(): string {
    const webview = this.panel.webview;
    const nonce = getNonce();

    // Character SVG URI
    const petKey = this.petName.toLowerCase();
    const charUri = webview.asWebviewUri(
      vscode.Uri.joinPath(this.extensionUri, "media", `char-${petKey}.svg`)
    );
    // Fallback
    const fallbackUri = webview.asWebviewUri(
      vscode.Uri.joinPath(this.extensionUri, "media", "char-nova.svg")
    );

    const greeting = this.getTimeGreeting();
    const motivation = this.getMotivationalMessage();
    const s = this.stats;

    // Streak message
    let streakText = "";
    if (s.streakDays > 0) {
      streakText = `<div class="streak-badge">${s.streakDays}-day streak</div>`;
    }

    // Yesterday's stats section
    let yesterdaySection = "";
    if (s.yesterdayCodingMinutes > 0) {
      const h = Math.floor(s.yesterdayCodingMinutes / 60);
      const m = s.yesterdayCodingMinutes % 60;
      const timeStr = h > 0 ? `${h}h ${m}m` : `${m}m`;
      yesterdaySection = `
        <div class="stats-recap">
          <div class="stats-title">Yesterday's recap</div>
          <div class="stats-row">
            <div class="stat-card">
              <div class="stat-num">${timeStr}</div>
              <div class="stat-desc">coding time</div>
            </div>
            <div class="stat-card">
              <div class="stat-num">${s.yesterdayLinesAdded}</div>
              <div class="stat-desc">lines written</div>
            </div>
            <div class="stat-card">
              <div class="stat-num">${s.yesterdayCommits}</div>
              <div class="stat-desc">commits</div>
            </div>
            <div class="stat-card">
              <div class="stat-num">${s.yesterdayCleanScore}%</div>
              <div class="stat-desc">clean score</div>
            </div>
          </div>
        </div>`;
    } else {
      yesterdaySection = `
        <div class="stats-recap">
          <div class="stats-title">Welcome back!</div>
          <div class="stats-subtitle">No session data from yesterday — let's make today count.</div>
        </div>`;
    }

    return /*html*/ `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; img-src ${webview.cspSource}; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';" />
  <title>Welcome — Codepet</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: var(--vscode-font-family, -apple-system, BlinkMacSystemFont, sans-serif);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 40px 20px;
    }

    .welcome-container {
      max-width: 560px;
      width: 100%;
      text-align: center;
      animation: fadeIn 0.6s ease-out;
    }

    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(20px); }
      to { opacity: 1; transform: translateY(0); }
    }

    @keyframes float {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(-8px); }
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.7; }
    }

    /* ── Pet Avatar ── */
    .pet-container {
      margin-bottom: 20px;
    }
    .pet-img {
      width: 120px;
      height: 150px;
      object-fit: contain;
      image-rendering: pixelated;
      animation: float 3s ease-in-out infinite;
      filter: drop-shadow(0 8px 24px rgba(123, 107, 216, 0.3));
    }

    /* ── Greeting ── */
    .greeting {
      font-size: 28px;
      font-weight: 700;
      margin-bottom: 6px;
      color: var(--vscode-foreground);
    }
    .greeting .name {
      background: linear-gradient(135deg, #7B6BD8, #A89BF2);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .pet-says {
      font-size: 14px;
      color: var(--vscode-descriptionForeground);
      font-style: italic;
      margin-bottom: 24px;
      line-height: 1.5;
      padding: 0 20px;
    }

    /* ── Streak Badge ── */
    .streak-badge {
      display: inline-block;
      background: linear-gradient(135deg, #F97316, #FBBF24);
      color: #1a1a1a;
      font-size: 12px;
      font-weight: 700;
      padding: 4px 14px;
      border-radius: 20px;
      margin-bottom: 20px;
      letter-spacing: 0.3px;
    }

    /* ── Stats Recap ── */
    .stats-recap {
      background: var(--vscode-sideBar-background, #1e1e1e);
      border: 1px solid var(--vscode-panel-border, #333);
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 24px;
    }
    .stats-title {
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      color: var(--vscode-descriptionForeground);
      margin-bottom: 14px;
    }
    .stats-subtitle {
      font-size: 13px;
      color: var(--vscode-descriptionForeground);
      margin-top: 4px;
    }
    .stats-row {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 10px;
    }
    .stat-card {
      background: var(--vscode-editor-background);
      border: 1px solid var(--vscode-panel-border, #333);
      border-radius: 8px;
      padding: 12px 8px;
    }
    .stat-num {
      font-size: 20px;
      font-weight: 700;
      color: #A89BF2;
    }
    .stat-desc {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
      text-transform: uppercase;
      letter-spacing: 0.3px;
      margin-top: 4px;
    }

    /* ── Action Buttons ── */
    .actions {
      display: flex;
      flex-direction: column;
      gap: 10px;
      align-items: center;
    }
    .btn-primary {
      width: 100%;
      max-width: 320px;
      padding: 12px 24px;
      font-size: 14px;
      font-weight: 600;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      background: linear-gradient(135deg, #7B6BD8, #534AB7);
      color: #fff;
      transition: transform 0.15s, box-shadow 0.15s;
    }
    .btn-primary:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 16px rgba(123, 107, 216, 0.4);
    }
    .btn-secondary {
      width: 100%;
      max-width: 320px;
      padding: 10px 24px;
      font-size: 13px;
      font-weight: 500;
      border: 1px solid var(--vscode-panel-border, #444);
      border-radius: 8px;
      cursor: pointer;
      background: var(--vscode-sideBar-background, #1e1e1e);
      color: var(--vscode-foreground);
      transition: background 0.15s;
    }
    .btn-secondary:hover {
      background: var(--vscode-list-hoverBackground, #2a2a2a);
    }
    .btn-row {
      display: flex;
      gap: 10px;
      width: 100%;
      max-width: 320px;
    }
    .btn-row .btn-secondary {
      flex: 1;
    }

    /* ── Dismiss ── */
    .dismiss {
      margin-top: 16px;
      font-size: 11px;
      color: var(--vscode-descriptionForeground);
      opacity: 0.6;
      cursor: pointer;
      border: none;
      background: none;
    }
    .dismiss:hover { opacity: 1; }
  </style>
</head>
<body>
  <div class="welcome-container">
    <div class="pet-container">
      <img class="pet-img" src="${charUri}" onerror="this.src='${fallbackUri}'" alt="${this.petName}" />
    </div>

    <div class="greeting">${greeting}, <span class="name">${this.userName}</span>!</div>
    <div class="pet-says">${this.petName} says: "${motivation}"</div>

    ${streakText}
    ${yesterdaySection}

    <div class="actions">
      <button class="btn-primary" onclick="send('startCoding')">Start Coding</button>
      <div class="btn-row">
        <button class="btn-secondary" onclick="send('openDashboard')">Dashboard</button>
        <button class="btn-secondary" onclick="send('openApp')">Open Codepet App</button>
      </div>
    </div>

    <button class="dismiss" onclick="send('dismiss')">Press Esc or click to dismiss</button>
  </div>

  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi();
    function send(cmd) { vscode.postMessage({ command: cmd }); }

    // Dismiss on Escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') send('dismiss');
    });
  </script>
</body>
</html>`;
  }

  private dispose(): void {
    WelcomePanel.currentPanel = undefined;
    this.panel.dispose();
    for (const d of this.disposables) d.dispose();
  }
}

// ───── Types ─────

export interface WelcomeStats {
  yesterdayCodingMinutes: number;
  yesterdayLinesAdded: number;
  yesterdayCommits: number;
  yesterdayCleanScore: number;
  streakDays: number;
}

// ───── Helpers ─────

function getNonce(): string {
  let text = "";
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  for (let i = 0; i < 32; i++) {
    text += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return text;
}
