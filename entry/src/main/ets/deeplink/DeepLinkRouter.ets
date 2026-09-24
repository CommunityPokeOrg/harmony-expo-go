/**
 * FUNCTIONAL — delivers deep-link URIs from EntryAbility wants to the
 * launcher page.
 *
 * EntryAbility receives wants in two situations:
 *   - cold start: onCreate(want) fires before the window/page exists, so the
 *     URI must be queued until the launcher subscribes;
 *   - warm start: onNewWant(want) fires while the app is already running
 *     (singleton launch mode), so the URI can be delivered immediately.
 *
 * The router queues links until the launcher page registers a listener, then
 * flushes them in arrival order. Validation/normalization happens at the
 * listener side (Index.ets -> ExpoUrl.normalize) so unsupported links are
 * rejected with a toast, never pushed into the runner.
 */
export class DeepLinkRouter {
  private static shared: DeepLinkRouter | null = null;

  static get instance(): DeepLinkRouter {
    if (DeepLinkRouter.shared === null) {
      DeepLinkRouter.shared = new DeepLinkRouter();
    }
    return DeepLinkRouter.shared;
  }

  private listener: ((rawUri: string) => void) | null = null;
  private pending: string[] = [];

  /** Called from EntryAbility.onCreate / onNewWant with want.uri. */
  dispatch(rawUri: string): void {
    if (rawUri.length === 0) {
      return;
    }
    if (this.listener !== null) {
      this.listener(rawUri);
    } else {
      this.pending.push(rawUri);
    }
  }

  /**
   * Called by the launcher page when it is ready to open projects.
   * Replaces any previous listener and flushes queued links in order.
   */
  setListener(listener: (rawUri: string) => void): void {
    this.listener = listener;
    if (this.pending.length === 0) {
      return;
    }
    const queued = this.pending;
    this.pending = [];
    for (const uri of queued) {
      listener(uri);
    }
  }

  clearListener(): void {
    this.listener = null;
  }

  /** Test seam — drops the listener and any queued links. */
  resetForTest(): void {
    this.listener = null;
    this.pending = [];
  }
}
