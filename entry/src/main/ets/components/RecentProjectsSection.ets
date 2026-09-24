import { ProjectEntry } from '../model/ProjectEntry';

/**
 * Recent projects list — persisted via RecentProjectsStore.
 */
@Component
export struct RecentProjectsSection {
  entries: ProjectEntry[] = [];
  onOpen: (entry: ProjectEntry) => void = () => {
  };
  onRemove: (entry: ProjectEntry) => void = () => {
  };
  onClear: () => void = () => {
  };

  private formatWhen(ts: number): string {
    if (ts <= 0) {
      return '';
    }
    const date = new Date(ts);
    const pad = (n: number) => (n < 10 ? '0' + n : '' + n);
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
      `${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  @Builder
  private EntryRow(entry: ProjectEntry) {
    Row() {
      Column({ space: 2 }) {
        Text(entry.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(entry.url)
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 2 }) {
        Text(this.formatWhen(entry.lastOpenedAt))
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
        Text(entry.source === 'qr' ? 'QR' : 'URL')
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          .borderRadius(4)
          .backgroundColor($r('app.color.surface_secondary'))
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .onClick(() => {
      this.onOpen(entry);
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.onRemove(entry);
        })
    )
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('Recently opened')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
        Blank()
        if (this.entries.length > 0) {
          Text('Clear')
            .fontSize(13)
            .fontColor($r('app.color.text_muted'))
            .onClick(() => {
              this.onClear();
            })
        }
      }
      .width('100%')

      if (this.entries.length === 0) {
        Column({ space: 6 }) {
          Text('No projects yet')
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
          Text('Scan a QR code from “expo start” or enter a URL above. ' +
            'Web exports render in-app; RN bundle execution is not yet implemented.')
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(24)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(12)
      } else {
        List({ space: 8 }) {
          ForEach(this.entries, (entry: ProjectEntry) => {
            ListItem() {
              this.EntryRow(entry)
            }
          }, (entry: ProjectEntry) => entry.url)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .layoutWeight(1)
  }
}
