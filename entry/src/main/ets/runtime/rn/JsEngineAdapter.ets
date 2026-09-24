import { webview } from '@kit.ArkWeb';

/**
 * JS engine adapter boundary.
 *
 * ArkTS is a statically-restricted TypeScript dialect — it cannot eval
 * arbitrary JavaScript, so a React Native bundle must run inside a real JS
 * engine hosted by the app. This interface is what a bridge consumes:
 * evaluate source, get a JSON-encoded {ok, value | error} envelope back.
 *
 * Two candidates, honestly scoped:
 *   - WebViewJsEngineAdapter (implemented): delegates to the ArkWeb engine.
 *     It genuinely evaluates JS today, but offers no synchronous
 *     native-call channel, so it can prototype bundle loading but cannot
 *     run an unmodified RN bundle (which expects __fbBatchedBridge etc.).
 *   - NativeEngineAdapter (placeholder): the real target — the ArkCompiler
 *     'NativeEngine' embedded JS runtime, reachable through a C++ NAPI
 *     module calling napi_run_script. See docs/rn-bridge-architecture.md.
 */
export interface JsEngineAdapter {
  readonly name: string;

  /** False when the adapter's backing engine is not available (stub). */
  readonly available: boolean;

  /**
   * Evaluate `script` (sourceUrl is for diagnostics). Resolves to a JSON
   * string: {"ok":true,"value":<last-expr>} or {"ok":false,"error":"..."}.
   */
  evaluate(script: string, sourceUrl: string): Promise<string>;

  dispose(): void;
}

/**
 * FUNCTIONAL — evaluates JavaScript inside a hidden ArkWeb WebView.
 *
 * Requirements: the host must render a `Web({ src: 'about:blank' })` and
 * pass its WebviewController to attach() before evaluate(). JS-to-native
 * is async only (runJavaScript resolves on completion); there is no
 * synchronous bridge callback channel, so this adapter cannot host the RN
 * bridge protocol — it exists to validate bundle fetching/parsing and to
 * prototype engine plumbing.
 */
export class WebViewJsEngineAdapter implements JsEngineAdapter {
  readonly name: string = 'arkweb-js';
  readonly available: boolean = true;
  private controller: webview.WebviewController | null = null;

  attach(controller: webview.WebviewController): void {
    this.controller = controller;
  }

  evaluate(script: string, sourceUrl: string): Promise<string> {
    const controller = this.controller;
    if (controller === null) {
      return Promise.reject(new Error(
        'WebViewJsEngineAdapter: attach() a WebviewController before evaluate()'
      ));
    }
    // Wrap so eval failures come back as a value, not a rejected promise.
    const wrapped = 'JSON.stringify((function(){try{var __r=eval(' +
      JSON.stringify(script) +
      ');return {ok:true,value:__r};}catch(e){return {ok:false,error:String(e&&e.stack||e)};}})())';
    return controller.runJavaScript(wrapped).then((result: string) => {
      // ArkWeb returns the expression result as a JSON string already.
      return result;
    }).catch((err: Error) => {
      return JSON.stringify({ ok: false, error: err.message });
    });
  }

  dispose(): void {
    this.controller = null;
  }
}

/**
 * PLACEHOLDER — ArkCompiler NativeEngine via NAPI (the real target).
 *
 * Executing an RN bundle needs a synchronous JS<->native channel. The
 * HarmonyOS NAPI surface exposes `napi_run_script` /
 * `napi_run_script_path` on the app's embedded ArkCompiler engine — the
 * same engine that executes ArkTS, reachable from a native (C++) module
 * built under entry/src/main/cpp. That is where __fbBatchedBridge,
 * flushQueue, and the UIManager dispatch (ShadowTree) would be bound.
 * Not implemented: requires a native build the ArkTS-only HAP lacks.
 */
export class NativeEngineAdapter implements JsEngineAdapter {
  readonly name: string = 'nativeengine';
  readonly available: boolean = false;

  evaluate(script: string, sourceUrl: string): Promise<string> {
    return Promise.reject(new Error(
      'NativeEngineAdapter is a placeholder: no NAPI native module is built ' +
      'in this package. See docs/rn-bridge-architecture.md for the plan.'
    ));
  }

  dispose(): void {
  }
}
