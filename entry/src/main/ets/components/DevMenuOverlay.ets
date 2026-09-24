import { MetroHotStatus } from '../metro/MetroHotClient';

/**
 * FUNCTIONAL — Expo-style dev-menu overlay for the runner.
 *
 * Rendered as a bottom sheet over the runner surface (the caller stacks it
 * above the runtime view). Actions: reload project, toggle the Metro /hot
 * fast-refresh socket, re-probe the dev server, copy the project URL.
 */
@Component
export struct DevMenuOverlay {
  projectUrl: string = '';
  hotStatus: MetroHotStatus = MetroHotStatus.OFF;
  probeSummary: string = '';
  onReload: () => void = () => {
  };
  onToggleHot: () => void = () => {
  };
  onProbe: () => void = () => {
  };
  onCopyUrl: () => void = () => {
  };
  onClose: () => void = () => {
  };

  private hotLabel(): string {
    switch (this.hotStatus) {
      case MetroHotStatus.CONNECTED:
        return 'Disconnect fast refresh';
      case MetroHotStatus.CONNECTING:
        return 'Connecting to Metro…';
      case MetroHotStatus.ERROR:
        return 'Fast refresh failed — retry';
      default:
        return 'Connect fast refresh';
    }
  }

  private hotDetail(): string {
    switch (this.hotStatus) {
      case MetroHotStatus.CONNECTED:
        return 'Metro /hot socket live — bundle updates reload the runner';
      case MetroHotStatus.CONNECTING:
        return 'Handshaking ws:///hot';
      case MetroHotStatus.CLOSED:
        return 'Socket closed by Metro';
      case MetroHotStatus.ERROR:
        return 'WebSocket error — is the Metro server up?';
      default:
        return 'Off — connects to ws(s)://<metro>/hot';
    }
  }

  @Builder
  private ActionRow(label: string, detail: string, action: () => void) {
    Row() {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
        if (detail.length > 0) {
          Text(detail)
            .fontSize(11)
            .fontColor($r('app.color.text_muted'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.surface_secondary'))
    .borderRadius(10)
    .onClick(() => {
      action();
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Tap-outside scrim dismisses the menu.
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_scrim'))
        .onClick(() => {
          this.onClose();
        })

      Column({ space: 8 }) {
        Row() {
          Text('Dev menu')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text('Close')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')

        Text(this.projectUrl)
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        this.ActionRow('Reload project', '', () => {
          this.onReload();
        })
        this.ActionRow(this.hotLabel(), this.hotDetail(), () => {
          this.onToggleHot();
        })
        this.ActionRow('Probe dev server', this.probeSummary, () => {
          this.onProbe();
        })
        this.ActionRow('Copy project URL', '', () => {
          this.onCopyUrl();
        })
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface'))
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
    .width('100%')
    .height('100%')
  }
}
