import { describe, it, expect } from '@ohos/hypium';
import { ShadowTree } from '../main/ets/runtime/rn/ShadowTree';
import { NativeModuleRegistry } from '../main/ets/runtime/rn/NativeModuleRegistry';

export default function shadowTreeTest() {
  describe('ShadowTree', () => {
    it('create_setChildren_and_getRoot_build_a_tree', () => {
      const tree = new ShadowTree();
      tree.createView(1, 'View', {});
      tree.createView(2, 'Text', { text: 'hello' });
      tree.createView(3, 'Image', { source: 'http://x/y.png' });
      tree.setChildren(1, [2, 3]);
      tree.setRoot(1);

      const root = tree.getRoot();
      expect(root !== null).assertTrue();
      if (root !== null) {
        expect(root.className).assertEqual('View');
        expect(root.children.length).assertEqual(2);
        expect(root.children[0].textContent()).assertEqual('hello');
      }
      expect(tree.nodeCount()).assertEqual(3);
    });

    it('updateView_merges_props', () => {
      const tree = new ShadowTree();
      tree.createView(1, 'Text', { text: 'a', fontSize: 14 });
      tree.updateView(1, { text: 'b' });
      const node = tree.getNode(1);
      expect(node !== null).assertTrue();
      if (node !== null) {
        expect(node.str('text')).assertEqual('b');
        expect(node.num('fontSize')).assertEqual(14);
      }
    });

    it('removeChildren_detaches_and_deletes_subtrees', () => {
      const tree = new ShadowTree();
      tree.createView(1, 'View', {});
      tree.createView(2, 'View', {});
      tree.createView(3, 'Text', { text: 'gone' });
      tree.setChildren(1, [2]);
      tree.setChildren(2, [3]);

      tree.removeChildren([2]);
      const root = tree.getNode(1);
      if (root !== null) {
        expect(root.children.length).assertEqual(0);
      }
      expect(tree.getNode(2)).assertNull();
      expect(tree.getNode(3)).assertNull();
      expect(tree.nodeCount()).assertEqual(1);
    });

    it('setChildren_ignores_unknown_tags', () => {
      const tree = new ShadowTree();
      tree.createView(1, 'View', {});
      tree.setChildren(1, [999]);
      const root = tree.getNode(1);
      if (root !== null) {
        expect(root.children.length).assertEqual(0);
      }
    });
  });

  describe('NativeModuleRegistry', () => {
    it('dispatches_calls_and_encodes_results', () => {
      const registry = new NativeModuleRegistry();
      registry.register({
        name: 'Echo',
        getConstants(): Record<string, Object> {
          return { version: '1' };
        },
        invoke(method: string, args: Object[]): Object {
          if (method === 'join') {
            return args.join(',');
          }
          throw new Error('unknown method ' + method);
        }
      });

      const ok = registry.call('Echo', 'join', '["a","b"]');
      expect(ok.indexOf('"ok":true') >= 0).assertTrue();
      expect(ok.indexOf('"result":"a,b"') >= 0).assertTrue();

      const bad = registry.call('Echo', 'nope', '[]');
      expect(bad.indexOf('"ok":false') >= 0).assertTrue();

      const missing = registry.call('Missing', 'x', '[]');
      expect(missing.indexOf('unknown module') >= 0).assertTrue();
    });
  });
}
