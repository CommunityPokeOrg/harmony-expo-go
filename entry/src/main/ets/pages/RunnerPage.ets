import { promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { ProjectEntry } from '../model/ProjectEntry';
import { RuntimeBridge, RuntimeBridgeRegistry, WebViewRuntimeBridge } from '../runtime/RuntimeBridge';

/**
 * Runner destination: hosts whatever the selected RuntimeBridge renders.
 *
 * FUNCTIONAL — loads the project URL in an ArkWeb Web component (Expo web
 * exports and any web-served content run for real).
 * NOT IMPLEMENTED — React Native bundle execution; a clearly-marked banner
 * states the current scope.
 */
@Component
export struct RunnerPage {
  project: ProjectEntry = new ProjectEntry('', '', 'url', 0);
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: RuntimeBridge = RuntimeBridgeRegistry.createFor(this.project);
  @State private pageReady: boolean = false;
  @State private lastError: string = '';

  aboutToAppear(): void {
    const bridge = this.bridge;
    if (bridge instanceof WebViewRuntimeBridge) {
      bridge.attach(this.controller);
    }
    bridge.prepare(this.project).catch((err: Error) => {
      this.lastError = err.message;
    });
  }

  aboutToDisappear(): void {
    this.bridge.dispose();
  }

  @Builder
  private StatusBanner() {
    Row() {
      Text('WebView runtime — RN bundle execution is not implemented')
        .fontSize(11)
        .fontColor($r('app.color.text_muted'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .backgroundColor($r('app.color.surface'))
    .justifyContent(FlexAlign.Center)
  }

  build() {
    NavDestination() {
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
              .width('100%')
              .height('100%')

            if (!this.pageReady) {
              Column({ space: 10 }) {
                LoadingProgress()
                  .width(36)
                  .height(36)
                  .color($r('app.color.expo_accent'))
                Text('Loading project…')
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
    }
    .title(this.project.name)
    .hideTitleBar(false)
    .backgroundColor($r('app.color.page_background'))
  }
}
