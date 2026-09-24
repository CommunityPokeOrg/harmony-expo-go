import { webview } from '@kit.ArkWeb';
import { ProjectEntry } from '../model/ProjectEntry';

/**
 * Runtime bridge boundary.
 *
 * The launcher shell (URL bar, QR scanner, recents) is deliberately decoupled
 * from the engine that actually executes a project. New engines implement
 * RuntimeBridge and plug into RuntimeBridgeRegistry.createFor().
 */
export enum RuntimeKind {
  /** Renders the project URL inside ArkWeb (Expo web export / any web page). */
  WEBVIEW = 'webview',

  /**
   * PLACEHOLDER — a Hermes (or JSC) engine hosted in the app that executes
   * React Native bundles served by Metro. There is no Hermes build for
   * HarmonyOS NEXT in this scaffold; see README "Implementation scope".
   */
  HERMES = 'hermes',
}

export interface RuntimeBridge {
  readonly kind: RuntimeKind;

  /** True when the bridge renders inside the app process (not a system UI). */
  readonly isEmbedded: boolean;

  /** Prepare the engine for a project. Reject when the project is unsupported. */
  prepare(project: ProjectEntry): Promise<void>;

  /** Reload the currently prepared project. */
  reload(): void;

  /** Release engine resources. */
  dispose(): void;
}

/**
 * FUNCTIONAL — renders the project URL with ArkWeb.
 *
 * Real Expo Go semantics for `expo start --web` output and plain web content:
 * the served page runs in the Web component (Chromium-based ArkWeb engine).
 * A React Native *bundle* is NOT executed by this bridge.
 */
export class WebViewRuntimeBridge implements RuntimeBridge {
  readonly kind: RuntimeKind = RuntimeKind.WEBVIEW;
  readonly isEmbedded: boolean = true;
  private controller: webview.WebviewController | null = null;
  private url: string = '';

  attach(controller: webview.WebviewController): void {
    this.controller = controller;
  }

  prepare(project: ProjectEntry): Promise<void> {
    this.url = project.url;
    return Promise.resolve();
  }

  reload(): void {
    if (this.controller !== null && this.url.length > 0) {
      this.controller.loadUrl(this.url);
    }
  }

  dispose(): void {
    this.controller = null;
  }
}

/**
 * PLACEHOLDER — future native JS runtime.
 *
 * Executing a React Native bundle on HarmonyOS NEXT requires:
 *   1. a JS engine for OHOS — see runtime/rn/JsEngineAdapter.ets (the
 *      ArkWeb adapter works for plain JS; the NativeEngine adapter is a
 *      stub pending a C++ NAPI module),
 *   2. a bridge/turbo-module surface — see runtime/rn/NativeModuleRegistry.ets,
 *   3. a UIManager + ArkUI view layer — see runtime/rn/ShadowTree.ets and
 *      runtime/rn/RnSurface.ets.
 * Bundle fetching already exists (runtime/rn/RnBundleLoader.ets); the
 * engine and bridge do not, so prepare() fails loudly.
 * Full investigation: docs/rn-bridge-architecture.md.
 */
export class HermesRuntimeBridge implements RuntimeBridge {
  readonly kind: RuntimeKind = RuntimeKind.HERMES;
  readonly isEmbedded: boolean = true;

  prepare(project: ProjectEntry): Promise<void> {
    return Promise.reject(new Error(
      'HermesRuntimeBridge is a placeholder: React Native bundle execution ' +
      'is not implemented for HarmonyOS NEXT (no JS engine is bound). ' +
      'Only web-served projects run.'
    ));
  }

  reload(): void {
  }

  dispose(): void {
  }
}

/**
 * Picks the bridge for a project URL.
 *
 * Today every supported URL resolves to the WebView bridge. When a native RN
 * runtime lands, this is the single place that decides whether a project is a
 * Metro bundle URL (-> HermesRuntimeBridge) or web content (-> WebView).
 */
export class RuntimeBridgeRegistry {
  static createFor(project: ProjectEntry): RuntimeBridge {
    return new WebViewRuntimeBridge();
  }
}
