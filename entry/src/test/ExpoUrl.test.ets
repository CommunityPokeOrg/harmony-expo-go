import { describe, it, expect } from '@ohos/hypium';
import { ExpoUrl } from '../main/ets/utils/ExpoUrl';

export default function expoUrlTest() {
  describe('ExpoUrl', () => {
    it('normalizes_exp_scheme_to_http', () => {
      expect(ExpoUrl.normalize('exp://192.168.1.10:8081')).assertEqual('http://192.168.1.10:8081');
    });

    it('normalizes_exps_scheme_to_https', () => {
      expect(ExpoUrl.normalize('exps://tunnel.example.com')).assertEqual('https://tunnel.example.com');
    });

    it('normalizes_bare_host_port_to_http', () => {
      expect(ExpoUrl.normalize('192.168.1.10:8081')).assertEqual('http://192.168.1.10:8081');
    });

    it('keeps_http_and_https_urls', () => {
      expect(ExpoUrl.normalize('http://localhost:8081')).assertEqual('http://localhost:8081');
      expect(ExpoUrl.normalize('https://expo.dev/@me/app')).assertEqual('https://expo.dev/@me/app');
    });

    it('rejects_empty_and_unknown_schemes', () => {
      expect(ExpoUrl.normalize('   ')).assertNull();
      expect(ExpoUrl.normalize('ftp://host/x')).assertNull();
      expect(ExpoUrl.normalize('http://')).assertNull();
    });

    it('extracts_dev_server_base', () => {
      expect(ExpoUrl.devServerBase('http://192.168.1.10:8081/node_modules/expo'))
        .assertEqual('http://192.168.1.10:8081');
    });

    it('builds_display_name', () => {
      expect(ExpoUrl.displayName('http://192.168.1.10:8081/index.bundle'))
        .assertEqual('192.168.1.10:8081');
    });
  });
}
