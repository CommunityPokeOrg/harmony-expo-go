import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UrlEntryBar } from '../components/UrlEntryBar';
import { RecentProjectsSection } from '../components/RecentProjectsSection';
import { ProjectEntry } from '../model/ProjectEntry';
import { RecentProjectsStore } from '../model/RecentProjectsStore';
import { ExpoUrl } from '../utils/ExpoUrl';
import { RunnerPage } from './RunnerPage';

const ROUTE_RUNNER = 'runner';
const DOMAIN = 0x0001;
const TAG = 'Index';

@Entry
@Component
struct Index {
  @State private recents: ProjectEntry[] = [];
  private pathStack: NavPathStack = new NavPathStack();
  private store: RecentProjectsStore =
    RecentProjectsStore.get(getContext(this) as common.UIAbilityContext);

  aboutToAppear(): void {
    this.refreshRecents();
  }

  private refreshRecents(): void {
    this.recents = this.store.list();
  }

  private openProject(url: string, source: 'url' | 'qr'): void {
    const entry = new ProjectEntry(ExpoUrl.displayName(url), url, source, Date.now());
    this.store.remember(entry);
    this.refreshRecents();
    this.pathStack.pushPath({ name: ROUTE_RUNNER, param: entry });
  }

  /**
   * FUNCTIONAL — system Scan Kit picker (scanBarcode.startScanForResult).
   * Runs as a system UI, so the app needs no CAMERA permission for it.
   */
  private scanQr(): void {
    const options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.QR_CODE],
      enableMultiMode: true,
      enableAlbum: true,
    };
    scanBarcode.startScanForResult(getContext(this), options)
      .then((result: scanBarcode.ScanResult) => {
        const value = result.originalValue;
        if (value !== undefined && value.length > 0) {
          this.openProject(value, 'qr');
        }
      })
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'Scan failed: %{public}s', JSON.stringify(err));
        if (err.code !== 1000500001) { // user cancelled
          promptAction.showToast({ message: 'Could not scan QR code' });
        }
      });
  }

  @Builder
  private PageMap(name: string, param: Object) {
    if (name === ROUTE_RUNNER) {
      RunnerPage({ project: param as ProjectEntry })
    }
  }

  build() {
    Navigation(this.pathStack) {
      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text('Expo Go')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('Development client for HarmonyOS NEXT')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        UrlEntryBar({
          onOpen: (url: string) => {
            this.openProject(url, 'url');
          },
        })

        Row({ space: 8 }) {
          Button() {
            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.camera'))
                .fontSize(18)
                .fontColor(Color.White)
              Text('Scan QR code')
                .fontSize(15)
                .fontColor(Color.White)
            }
          }
          .onClick(() => {
            this.scanQr();
          })
          .backgroundColor($r('app.color.expo_accent'))
          .borderRadius(10)
          .height(44)
          .layoutWeight(1)
        }
        .width('100%')

        RecentProjectsSection({
          entries: this.recents,
          onOpen: (entry: ProjectEntry) => {
            const refreshed = new ProjectEntry(entry.name, entry.url, entry.source, Date.now());
            this.store.remember(refreshed);
            this.refreshRecents();
            this.pathStack.pushPath({ name: ROUTE_RUNNER, param: refreshed });
          },
          onRemove: (entry: ProjectEntry) => {
            this.store.remove(entry.url);
            this.refreshRecents();
          },
          onClear: () => {
            this.store.clear();
            this.refreshRecents();
          },
        })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 24, bottom: 16 })
      .backgroundColor($r('app.color.page_background'))
    }
    .navDestination(this.PageMap)
    .hideToolBar(true)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }
}
