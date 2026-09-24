import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ProjectEntry } from './ProjectEntry';

const STORE_NAME = 'expo_go_recents';
const KEY_RECENTS = 'recent_projects';
const MAX_ENTRIES = 20;

/**
 * Preferences-backed store of recently opened project URLs.
 * Functional: persists across app launches.
 */
export class RecentProjectsStore {
  private static instance: RecentProjectsStore | null = null;
  private prefs: preferences.Preferences;

  private constructor(context: common.UIAbilityContext) {
    this.prefs = preferences.getPreferencesSync(context, { name: STORE_NAME });
  }

  static get(context: common.UIAbilityContext): RecentProjectsStore {
    if (RecentProjectsStore.instance === null) {
      RecentProjectsStore.instance = new RecentProjectsStore(context);
    }
    return RecentProjectsStore.instance;
  }

  list(): ProjectEntry[] {
    const raw = this.prefs.getSync(KEY_RECENTS, '[]') as string;
    try {
      const arr = JSON.parse(raw) as Array<ProjectEntry>;
      return arr.map((e) => new ProjectEntry(e.name, e.url, e.source, e.lastOpenedAt));
    } catch (e) {
      return [];
    }
  }

  remember(entry: ProjectEntry): void {
    const entries = this.list().filter((e) => e.url !== entry.url);
    entries.unshift(entry);
    if (entries.length > MAX_ENTRIES) {
      entries.length = MAX_ENTRIES;
    }
    this.save(entries);
  }

  remove(url: string): void {
    this.save(this.list().filter((e) => e.url !== url));
  }

  clear(): void {
    this.save([]);
  }

  private save(entries: ProjectEntry[]): void {
    this.prefs.putSync(KEY_RECENTS, JSON.stringify(entries));
    this.prefs.flush();
  }
}
