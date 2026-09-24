/**
 * Normalization helpers for Expo-style URLs.
 *
 * Accepted inputs:
 *   exp://192.168.1.10:8081        (classic Expo QR-code deep link)
 *   exps://tunnel.example.com      (TLS variant)
 *   http(s)://host:port[/path]
 *   192.168.1.10:8081              (bare host[:port], assumed http)
 *
 * Output is always an http(s):// URL usable by the WebView runtime bridge.
 */
export class ExpoUrl {
  /**
   * Returns a normalized http(s) URL, or null when the input cannot be
   * interpreted as a project URL.
   */
  static normalize(raw: string): string | null {
    let value = raw.trim();
    if (value.length === 0) {
      return null;
    }

    if (value.startsWith('exps://')) {
      value = 'https://' + value.substring('exps://'.length);
    } else if (value.startsWith('exp://')) {
      value = 'http://' + value.substring('exp://'.length);
    } else if (!value.includes('://')) {
      // Bare host[:port][/path] typed into the URL bar.
      value = 'http://' + value;
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return null;
    }

    const host = ExpoUrl.hostOf(value);
    if (host === null || host.length === 0) {
      return null;
    }
    return value;
  }

  static isSupported(url: string): boolean {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /** Origin portion (scheme://host:port) — the Metro dev-server base URL. */
  static devServerBase(url: string): string {
    const schemeEnd = url.indexOf('://');
    if (schemeEnd < 0) {
      return url;
    }
    const rest = url.substring(schemeEnd + 3);
    const slash = rest.indexOf('/');
    const authority = slash < 0 ? rest : rest.substring(0, slash);
    return url.substring(0, schemeEnd + 3) + authority;
  }

  static displayName(url: string): string {
    const base = ExpoUrl.devServerBase(url);
    const schemeEnd = base.indexOf('://');
    return schemeEnd >= 0 ? base.substring(schemeEnd + 3) : base;
  }

  private static hostOf(url: string): string | null {
    const schemeEnd = url.indexOf('://');
    if (schemeEnd < 0) {
      return null;
    }
    const rest = url.substring(schemeEnd + 3);
    const slash = rest.indexOf('/');
    const authority = slash < 0 ? rest : rest.substring(0, slash);
    const colon = authority.indexOf(':');
    return colon < 0 ? authority : authority.substring(0, colon);
  }
}
