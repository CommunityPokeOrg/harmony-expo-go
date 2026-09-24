/**
 * A project the launcher can open: an Expo dev-server (Metro) endpoint or any
 * web-served URL rendered through the WebView runtime bridge.
 */
export type ProjectSource = 'url' | 'qr' | 'deepLink';

export class ProjectEntry {
  name: string;
  url: string;
  source: ProjectSource;
  lastOpenedAt: number;

  constructor(name: string, url: string, source: ProjectSource, lastOpenedAt: number) {
    this.name = name;
    this.url = url;
    this.source = source;
    this.lastOpenedAt = lastOpenedAt;
  }

  static fromJson(json: string): ProjectEntry {
    const raw = JSON.parse(json) as ProjectEntry;
    return new ProjectEntry(raw.name, raw.url, raw.source, raw.lastOpenedAt);
  }
}
