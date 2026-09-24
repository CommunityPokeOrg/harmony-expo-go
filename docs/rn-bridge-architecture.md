# RN bundle execution on HarmonyOS NEXT — investigation & plan

Goal: run a real React Native JS bundle served by Metro inside this app, the
way Expo Go does on Android/iOS. This document records what was investigated,
what foundation now exists in `entry/src/main/ets/runtime/rn/`, what is NOT
implemented, and the concrete next steps.

## The constraint

ArkTS is a statically-typed, restricted TypeScript dialect: no dynamic
`eval`, no `Function` constructor, no prototype patching. An RN bundle is
plain, dynamically-loaded JavaScript — it can never execute as ArkTS. The
app therefore needs an embedded general-purpose JS engine plus a
native-call surface, which is the same architecture RN itself uses
(engine + bridge/turbo modules + view managers).

## Engine options considered

| Option | What it is | Feasibility |
| ------ | ---------- | ----------- |
| **ArkCompiler "NativeEngine" via NAPI** | The embedded JS runtime that already executes ArkTS inside every OHOS app. NAPI exposes `napi_run_script` / `napi_run_script_path`, so a small C++ module (`entry/src/main/cpp`, CMake + hvigor native build) can eval bundle text inside the app's own engine and expose synchronous callouts (`__fbBatchedBridge` hooks) back into ArkTS via `napi_call_function` / registered JS globals. | **Realistic path.** Real JS engine, real sync channel, no external dependency. Cost: a C++ NAPI layer that must marshal every bridge call. |
| **Hermes for OHOS** | The RN-native engine. No official OHOS build exists; would mean porting Hermes' C++ to the OHOS LLVM toolchain, then writing a JSI↔NAPI shim for the whole RN surface. | Heavy research project; not started. Advantage would be JSI compatibility with modern RN internals. |
| **ArkWeb (Chromium) JS engine** | `Web` component + `WebviewController.runJavaScript`. Implemented as `WebViewJsEngineAdapter` — **works today for plain JS evaluation**. | Only an async eval channel (results resolve via promise); no synchronous native-call hook, so an unmodified RN bundle cannot run — `__fbBatchedBridge` calls would have to be async-queued, which breaks RN's sync bridge semantics. Useful for prototyping bundle fetch/eval plumbing. |
| **V8/JSC cross-build** | Cross-compile V8 or JavaScriptCore for OHOS. | Possible in principle (community V8-for-OHOS builds exist), but brings a whole engine port + NAPI shim, comparable effort to Hermes with less RN compatibility. |

Chosen direction for the foundation: keep `JsEngineAdapter` as the seam,
ship the working `WebViewJsEngineAdapter` for prototyping, and target
`NativeEngineAdapter` (NAPI `napi_run_script`) as the production engine.

## What exists now (`runtime/rn/`)

| File | Status | Role |
| ---- | ------ | ---- |
| `JsEngineAdapter.ets` | interface + working ArkWeb adapter + NativeEngine stub | `evaluate(script)` → JSON `{ok, value|error}` envelope |
| `RnBundleLoader.ets` | **functional** | builds `…/index.bundle?platform=harmony&dev=true…` and fetches bundle text over HTTP |
| `ShadowTree.ets` | **functional** (pure data) | models RN UIManager ops: `createView`, `setChildren`, `updateView`, `removeChildren`, `setRoot`; `onChange` hook for re-render |
| `NativeModuleRegistry.ets` | **functional** (dispatch seam) | registers `NativeModule`s and executes `(module, method, argsJson)` → JSON `{ok,result|error}` — the shape bridge calls take |
| `ViewNode.ets` | **functional** | tagged shadow node + prop accessors |
| `RnSurface.ets` | **functional** ArkUI renderer | recursive `RnNodeView` maps `View/Text/Image/ScrollView/TextInput` (+unknown→View fallback) to ArkUI; renders any data-defined `ViewNode` tree today |

What is wired: nothing yet consumes `ShadowTree`/`RnSurface` from JS — there
is no engine bound to them. `HermesRuntimeBridge.prepare()` still rejects;
the launcher deliberately routes every project to the WebView bridge.

## The remaining pieces (in dependency order)

1. **Native module (C++)** — `entry/src/main/cpp`: a NAPI module exposing
   `evalScript(source, sourceUrl)` backed by `napi_run_script`, plus a
   registered global `__harmonyNativeCall(module, method, argsJson)` that
   calls back into ArkTS (napi → ArkTS callback) and lands on
   `NativeModuleRegistry.call`.
2. **Bridge bootstrap JS** — a preamble injected before the bundle that
   defines `global.__fbBatchedBridge`, `MessageQueue`, `require`/`module`
   shims enough for an unmodified RN dev bundle to register itself. This
   is where most unknowns live (which RN version's BatchedBridge contract
   to target).
3. **UIManager dispatch** — the preamble's UIManager forwards
   `createView/setChildren/updateView/manageChildren` ops through
   `__harmonyNativeCall` onto `ShadowTree`, which bumps `onChange` and
   `RnSurface` re-renders.
4. **Native modules** — minimum set an RN app touches: `DeviceInfo`,
   `Timing` (setTimeout), `NativeAnimatedHelper` can be stubbed,
   `UIManager` constants, platform constants (`Platform.constants` =
   `{os:'harmony'}`).
5. **Event routing** — native→JS (`callFunctionReturnFlushedQueue`) for
   touches/text input, plus the Metro `/hot` client (already implemented)
   driving real HMR once the engine exists.
6. **Bridge selection** — `RuntimeBridgeRegistry.createFor()` gains the
   Metro-vs-web decision once `NativeEngineAdapter.available` is true.

## Hard limitations to expect

- **Yoga/flexbox**: `RnSurface` approximates layout with ArkUI flex
  attributes; pixel-parity needs a Yoga port (C++ builds for OHOS exist in
  community ports) and a real measure pass.
- **ArkTS reflection limits**: native modules must be hand-registered —
  no scanning annotations like Java.
- **Dev tooling gaps**: no JS debugging inside the engine yet; redbox
  shows Metro/ArkWeb errors, not JS stack traces, until the bridge can
  capture them.
- **Metro platform**: `platform=harmony` is honored by Metro's resolver
  (so `*.harmony.ts` files win), but Expo config plugins that assume
  ios/android may need `platforms: [...]`-style config in the app.

## Verification status

- Unit-testable in `src/test`: `ShadowTree` ops, `MetroHotMessage` parsing,
  `NativeModuleRegistry` dispatch, `RnBundleLoader.bundleUrl`,
  `DeepLinkRouter` — all pure-logic, run via `hvigorw test`.
- Not verifiable without DevEco/SDK or a HarmonyOS device: ArkUI rendering
  of `RnSurface`, the `/hot` WebSocket against a live Metro, deep-link
  want delivery, and everything in `entry/src/main/cpp` (not yet written).
