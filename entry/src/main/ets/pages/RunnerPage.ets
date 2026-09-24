import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { DevMenuOverlay } from '../components/DevMenuOverlay';
import { RedboxOverlay } from '../components/RedboxOverlay';
import { MetroHotClient, MetroHotStatus } from '../metro/MetroHotClient';
import { ProjectEntry } from '../model/ProjectEntry';
import { DevServerClient } from '../runtime/DevServerClient';
import { RuntimeBridge, RuntimeBridgeRegistry, WebViewRuntimeBridge } from '../runtime/RuntimeBridge';

/**
 * Runner destination: hosts whatever the selected RuntimeBridge renders.
 *
 * FUNCTIONAL — loads the project URL in an ArkWeb Web component (Expo web
 * exports and any web-served content run for real). On top of that:
 *   - dev-menu overlay (Reload / fast-refresh toggle / probe / copy URL),
 *     opened via the floating DEV button;
 *   - Metro `/hot` WebSocket — connects automatically when the target
 *     probes as a Metro/Expo dev server; 'update-done' reloads the page
 *     (the WebView runtime cannot apply in-bundle hot updates, so it
 *     reloads instead — see README);
 *   - redbox overlay for Metro build errors and ArkWeb load/console errors.
 *
 * NOT IMPLEMENTED — React Native bundle execution; a clearly-marked banner
 * states the current scope.
 */
@Component
export struct RunnerPage {
  project: ProjectEntry = new ProjectEntry('', '', 'url', 0);
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: RuntimeBridge = RuntimeBridgeRegistry.createFor(this.project);
  private hot: MetroHotClient = new MetroHotClient();
  @State private pageReady: boolean = false;
  @State private lastError: string = '';
  @State private hotStatus: MetroHotStatus = MetroHotStatus.OFF;
  @State private bundleUpdating: boolean = false;
  @State private showDevMenu: boolean = false;
  @State private redboxVisible: boolean = false;
  @State private redboxTitle: string = '';
  @State private redboxMessage: string = '';
  @State private probeSummary: string = '';

  aboutToAppear(): void {
    const bridge = this.bridge;
    if (bridge instanceof WebViewRuntimeBridge) {
      bridge.attach(this.controller);
    }
    bridge.prepare(this.project).catch((err: Error) => {
      this.lastError = err.message;
    });
    this.wireHotClient();
    this.probeServer(true);
  }

  aboutToDisappear(): void {
    this.hot.dispose();
    this.bridge.dispose();
  }

  private wireHotClient(): void {
    this.hot.onStatusChange = (status: MetroHotStatus) => {
      this.hotStatus = status;
    };
    this.hot.onUpdateStart = () => {
      this.bundleUpdating = true;
    };
    this.hot.onUpdateDone = () => {
      this.bundleUpdating = false;
      // The WebView runtime cannot apply HMR module updates in-place, so a
      // completed Metro rebuild falls back to a full page reload.
      this.bridge.reload();
    };
    this.hot.onMetroError = (errorType: string, description: string) => {
      this.bundleUpdating = false;
      this.showRedbox(errorType, description);
    };
    this.hot.onReloadRequested = () => {
      // 'r' in `expo start` broadcasts a reload frame over /hot.
      this.bundleUpdating = false;
      this.bridge.reload();
    };
    this.hot.onDevMenuRequested = () => {
      // 'd' in `expo start` broadcasts a dev-menu frame over /hot.
      this.showDevMenu = true;
    };
  }

  private probeServer(autoConnect: boolean): void {
    this.probeSummary = 'Probing…';
    DevServerClient.probe(this.project.url).then((info) => {
      if (info.isExpoDevServer) {
        this.probeSummary = info.manifestName.length > 0
          ? 'Metro/Expo dev server — ' + info.manifestName
          : 'Metro/Expo dev server';
        if (autoConnect) {
          this.hot.connect(this.project.url);
        }
      } else if (info.reachable) {
        this.probeSummary = 'Reachable, but not a Metro dev server';
      } else {
        this.probeSummary = info.error.length > 0 ? info.error : 'Not reachable';
      }
    }).catch(() => {
      this.probeSummary = 'Probe failed';
    });
  }

  private showRedbox(title: string, message: string): void {
    this.redboxTitle = title.length > 0 ? title : 'Error';
    this.redboxMessage = message;
    this.redboxVisible = true;
  }

  private copyUrl(): void {
    const board = pasteboard.getSystemPasteboard();
    board.setData(pasteboard.createPlainTextData(this.project.url));
    promptAction.showToast({ message: 'Project URL copied' });
  }

  @Builder
  private StatusBanner() {
    Row({ space: 6 }) {
      Text('WebView runtime — RN bundle execution is not implemented')
        .fontSize(11)
        .fontColor($r('app.color.text_muted'))
      Blank()
      if (this.hotStatus === MetroHotStatus.CONNECTED) {
        Text('fast refresh')
          .fontSize(10)
          .fontColor($r('app.color.expo_accent'))
      } else if (this.hotStatus === MetroHotStatus.CONNECTING) {
        Text('connecting…')
          .fontSize(10)
          .fontColor($r('app.color.text_muted'))
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .backgroundColor($r('app.color.surface'))
    .justifyContent(FlexAlign.Center)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(this.project.name)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.project.url)
                .fontSize(11)
                .fontColor($r('app.color.text_muted'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('Reload')
              .fontSize(14)
              .fontColor($r('app.color.expo_accent'))
              .onClick(() => {
                this.bridge.reload();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })

          if (this.lastError.length > 0) {
            Column({ space: 8 }) {
              Text('Could not prepare runtime')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text(this.lastError)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .padding(24)
          } else {
            Stack() {
              Web({ src: this.project.url, controller: this.controller })
                .javaScriptAccess(true)
                .domStorageAccess(true)
                .mixedMode(MixedMode.All)
                .onPageBegin(() => {
                  this.pageReady = false;
                })
                .onPageEnd(() => {
                  this.pageReady = true;
                })
                .onErrorReceive((event) => {
                  if (event !== undefined && event.request.isMainFrame()) {
                    this.lastError = event.error.getErrorInfo();
                    promptAction.showToast({ message: 'Failed to load project' });
                  }
                })
                .onConsole((event) => {
                  if (event !== undefined &&
                    event.message.getMessageLevel() === webview.MessageLevel.Error) {
                    this.showRedbox('JS console error',
                      event.message.getMessage() + ' (' +
                      event.message.getSourceId() + ':' +
                      event.message.getLineNumber() + ')');
                  }
                  return false;
                })
                .width('100%')
                .height('100%')

              if (!this.pageReady) {
                Column({ space: 10 }) {
                  LoadingProgress()
                    .width(36)
                    .height(36)
                    .color($r('app.color.expo_accent'))
                  Text(this.bundleUpdating ? 'Applying update…' : 'Loading project…')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')
                .height('100%')
                .justifyContent(FlexAlign.Center)
                .backgroundColor($r('app.color.page_background'))
              }
            }
            .layoutWeight(1)
          }

          this.StatusBanner()
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_background'))

        // Floating DEV button — opens the dev menu overlay.
        Text('DEV')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.expo_accent'))
          .borderRadius(14)
          .margin({ right: 16, bottom: 48 })
          .opacity(this.redboxVisible || this.showDevMenu ? 0 : 0.9)
          .onClick(() => {
            this.showDevMenu = true;
          })

        if (this.showDevMenu) {
          DevMenuOverlay({
            projectUrl: this.project.url,
            hotStatus: this.hotStatus,
            probeSummary: this.probeSummary,
            onReload: () => {
              this.showDevMenu = false;
              this.bridge.reload();
            },
            onToggleHot: () => {
              if (this.hotStatus === MetroHotStatus.CONNECTED ||
                this.hotStatus === MetroHotStatus.CONNECTING) {
                this.hot.disconnect();
              } else {
                this.hot.connect(this.project.url);
              }
            },
            onProbe: () => {
              this.probeServer(false);
            },
            onCopyUrl: () => {
              this.copyUrl();
            },
            onClose: () => {
              this.showDevMenu = false;
            },
          })
        }

        if (this.redboxVisible) {
          RedboxOverlay({
            title: this.redboxTitle,
            message: this.redboxMessage,
            onReload: () => {
              this.redboxVisible = false;
              this.bridge.reload();
            },
            onDismiss: () => {
              this.redboxVisible = false;
            },
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .title(this.project.name)
    .hideTitleBar(false)
    .backgroundColor($r('app.color.page_background'))
  }
}
