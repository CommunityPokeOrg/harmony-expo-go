/**
 * A node in the React Native shadow view tree.
 *
 * Mirrors what RN's UIManager produces on the native side: a flat map of
 * tagged nodes, each with a registered view class name ('View', 'Text',
 * 'Image', 'ScrollView', 'TextInput', ...) and a JSON-serializable props
 * bag. Function-valued props (event handlers) never travel the bridge —
 * they are represented by registration names the event dispatcher resolves,
 * so they do not appear here.
 */
export type ViewPropValue = string | number | boolean;

export class ViewNode {
  /** Bridge-assigned react tag (positive int, odd for root tags in RN). */
  tag: number;
  /** Registered RN view-manager class name, e.g. 'View', 'Text'. */
  className: string;
  props: Record<string, ViewPropValue> = {};
  children: ViewNode[] = [];

  constructor(tag: number, className: string) {
    this.tag = tag;
    this.className = className;
  }

  /** Own 'text' prop plus descendants' text — flattens nested <Text>. */
  textContent(): string {
    let out = '';
    const own = this.props['text'];
    if (typeof own === 'string') {
      out += own;
    }
    for (const child of this.children) {
      out += child.textContent();
    }
    return out;
  }

  str(key: string, fallback: string = ''): string {
    const v = this.props[key];
    return typeof v === 'string' ? v : fallback;
  }

  num(key: string, fallback: number = 0): number {
    const v = this.props[key];
    return typeof v === 'number' ? v : fallback;
  }

  bool(key: string, fallback: boolean = false): boolean {
    const v = this.props[key];
    return typeof v === 'boolean' ? v : fallback;
  }
}
