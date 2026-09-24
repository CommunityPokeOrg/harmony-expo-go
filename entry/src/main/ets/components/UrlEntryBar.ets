import { ExpoUrl } from '../utils/ExpoUrl';
import { promptAction } from '@kit.ArkUI';

/**
 * Manual entry path: type an exp:// / http(s):// URL or bare host:port.
 */
@Component
export struct UrlEntryBar {
  onOpen: (url: string) => void = () => {
  };
  @State private text: string = '';

  private submit(): void {
    const normalized = ExpoUrl.normalize(this.text);
    if (normalized === null) {
      promptAction.showToast({ message: 'Enter an exp:// or http(s):// project URL' });
      return;
    }
    this.text = normalized;
    this.onOpen(normalized);
  }

  build() {
    Row({ space: 8 }) {
      TextInput({ text: $$this.text, placeholder: 'exp://… or 192.168.1.10:8081' })
        .type(InputType.Url)
        .enterKeyType(EnterKeyType.Go)
        .onSubmit(() => {
          this.submit();
        })
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_muted'))
        .borderRadius(10)
        .height(44)
        .layoutWeight(1)

      Button('Open')
        .onClick(() => {
          this.submit();
        })
        .backgroundColor($r('app.color.expo_accent'))
        .fontColor(Color.White)
        .borderRadius(10)
        .height(44)
    }
    .width('100%')
  }
}
