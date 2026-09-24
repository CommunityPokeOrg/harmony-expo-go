import { http } from '@kit.NetworkKit';
import { ExpoUrl } from '../../utils/ExpoUrl';

/**
 * FUNCTIONAL — fetches the React Native bundle Metro serves for a project.
 *
 * Metro answers GET /<entry>.bundle?platform=<p>&dev=<d>&hot=<h>&minify=<m>
 * with the concatenated JS bundle. `platform=harmony` is sent verbatim —
 * Metro accepts arbitrary platform strings and will resolve `*.harmony.*`
 * file suffixes, which is what a real HarmonyOS port wants.
 *
 * This performs the network side only: it returns bundle source text. It
 * does NOT execute the bundle (that needs a JsEngineAdapter plus the RN
 * bridge module surface — see docs/rn-bridge-architecture.md).
 */
export class RnBundleLoader {
  /** Bundle URL for a normalized project URL. Entry defaults to index. */
  static bundleUrl(projectUrl: string, entry: string = 'index'): string {
    const base = ExpoUrl.devServerBase(projectUrl);
    return base + '/' + entry + '.bundle?platform=harmony&dev=true&hot=false&minify=false';
  }

  /**
   * Downloads the bundle text. Rejects on non-2xx or non-text responses.
   * Large bundles (several MB) are normal — readTimeout is generous.
   */
  static async fetchBundle(projectUrl: string, entry: string = 'index'): Promise<string> {
    const url = RnBundleLoader.bundleUrl(projectUrl, entry);
    const request = http.createHttp();
    try {
      const resp = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 60000,
      });
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        throw new Error('bundle fetch failed: HTTP ' + resp.responseCode);
      }
      if (typeof resp.result !== 'string' || resp.result.length === 0) {
        throw new Error('bundle fetch returned no text payload');
      }
      return resp.result;
    } finally {
      request.destroy();
    }
  }
}
