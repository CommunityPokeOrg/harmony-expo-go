import { ViewNode } from './ViewNode';

/**
 * Shadow view tree — models the native side of RN's UIManager protocol.
 *
 * On Android/iOS, the JS thread issues batched view ops to UIManager:
 * createView / setChildren / updateView / manageChildren (move/remove) /
 * setRoot. This class reproduces that contract in ArkTS so a future JS
 * engine adapter can dispatch real UIManager commands onto it. The mounted
 * tree is then rendered by RnSurface (ArkUI view-manager surface).
 *
 * FUNCTIONAL — pure data structure, unit-tested. No layout engine (Yoga)
 * and no measure pass: layout props are interpreted directly by the
 * ArkUI renderer, which is an approximation of Yoga's flexbox.
 */
export class ShadowTree {
  private nodes: Map<number, ViewNode> = new Map();
  private rootTag: number = -1;
  /** Fires after every mutation batch; the renderer bumps a @State counter. */
  onChange: () => void = () => {
  };

  /** Registers a mounted root. RN uses odd tags for root views. */
  setRoot(tag: number): void {
    this.rootTag = tag;
    this.onChange();
  }

  getRoot(): ViewNode | null {
    const n = this.nodes.get(this.rootTag);
    return n !== undefined ? n : null;
  }

  /** UIManager.createView(tag, className, rootTag?, props). */
  createView(tag: number, className: string, props: Record<string, string | number | boolean>): ViewNode {
    const node = new ViewNode(tag, className);
    node.props = props;
    this.nodes.set(tag, node);
    this.onChange();
    return node;
  }

  getNode(tag: number): ViewNode | null {
    const n = this.nodes.get(tag);
    return n !== undefined ? n : null;
  }

  /** UIManager.setChildren(parentTag, childTags) — replaces all children. */
  setChildren(parentTag: number, childTags: number[]): void {
    const parent = this.getNode(parentTag);
    if (parent === null) {
      return;
    }
    const kids: ViewNode[] = [];
    for (const t of childTags) {
      const child = this.getNode(t);
      if (child !== null) {
        kids.push(child);
      }
    }
    parent.children = kids;
    this.onChange();
  }

  /** UIManager.updateView(tag, className, props) — merges props. */
  updateView(tag: number, props: Record<string, string | number | boolean>): void {
    const node = this.getNode(tag);
    if (node === null) {
      return;
    }
    const keys = Object.keys(props);
    for (const key of keys) {
      node.props[key] = props[key];
    }
    this.onChange();
  }

  /** manageChildren remove-path: drops the given tags from their parents. */
  removeChildren(childTags: number[]): void {
    const drop = new Set<number>();
    for (const t of childTags) {
      drop.add(t);
    }
    for (const entry of this.nodes) {
      const node = entry[1];
      if (node.children.some((c) => drop.has(c.tag))) {
        node.children = node.children.filter((c) => !drop.has(c.tag));
      }
    }
    for (const t of childTags) {
      this.deleteSubtree(t);
    }
    this.onChange();
  }

  private deleteSubtree(tag: number): void {
    const node = this.getNode(tag);
    if (node === null) {
      return;
    }
    for (const child of node.children) {
      this.deleteSubtree(child.tag);
    }
    this.nodes.delete(tag);
  }

  clear(): void {
    this.nodes.clear();
    this.rootTag = -1;
    this.onChange();
  }

  nodeCount(): number {
    return this.nodes.size;
  }
}
