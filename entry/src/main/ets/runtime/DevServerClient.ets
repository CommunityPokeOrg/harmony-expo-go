import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ExpoUrl } from '../utils/ExpoUrl';

export interface DevServerInfo {
  /** The base URL responded at all. */
  reachable: boolean;
  /** The endpoint looks like a Metro/Expo dev server (`/status` probe). */
  isExpoDevServer: boolean;
  /** Project name parsed from /manifest when available. */
  manifestName: string;
  /** Human-readable detail about the last failed step, if any. */
  error: string;
}

/**
 * FUNCTIONAL (best-effort) — probes a Metro/Expo dev server over HTTP.
 *
 * Metro answers GET /status with "packager-status:running" and GET /manifest
 * with the expo-updates manifest JSON (which carries `name`/`slug` for Expo
 * projects). Used only to label/annotate launcher entries — the runner itself
 * goes through RuntimeBridge.
 */
export class DevServerClient {
  static async probe(projectUrl: string): Promise<DevServerInfo> {
    const base = ExpoUrl.devServerBase(projectUrl);
    const info: DevServerInfo = {
      reachable: false,
      isExpoDevServer: false,
      manifestName: '',
      error: '',
    };

    const status = await DevServerClient.get(base + '/status');
    if (status === null) {
      info.error = 'No response from ' + base + '/status';
      return info;
    }
    info.reachable = true;
    info.isExpoDevServer = status.indexOf('packager-status:running') >= 0;

    const manifest = await DevServerClient.get(base + '/manifest');
    if (manifest !== null) {
      try {
        const parsed = JSON.parse(manifest) as Record<string, Object>;
        const name = parsed['name'];
        const slug = parsed['slug'];
        if (typeof name === 'string' && name.length > 0) {
          info.manifestName = name;
        } else if (typeof slug === 'string' && slug.length > 0) {
          info.manifestName = slug;
        }
      } catch (e) {
        // Manifest endpoint not JSON — fine, probe is best-effort.
      }
    }
    return info;
  }

  private static get(url: string): Promise<string | null> {
    const request = http.createHttp();
    return request.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 4000,
      readTimeout: 4000,
    }).then((resp) => {
      request.destroy();
      if (resp.responseCode >= 200 && resp.responseCode < 300 &&
          typeof resp.result === 'string') {
        return resp.result;
      }
      return null;
    }).catch((err: BusinessError) => {
      request.destroy();
      return null;
    });
  }
}
