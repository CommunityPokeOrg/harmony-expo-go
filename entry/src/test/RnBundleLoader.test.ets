import { describe, it, expect } from '@ohos/hypium';
import { RnBundleLoader } from '../main/ets/runtime/rn/RnBundleLoader';

export default function rnBundleLoaderTest() {
  describe('RnBundleLoader.bundleUrl', () => {
    it('builds_index_bundle_url_with_harmony_platform', () => {
      expect(RnBundleLoader.bundleUrl('http://192.168.1.10:8081'))
        .assertEqual('http://192.168.1.10:8081/index.bundle?platform=harmony&dev=true&hot=false&minify=false');
    });

    it('strips_project_paths_and_keeps_origin', () => {
      expect(RnBundleLoader.bundleUrl('https://tunnel.example.com/@me/app'))
        .assertEqual('https://tunnel.example.com/index.bundle?platform=harmony&dev=true&hot=false&minify=false');
    });

    it('honours_a_custom_entry_point', () => {
      expect(RnBundleLoader.bundleUrl('http://host:8081', 'main'))
        .assertEqual('http://host:8081/main.bundle?platform=harmony&dev=true&hot=false&minify=false');
    });
  });
}
