import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ExpoUrl } from '../utils/ExpoUrl';

const DOMAIN = 0x0001;
const TAG = 'MetroHotClient';

export enum MetroHotStatus {
  OFF = 'off',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  CLOSED = 'closed',
  ERROR = 'error',
}

/**
 * Parsed Metro `/hot` WebSocket message (tolerant subset).
 *
 * Metro's HMR server emits JSON frames like:
 *   {"type":"bundle-started"}
 *   {"type":"update-start"}
 *   {"type":"update","body":{"modules":[...],"revisionId":"r3"}}
 *   {"type":"update-done"}
 *   {"type":"error","body":{"type":"...","description":"..."}}
 *   {"type":"warning","body":{"description":"..."}}
 *   {"type":"ok"}
 * Unknown/extra fields are ignored; malformed frames parse to null.
 */
export class MetroHotMessage {
  type: string = '';
  /** Error/warning classification carried in body.type, when present. */
  errorType: string = '';
  /** body.description or body.message, when present. */
  description: string = '';
  /** body.revisionId for update frames, when present. */
  revisionId: string = '';

  static parse(data: string): MetroHotMessage | null {
    let obj: Record<string, Object>;
    try {
      obj = JSON.parse(data) as Record<string, Object>;
    } catch (e) {
      return null;
    }
    const type = obj['type'];
    if (typeof type !== 'string' || type.length === 0) {
      return null;
    }
    const msg = new MetroHotMessage();
    msg.type = type;
    const body = obj['body'];
    if (body !== undefined && body !== null) {
      const b = body as Record<string, Object>;
      const desc = b['description'];
      const message = b['message'];
      const errorType = b['type'];
      const revisionId = b['revisionId'];
      if (typeof desc === 'string') {
        msg.description = desc;
      } else if (typeof message === 'string') {
        msg.description = message;
      }
      if (typeof errorType === 'string') {
        msg.errorType = errorType;
      }
      if (typeof revisionId === 'string') {
        msg.revisionId = revisionId;
      } else if (typeof revisionId === 'number') {
        msg.revisionId = 'r' + revisionId;
      }
    }
    return msg;
  }
}

/**
 * FUNCTIONAL (transport + lifecycle) — WebSocket client for Metro's `/hot`
 * fast-refresh channel.
 *
 * What works: connect/disconnect to ws(s)://<metro-host>/hot, status
 * callbacks, and typed message dispatch (update-start/update-done/error/
 * warning). What does NOT work: actual in-bundle hot module replacement —
 * that requires the JS runtime (Hermes/NativeEngine bridge) which is not
 * implemented. On 'update-done' the runner therefore falls back to a full
 * bridge.reload(), which refreshes the WebView runtime for real.
 *
 * Callback fields default to no-ops so callers subscribe only to what they
 * need.
 */
export class MetroHotClient {
  onStatusChange: (status: MetroHotStatus, detail: string) => void = () => {
  };
  onUpdateStart: () => void = () => {
  };
  onUpdateDone: (revisionId: string) => void = () => {
  };
  onMetroError: (errorType: string, description: string) => void = () => {
  };
  /** Everything not otherwise handled: warnings, ok, unknown frame types. */
  onMessage: (message: string) => void = () => {
  };

  status: MetroHotStatus = MetroHotStatus.OFF;
  private ws: webSocket.WebSocket | null = null;
  private url: string = '';

  /** ws(s)://<host:port>/hot for a normalized http(s) project URL. */
  static hotUrlFor(projectUrl: string): string | null {
    const base = ExpoUrl.devServerBase(projectUrl);
    if (base.startsWith('https://')) {
      return 'wss://' + base.substring('https://'.length) + '/hot';
    }
    if (base.startsWith('http://')) {
      return 'ws://' + base.substring('http://'.length) + '/hot';
    }
    return null;
  }

  connect(projectUrl: string): void {
    const hotUrl = MetroHotClient.hotUrlFor(projectUrl);
    if (hotUrl === null) {
      this.setStatus(MetroHotStatus.ERROR, 'cannot derive ws:// URL from ' + projectUrl);
      return;
    }
    this.disconnect();
    this.url = hotUrl;
    const ws = webSocket.createWebSocket();
    this.ws = ws;
    this.setStatus(MetroHotStatus.CONNECTING, hotUrl);

    ws.on('open', () => {
      this.setStatus(MetroHotStatus.CONNECTED, '');
    });
    ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
      if (typeof data === 'string') {
        this.handleMessage(data);
      }
    });
    ws.on('close', (err: BusinessError, result: webSocket.CloseResult) => {
      this.setStatus(MetroHotStatus.CLOSED, 'code ' + result.code);
      this.ws = null;
    });
    ws.on('error', (err: BusinessError) => {
      this.setStatus(MetroHotStatus.ERROR, err.message !== undefined ? err.message : 'ws error');
    });

    ws.connect(hotUrl).then((ok: boolean) => {
      if (!ok) {
        this.setStatus(MetroHotStatus.ERROR, 'connect returned false');
      }
    }).catch((err: BusinessError) => {
      this.setStatus(MetroHotStatus.ERROR, 'connect failed: ' + err.code);
    });
  }

  disconnect(): void {
    const ws = this.ws;
    this.ws = null;
    if (ws !== null) {
      ws.off('open');
      ws.off('message');
      ws.off('close');
      ws.off('error');
      ws.close().catch(() => {
      });
    }
    if (this.status !== MetroHotStatus.OFF) {
      this.setStatus(MetroHotStatus.OFF, '');
    }
  }

  dispose(): void {
    this.disconnect();
    this.onStatusChange = () => {
    };
    this.onUpdateStart = () => {
    };
    this.onUpdateDone = () => {
    };
    this.onMetroError = () => {
    };
    this.onMessage = () => {
    };
  }

  private setStatus(status: MetroHotStatus, detail: string): void {
    this.status = status;
    hilog.info(DOMAIN, TAG, 'hot %{public}s %{public}s', status, detail);
    this.onStatusChange(status, detail);
  }

  private handleMessage(raw: string): void {
    const msg = MetroHotMessage.parse(raw);
    if (msg === null) {
      this.onMessage(raw);
      return;
    }
    switch (msg.type) {
      case 'bundle-started':
      case 'update-start':
      case 'update':
        this.onUpdateStart();
        break;
      case 'update-done':
      case 'bundle-build-done':
        this.onUpdateDone(msg.revisionId);
        break;
      case 'error':
        this.onMetroError(
          msg.errorType.length > 0 ? msg.errorType : 'Metro error',
          msg.description.length > 0 ? msg.description : raw
        );
        break;
      case 'warning':
        this.onMessage('warning: ' + msg.description);
        break;
      case 'ok':
        break;
      default:
        this.onMessage(raw);
        break;
    }
  }
}
