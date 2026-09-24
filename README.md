# harmony-expo-go

An **Expo Go–style runtime client for HarmonyOS NEXT**, written in ArkTS.
Open Expo projects on a HarmonyOS device the way Expo Go does on Android/iOS:
scan a QR code from `expo start`, paste a dev-server URL, and re-open recent
projects.

> **Status: early scaffold.** The launcher shell is functional; native
> React Native bundle execution is *not* implemented (see
> [Implementation scope](#implementation-scope)).

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Launcher shell (ArkUI, ArkTS)                                │
│  pages/Index.ets        – home: URL bar, QR scan, recents    │
│  pages/RunnerPage.ets   – project runner NavDestination      │
│  components/            – UrlEntryBar, RecentProjectsSection │
│  model/                 – ProjectEntry, RecentProjectsStore  │
│  utils/ExpoUrl.ets      – exp:// → http(s):// normalization  │
├──────────────────────────────────────────────────────────────┤
│ Runtime bridge (isolated interfaces)                         │
│  runtime/RuntimeBridge.ets    – RuntimeBridge interface,     │
│                                 WebViewRuntimeBridge,        │
│                                 HermesRuntimeBridge (stub),  │
│                                 RuntimeBridgeRegistry        │
│  runtime/DevServerClient.ets  – /status + /manifest probes   │
└──────────────────────────────────────────────────────────────┘
```

The launcher never talks to an engine directly — it resolves a
`RuntimeBridge` through `RuntimeBridgeRegistry.createFor()`. Today every URL
resolves to `WebViewRuntimeBridge`; a future native RN runtime slots into the
registry without touching launcher UI.

### Entry paths

| Path                  | Mechanism                                                        | Status      |
| --------------------- | ---------------------------------------------------------------- | ----------- |
| QR code               | `scanBarcode.startScanForResult` (system Scan Kit picker — no CAMERA permission needed) | Functional  |
| URL bar               | `exp://`, `exps://`, `http(s)://`, or bare `host:port`           | Functional  |
| Recent projects       | `preferences` store, max 20 entries                              | Functional  |
| Custom-scan camera UI | `scanCore` customScan component                                  | Planned     |

### Project structure

```
AppScope/                     app-level config + icon
  app.json5                   bundleName, version, icon, label
  resources/base/             app_name string, app_icon.png
build-profile.json5           signingConfigs, products (API 12), modules
oh-package.json5              root package (hypium/hamock dev deps)
hvigorfile.ts                 hvigor entry (appTasks)
hvigor/hvigor-config.json5    hvigor model/execution config
entry/                        the single HAP module
  build-profile.json5         stageMode, targets, release obfuscation
  hvigorfile.ts               hapTasks
  oh-package.json5            module package
  obfuscation-rules.txt
  src/main/
    module.json5              EntryAbility, INTERNET/GET_NETWORK_INFO
    ets/
      entryability/EntryAbility.ets
      pages/Index.ets         launcher home (@Entry, Navigation root)
      pages/RunnerPage.ets    project runner (NavDestination, Web)
      components/UrlEntryBar.ets
      components/RecentProjectsSection.ets
      model/ProjectEntry.ets
      model/RecentProjectsStore.ets
      runtime/RuntimeBridge.ets
      runtime/DevServerClient.ets
      utils/ExpoUrl.ets
    resources/base/           strings, colors, main_pages.json, media
  src/test/ExpoUrl.test.ets   local unit tests (pure logic, hypium)
```

## Implementation scope

**Functional now**

- Launcher UI: dark-themed home with URL entry, "Scan QR code", recents list.
- `exp://` / `exps://` → `http(s)://` normalization and validation.
- QR scanning via the Scan Kit system picker (`startScanForResult`), which
  needs no app-declared camera permission.
- Recent-project persistence (`preferences`).
- Runner page: loads the project URL in ArkWeb (`Web` component) with JS +
  DOM storage enabled — Expo **web** exports and any web-served page run.
- Dev-server probing: `DevServerClient.probe()` hits `/status` and
  `/manifest` to detect Metro/Expo servers (best-effort, used for labeling).
- Local unit tests for `ExpoUrl` (`entry/src/test`).

**Placeholder / not implemented**

- **React Native bundle execution.** `HermesRuntimeBridge` exists only as an
  interface stub whose `prepare()` rejects. Running an RN bundle on
  HarmonyOS NEXT requires (a) a JS engine for OHOS (Hermes fork, JSC via
  NativeEngine, or V8), (b) a NAPI bridge for the RN bridge/turbo-module
  surface, and (c) ArkTS/ArkUI view managers for core RN components. None of
  that exists yet.
- `exp://` deep-link interception via a `want` handler (system would open
  this app for scanned links).
- Metro fast-refresh websocket hookup, dev-menu overlay, error overlay.

### ArkTS / HarmonyOS NEXT limitations to know

- ArkTS is a statically-typed, restricted TypeScript dialect: no dynamic
  `eval`, no prototype patching, no structural typing tricks — which is why a
  JS engine bridge (not ArkTS itself) must execute RN bundles.
- There is no official Hermes/JSC build for OHOS; `NativeEngine` (ArkCompiler
  NAPI) is the realistic JS-engine path, or a Web-based JS engine — both
  future work.
- `Web` (ArkWeb) can execute the **web** target of an Expo app today; it
  cannot run a React Native bundle (RN needs its own runtime + view layer).
- `exp://` URLs are normalized to `http://`; running `expo start --web`
  output works in the WebView bridge.

## Prerequisites

- **DevEco Studio 5.x** (build for HarmonyOS NEXT / API 12+).
- **HarmonyOS NEXT SDK** (API 12 — `compatibleSdkVersion 5.0.0(12)`), installed
  via DevEco's SDK Manager.
- A HarmonyOS NEXT device or emulator.
- Signing: a debug signature configured in DevEco
  (*File → Project Structure → Signing Configs*) or a real developer
  certificate/profile for release builds.

## Build & run

1. Open the repo root in DevEco Studio 5.x. It resolves `oh_modules`
   automatically (`File → Sync and Refresh Project` if needed).
2. Configure signing for the `default` product.
3. Select the `entry` module and a HarmonyOS NEXT device/emulator, then
   **Run** (`Shift+F10`). The app installs and launches the launcher.
4. Command line (with the DevEco toolchain on PATH):

   ```bash
   hvigorw assembleHap --mode module -p product=default
   ```

   Output lands in `entry/build/default/outputs/default/`.

5. Unit tests (host-side, pure-logic):

   ```bash
   hvigorw test
   ```

## Trying it

- Point the URL bar at any web server, e.g. `http://<host>:<port>` — it loads
  in the WebView runner.
- For Expo projects, start with the web target: `npx expo start --web` (or
  the web export of a project) and enter the printed URL. A persistent
  in-app banner makes clear that this is the WebView runtime, not RN.

## Next steps

1. JS-engine spike: evaluate NativeEngine/Hermes-on-OHOS viability for the
   `HermesRuntimeBridge`.
2. `customScan` in-app camera UI (requires `ohos.permission.CAMERA` with a
   `usedScene` declaration).
3. `want`/deep-link handling so scanning an Expo QR code in any app opens
   here directly.
4. Metro integration: fast refresh websocket, dev menu, red-box overlay.
5. Release signing config + HAP packaging docs.

## License

Apache-2.0
