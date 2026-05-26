/**
 * CompanionPanelProvider — Separate sidebar panel for "Ask Byte" companion chat
 *
 * Lives as its own collapsible panel in the Codepet sidebar, below the Dashboard.
 * Handles the chat UI, message rendering, and watching status indicator.
 */

import * as vscode from "vscode";

export class CompanionPanelProvider implements vscode.WebviewViewProvider {
  public static readonly viewType = "codepet.companion";

  private view?: vscode.WebviewView;
  private disposables: vscode.Disposable[] = [];
  private petName: string = "Byte";
  private watchingMsg: string = "";

  /** Callback when user sends a message */
  public onUserMessage?: (text: string) => void;
  /** Callback when user clears chat */
  public onClear?: () => void;

  constructor(private extensionUri: vscode.Uri) {}

  setPetName(name: string): void {
    this.petName = name;
  }

  /** Post a chat message (user or pet) to the webview */
  postMessage(msg: { role: string; text: string; timestamp: string }): void {
    if (this.view) {
      this.view.webview.postMessage({ type: "message", data: msg });
    }
  }

  /** Update the watching status indicator */
  postWatchingStatus(active: boolean, message?: string): void {
    this.watchingMsg = active ? (message ?? "Watching your coding session...") : "";
    if (this.view) {
      this.view.webview.postMessage({ type: "watching", data: { active, message: this.watchingMsg } });
    }
  }

  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken,
  ): void {
    this.view = webviewView;

    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this.extensionUri],
    };

    webviewView.webview.html = this.getHtml(webviewView.webview);

    // Handle messages from webview
    webviewView.webview.onDidReceiveMessage(
      (msg) => {
        if (msg.command === "send" && msg.text) {
          this.onUserMessage?.(msg.text);
        } else if (msg.command === "clear") {
          this.onClear?.();
        }
      },
      undefined,
      this.disposables,
    );

    // Re-send watching status when panel becomes visible
    webviewView.onDidChangeVisibility(() => {
      if (webviewView.visible && this.watchingMsg) {
        this.postWatchingStatus(true, this.watchingMsg);
      }
    });
  }

  private getHtml(webview: vscode.Webview): string {
    const nonce = getNonce();
    const petName = this.petName;

    return /*html*/ `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <style nonce="${nonce}">
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: var(--vscode-font-family);
      color: var(--vscode-foreground);
      background: var(--vscode-sideBar-background);
      display: flex;
      flex-direction: column;
      height: 100vh;
      overflow: hidden;
    }

    .input-area {
      order: -1;
      padding: 10px 10px 6px;
      border-bottom: 1px solid var(--vscode-panel-border, rgba(255,255,255,0.08));
      display: flex;
      gap: 6px;
      align-items: flex-end;
      flex-shrink: 0;
    }
    textarea {
      flex: 1;
      background: var(--vscode-input-background);
      color: var(--vscode-input-foreground);
      border: 1px solid var(--vscode-input-border, rgba(255,255,255,0.1));
      border-radius: 8px;
      padding: 8px 10px;
      font-size: 12px;
      font-family: inherit;
      resize: none;
      min-height: 22px;
      max-height: 100px;
      outline: none;
      line-height: 1.4;
    }
    textarea:focus { border-color: var(--vscode-focusBorder); }
    textarea::placeholder { color: var(--vscode-input-placeholderForeground); }

    .send-btn {
      background: var(--vscode-button-background);
      color: var(--vscode-button-foreground);
      border: none;
      border-radius: 8px;
      padding: 8px 14px;
      cursor: pointer;
      font-size: 12px;
      font-weight: 600;
      flex-shrink: 0;
    }
    .send-btn:hover { opacity: 0.85; }

    .header {
      display: flex;
      justify-content: flex-end;
      padding: 2px 10px 0;
    }
    .clear-btn {
      background: none;
      border: none;
      color: var(--vscode-descriptionForeground);
      font-size: 10px;
      cursor: pointer;
      opacity: 0.5;
      padding: 2px 4px;
    }
    .clear-btn:hover { opacity: 1; }

    .messages {
      flex: 1;
      overflow-y: auto;
      padding: 10px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .msg {
      padding: 8px 12px;
      border-radius: 12px;
      font-size: 12px;
      line-height: 1.55;
      max-width: 92%;
      word-wrap: break-word;
      white-space: pre-wrap;
    }
    .msg-user {
      background: var(--vscode-button-background);
      color: var(--vscode-button-foreground);
      align-self: flex-end;
      border-bottom-right-radius: 4px;
    }
    .msg-pet {
      background: var(--vscode-editor-inactiveSelectionBackground, rgba(255,255,255,0.06));
      color: var(--vscode-foreground);
      align-self: flex-start;
      border-bottom-left-radius: 4px;
    }

    .empty {
      text-align: center;
      font-size: 11.5px;
      color: var(--vscode-descriptionForeground);
      padding: 20px 16px;
      opacity: 0.7;
      line-height: 1.6;
    }
  </style>
</head>
<body>
  <div class="input-area">
    <textarea id="input" placeholder="Ask ${petName} anything..." rows="1"></textarea>
    <button class="send-btn" id="send-btn">Send</button>
  </div>
  <div class="header">
    <button class="clear-btn" id="clear-btn">clear</button>
  </div>
  <div class="messages" id="messages">
    <div class="empty">
      Ask me anything about your code!<br><br>
      Try: "Summarize my session"<br>
      "How should I build this?"<br>
      "What do you think of my approach?"
    </div>
  </div>

  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi();
    const messagesEl = document.getElementById('messages');
    const inputEl = document.getElementById('input');
    const sendBtn = document.getElementById('send-btn');
    const clearBtn = document.getElementById('clear-btn');

    function send() {
      const text = inputEl.value.trim();
      if (!text) return;
      inputEl.value = '';
      inputEl.style.height = 'auto';
      vscode.postMessage({ command: 'send', text });
    }

    sendBtn.addEventListener('click', send);
    inputEl.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
    });
    inputEl.addEventListener('input', () => {
      inputEl.style.height = 'auto';
      inputEl.style.height = Math.min(inputEl.scrollHeight, 100) + 'px';
    });
    clearBtn.addEventListener('click', () => {
      vscode.postMessage({ command: 'clear' });
      messagesEl.innerHTML = '<div class="empty">Ask me anything about your code!<br><br>Try: "Summarize my session"<br>"How should I build this?"<br>"What do you think of my approach?"</div>';
    });

    function appendMsg(data) {
      // Remove empty state
      const empty = messagesEl.querySelector('.empty');
      if (empty) empty.remove();

      const div = document.createElement('div');
      div.className = 'msg msg-' + data.role;

      if (data.role === 'pet') {
        let html = data.text
          .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
          .replace(/\\*\\*(.+?)\\*\\*/g, '<strong>$1</strong>')
          .replace(/^[•\\-] (.+)$/gm, '• $1')
          .replace(/\\n/g, '<br>');
        div.innerHTML = html;
      } else {
        div.textContent = data.text;
      }

      messagesEl.appendChild(div);
      messagesEl.scrollTop = messagesEl.scrollHeight;
    }

    window.addEventListener('message', (e) => {
      const msg = e.data;
      if (msg.type === 'message') appendMsg(msg.data);
    });
  </script>
</body>
</html>`;
  }

  dispose(): void {
    for (const d of this.disposables) d.dispose();
  }
}

function getNonce(): string {
  let text = "";
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  for (let i = 0; i < 32; i++) text += chars.charAt(Math.floor(Math.random() * chars.length));
  return text;
}
