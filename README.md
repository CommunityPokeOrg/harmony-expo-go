# harmony-expo-go

An **Expo Go–style runtime client for HarmonyOS NEXT**, written in ArkTS.
Open Expo projects on a HarmonyOS device the way Expo Go does on Android/iOS:
scan a QR code from `expo start`, open an `exp://` deep link, paste a
dev-server URL, and re-open recent projects.

> **Status: early scaffold → functional launcher shell.** Deep-link
> interception, dev-menu/redbox overlays, and the Metro `/hot` socket are
> implemented; native React Native bundle execution is *not* (see
> [Implementation scope](#implementation-scope)).

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Launcher shell (ArkUI, ArkTS)                                │
│  pages/Index.ets        – home: URL bar, QR scan, recents    │
│  pages/RunnerPage.ets   – runner: Web + dev tools overlays   │
│  components/            – UrlEntryBar, RecentProjectsSection │
│                           DevMenuOverlay, RedboxOverlay      │
│  deeplink/DeepLinkRouter – want.uri → launcher delivery      │
│  model/                 – ProjectEntry, RecentProjectsStore  │
│  utils/ExpoUrl.ets      – exp:// → http(s):// normalization  │
├──────────────────────────────────────────────────────────────┤
│ Metro dev tooling                                            │
│  metro/MetroHotClient   – ws(s)://<metro>/hot fast-refresh   │
│                           socket: lifecycle + frame parsing  │
│  runtime/DevServerClient – /status + /manifest probes        │
├──────────────────────────────────────────────────────────────┤
│ Runtime bridge + RN foundation (isolated interfaces)         │
│  runtime/RuntimeBridge.ets – bridge interface, registry,     │
│                              WebViewRuntimeBridge,           │
│                              HermesRuntimeBridge (stub)      │
│  runtime/rn/            – RnBundleLoader, JsEngineAdapter,   │
│                           NativeModuleRegistry, ShadowTree,  │
│                           ViewNode, RnSurface (ArkUI views)  │
└──────────────────────────────────────────────────────────────┘
```

The launcher never talks to an engine directly — it resolves a
`RuntimeBridge` through `RuntimeBridgeRegistry.createFor()`. Today every URL
resolves to `WebViewRuntimeBridge`; a future native RN runtime slots into the
registry without touching launcher UI. The `runtime/rn/` package is the
foundation for that runtime — see
[docs/rn-bridge-architecture.md](docs/rn-bridge-architecture.md).

### Entry paths

| Path                  | Mechanism                                                                                | Status      |
| --------------------- | ---------------------------------------------------------------------------------------- | ----------- |
| QR code               | `scanBarcode.startScanForResult` (system Scan Kit picker — no CAMERA permission needed)    | Functional  |
| URL bar               | `exp://`, `exps://`, `http(s)://`, or bare `host:port`                                     | Functional  |
| Deep links            | `exp://` / `exps://` URI skills on EntryAbility → `want.uri` → `DeepLinkRouter` → launcher | Functional* |
| Recent projects       | `preferences` store, max 20 entries                                                      | Functional  |
| Custom-scan camera UI | `scanCore` customScan component                                                          | Planned     |

\* Functional = declared and routed end-to-end in code; exercised only on a
real device/emulator (see [Deep links](#deep-links)).

### Project structure

```
AppScope/                     app-level config + icon
  app.json5                   bundleName, version, icon, label
  resources/base/             app_name string, app_icon.png
build-profile.json5           signingConfigs, products (API 12), modules
oh-package.json5              root package (hypium/hamock dev deps)
hvigorfile.ts                 hvigor entry (appTasks)
hvigor/hvigor-config.json5    hvigor model/execution config
docs/rn-bridge-architecture.md  engine options + bridge plan
entry/                        the single HAP module
  build-profile.json5         stageMode, targets, release obfuscation
  hvigorfile.ts               hapTasks
  oh-package.json5            module package
  obfuscation-rules.txt
  src/main/
    module.json5              EntryAbility (singleton, exp/exps URI skills),
                              INTERNET/GET_NETWORK_INFO
    ets/
      entryability/EntryAbility.ets   onCreate/onNewWant → DeepLinkRouter
      deeplink/DeepLinkRouter.ets     queued deep-link dispatch
      pages/Index.ets                 launcher home (@Entry, Navigation root)
      pages/RunnerPage.ets            runner (Web + dev menu + redbox)
      components/UrlEntryBar.ets
      components/RecentProjectsSection.ets
      components/DevMenuOverlay.ets   dev-menu bottom sheet
      components/RedboxOverlay.ets    error overlay
      metro/MetroHotClient.ets        /hot websocket + frame parser
      model/ProjectEntry.ets
      model/RecentProjectsStore.ets
      runtime/RuntimeBridge.ets
      runtime/DevServerClient.ets
      runtime/rn/ViewNode.ets         shadow view node
      runtime/rn/ShadowTree.ets       UIManager ops (create/setChildren/…)
      runtime/rn/RnSurface.ets        ArkUI renderer for ViewNode trees
      runtime/rn/JsEngineAdapter.ets  engine interface + ArkWeb adapter +
                                      NativeEngine stub
      runtime/rn/RnBundleLoader.ets   Metro bundle fetch (platform=harmony)
      runtime/rn/NativeModuleRegistry.ets  bridge-call dispatch seam
      utils/ExpoUrl.ets
    resources/base/           strings, colors, main_pages.json, media
  src/test/                   local unit tests (pure logic, hypium)
```

## Implementation scope

**Functional now**

- Launcher UI: dark-themed home with URL entry, "Scan QR code", recents list.
- `exp://` / `exps://` → `http(s)://` normalization and validation, applied
  to the URL bar, QR results, and deep links alike.
- QR scanning via the Scan Kit system picker (`startScanForResult`), which
  needs no app-declared camera permission.
- `exp://` / `exps://` deep-link interception: URI skills declared in
  `module.json5`, `EntryAbility.onCreate`/`onNewWant` forward `want.uri`
  through `DeepLinkRouter`, and the launcher validates + opens them.
- Recent-project persistence (`preferences`), including deep-link entries.
- Runner page: loads the project URL in ArkWeb (`Web` component) with JS +
  DOM storage enabled — Expo **web** exports and any web-served page run.
- Dev-server probing: `DevServerClient.probe()` hits `/status` and
  `/manifest` to detect Metro/Expo servers (used for labeling and to decide
  whether to auto-connect fast refresh).
- Metro fast-refresh socket: `MetroHotClient` connects to
  `ws(s)://<metro>/hot`, parses Metro's frame types (`update-start`,
  `update`, `update-done`, `error`, `warning`, `reload`,
  `send-dev-command`, `devMenu`), and on a completed build reloads the
  runner — the WebView runtime can't apply in-bundle HMR, so reload is the
  honest equivalent. `error` frames open the redbox; `reload` frames and
  `send-dev-command:name=reload` (pressing `r` in `expo start`) reload the
  project; `devMenu` frames (`d` in the CLI) open the dev menu.
- Dev-menu overlay: bottom sheet on the runner (floating DEV button) with
  Reload, fast-refresh connect/disconnect + status, dev-server probe, and
  Copy URL.
- Redbox overlay: full-screen error surface for Metro build errors, ArkWeb
  main-frame failures, and JS console errors (via `onConsole`).
- RN foundation: `RnBundleLoader` fetches Metro bundles
  (`?platform=harmony`), `ShadowTree` models UIManager ops, `RnSurface`
  renders `ViewNode` trees for View/Text/Image/ScrollView/TextInput,
  `WebViewJsEngineAdapter` evaluates JS via ArkWeb,
  `NativeModuleRegistry` models the bridge dispatch seam.
- Local unit tests (`entry/src/test`): ExpoUrl, DeepLinkRouter,
  MetroHotMessage/hotUrlFor, ShadowTree, NativeModuleRegistry,
  RnBundleLoader.

**Placeholder / not implemented**

- **React Native bundle execution.** `HermesRuntimeBridge` /
  `NativeEngineAdapter` are explicit stubs that reject. Nothing runs an RN
  bundle yet — `RnSurface` renders data-defined trees, not live RN output.
  The missing native piece (a C++ NAPI module binding `napi_run_script`
  and the `__fbBatchedBridge` hooks) is detailed in
  [docs/rn-bridge-architecture.md](docs/rn-bridge-architecture.md).
- In-bundle fast refresh: the `/hot` socket works, but applies updates via
  full reload because the WebView runtime has no HMR channel.
- `customScan` in-app camera UI (requires `ohos.permission.CAMERA` with a
  `usedScene` declaration).

### ArkTS / HarmonyOS NEXT limitations to know

- ArkTS is a statically-typed, restricted TypeScript dialect: no dynamic
  `eval`, no prototype patching, no structural typing tricks — which is why a
  JS engine bridge (not ArkTS itself) must execute RN bundles.
- There is no official Hermes/JSC build for OHOS; `NativeEngine` (ArkCompiler
  NAPI) is the realistic JS-engine path, or a Web-based JS engine — see
  docs/rn-bridge-architecture.md.
- `Web` (ArkWeb) can execute the **web** target of an Expo app today; it
  cannot run a React Native bundle (RN needs its own runtime + view layer).
- `exp://` URLs are normalized to `http://`; running `expo start --web`
  output works in the WebView bridge.

## Deep links

`EntryAbility` declares an `ohos.want.action.viewData` skill with `uris`
schemes `exp` and `exps`, and `launchType: singleton` so a link arriving
while the app runs delivers through `onNewWant` instead of a second ability.

Flow: system/scanner app sends a want with `uri` → `EntryAbility` (cold or
warm) → `DeepLinkRouter` (queues until the page subscribes) →
`Index.handleDeepLink` → `ExpoUrl.normalize` → runner. Unsupported or
malformed links get a toast and are never pushed onto the runner.

Test on a device/emulator without a QR scan:

```bash
hdc shell aa start -a ohos.want.action.viewData -U "exp://192.168.1.10:8081"
```

Notes:

- Custom schemes rely on another app actually sending the want — most
  third-party QR scanners open the OS browser instead, so the `hdc`
  command is the reliable verification path.
- `https://` App Linking (opening `expo.dev` links) is not registered;
  it would need `linkFeature` + domain verification, which does not apply
  to a dev client pointing at LAN Metro servers.

## Dev tools (runner)

- **DEV button** (bottom-right): opens the dev-menu overlay.
- **Reload project**: `WebviewController.loadUrl` reload.
- **Fast refresh**: shows `/hot` socket state; toggle connects/disconnects.
  Auto-connects on runner open when the project probes as a Metro server.
- **Probe dev server**: re-runs the `/status` + `/manifest` probe and shows
  the result inline.
- **Copy project URL**: system pasteboard.
- **Redbox**: Metro `error` frames and ArkWeb console/page errors appear
  full-screen with Reload / Dismiss.

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
- With `npx expo start` (native Metro), opening the project probes the dev
  server and auto-connects `/hot`; editing the app triggers a build →
  `update-done` → the runner reloads. Bundle JS errors Metro reports arrive
  in the redbox.

## Next steps

1. JS-engine spike: `entry/src/main/cpp` NAPI module exposing
   `napi_run_script` + `__harmonyNativeCall` (see the architecture doc).
2. Bridge bootstrap preamble (`__fbBatchedBridge`, MessageQueue, module
   shims) so a Metro bundle registers against `NativeModuleRegistry`.
3. `customScan` in-app camera UI (requires `ohos.permission.CAMERA` with a
   `usedScene` declaration).
4. Yoga layout + real UIManager measure pass for `RnSurface`.
5. Release signing config + HAP packaging docs.

## License

Apache-2.0
