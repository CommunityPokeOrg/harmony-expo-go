/**
 * FUNCTIONAL — redbox-style error overlay.
 *
 * Shown over the runner when the Metro /hot socket reports a build error, or
 * when the WebView runtime surfaces a load/console error. Displays the error
 * type, the description text, and offers Reload / Dismiss. Under the WebView
 * runtime there is no JS stack to show — the description is whatever Metro or
 * ArkWeb reported.
 */
@Component
export struct RedboxOverlay {
  title: string = 'Error';
  message: string = '';
  onReload: () => void = () => {
  };
  onDismiss: () => void = () => {
  };

  build() {
    Column() {
      Column({ space: 10 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width('100%')

        Scroll() {
          Text(this.message.length > 0 ? this.message : 'Unknown error')
            .fontSize(13)
            .fontColor(Color.White)
            .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)

        Row({ space: 12 }) {
          Button('Reload')
            .onClick(() => {
              this.onReload();
            })
            .backgroundColor(Color.White)
            .fontColor($r('app.color.error_red_deep'))
            .borderRadius(8)
            .layoutWeight(1)

          Button('Dismiss')
            .onClick(() => {
              this.onDismiss();
            })
            .backgroundColor($r('app.color.error_red_deep'))
            .fontColor(Color.White)
            .borderRadius(8)
            .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding(20)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.error_red'))
  }
}
