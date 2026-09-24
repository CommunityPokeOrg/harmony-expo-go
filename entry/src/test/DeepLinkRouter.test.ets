import { describe, it, expect } from '@ohos/hypium';
import { DeepLinkRouter } from '../main/ets/deeplink/DeepLinkRouter';

export default function deepLinkRouterTest() {
  describe('DeepLinkRouter', () => {
    it('queues_links_until_a_listener_subscribes', () => {
      const router = DeepLinkRouter.instance;
      router.resetForTest();
      router.dispatch('exp://192.168.1.10:8081');
      router.dispatch('exps://tunnel.example.com');

      const received: string[] = [];
      router.setListener((raw: string) => {
        received.push(raw);
      });
      expect(received.length).assertEqual(2);
      expect(received[0]).assertEqual('exp://192.168.1.10:8081');
      expect(received[1]).assertEqual('exps://tunnel.example.com');
      router.resetForTest();
    });

    it('delivers_immediately_once_a_listener_exists', () => {
      const router = DeepLinkRouter.instance;
      router.resetForTest();
      const received: string[] = [];
      router.setListener((raw: string) => {
        received.push(raw);
      });
      router.dispatch('exp://10.0.0.1:8081');
      expect(received.length).assertEqual(1);
      router.resetForTest();
    });

    it('ignores_empty_uris', () => {
      const router = DeepLinkRouter.instance;
      router.resetForTest();
      router.dispatch('');
      const received: string[] = [];
      router.setListener((raw: string) => {
        received.push(raw);
      });
      expect(received.length).assertEqual(0);
      router.resetForTest();
    });

    it('clearListener_reverts_to_queueing', () => {
      const router = DeepLinkRouter.instance;
      router.resetForTest();
      const received: string[] = [];
      router.setListener((raw: string) => {
        received.push(raw);
      });
      router.clearListener();
      router.dispatch('exp://10.0.0.2:8081');
      expect(received.length).assertEqual(0);

      const later: string[] = [];
      router.setListener((raw: string) => {
        later.push(raw);
      });
      expect(later.length).assertEqual(1);
      router.resetForTest();
    });
  });
}
