import { ViewNode } from './ViewNode';

/**
 * ArkUI view-manager surface — renders a ShadowTree ViewNode graph into
 * real ArkUI components.
 *
 * This is the view layer a native RN runtime would target: UIManager ops
 * mutate the ShadowTree, the tree bumps a render counter, and RnSurface
 * re-renders. The component catalog covers the core RN components:
 *
 *   View        -> Row/Column (flexDirection) with box props
 *   Text        -> Text (flattened textContent for nested spans)
 *   Image       -> Image (source.uri / source string, resizeMode)
 *   ScrollView  -> Scroll wrapping a Column
 *   TextInput   -> TextInput (value/placeholder/editable)
 *   (unknown)   -> View fallback, so trees never drop children
 *
 * HONEST SCOPE: this renders a *data-defined* tree. Without the JS engine
 * and bridge, nothing produces these trees from real RN JS yet — the
 * surface exists so that when UIManager commands do flow, the visual path
 * is already done. Layout is ArkUI's approximation of Yoga flexbox, not
 * Yoga itself, and only a subset of props is mapped.
 */

function justifyContentOf(value: string): FlexAlign {
  switch (value) {
    case 'center':
      return FlexAlign.Center;
    case 'flex-end':
      return FlexAlign.End;
    case 'space-between':
      return FlexAlign.SpaceBetween;
    case 'space-around':
      return FlexAlign.SpaceAround;
    case 'space-evenly':
      return FlexAlign.SpaceEvenly;
    default:
      return FlexAlign.Start;
  }
}

function rowAlignOf(value: string): VerticalAlign {
  switch (value) {
    case 'center':
      return VerticalAlign.Center;
    case 'flex-end':
      return VerticalAlign.Bottom;
    default:
      return VerticalAlign.Top;
  }
}

function columnAlignOf(value: string): HorizontalAlign {
  switch (value) {
    case 'center':
      return HorizontalAlign.Center;
    case 'flex-end':
      return HorizontalAlign.End;
    default:
      return HorizontalAlign.Start;
  }
}

function imageFitOf(mode: string): ImageFit {
  switch (mode) {
    case 'contain':
      return ImageFit.Contain;
    case 'stretch':
    case 'fill':
      return ImageFit.Fill;
    case 'center':
      return ImageFit.None;
    default:
      return ImageFit.Cover;
  }
}

/** RN image source may be a uri string or a {uri:'...'} shaped prop. */
function imageUriOf(node: ViewNode): string {
  const source = node.props['source'];
  if (typeof source === 'string') {
    return source;
  }
  const uri = node.props['uri'];
  return typeof uri === 'string' ? uri : '';
}

function textAlignOf(value: string): TextAlign {
  switch (value) {
    case 'center':
      return TextAlign.Center;
    case 'right':
      return TextAlign.End;
    default:
      return TextAlign.Start;
  }
}

@Component
struct RnNodeView {
  node: ViewNode | null = null;

  @Builder
  private Children(node: ViewNode) {
    ForEach(node.children, (child: ViewNode) => {
      RnNodeView({ node: child })
    }, (child: ViewNode) => child.tag.toString())
  }

  /** 'View' and the unknown-component fallback share this container path. */
  @Builder
  private RenderBox(node: ViewNode) {
    if (node.str('flexDirection') === 'row') {
      Row({ space: node.num('gap', 0) }) {
        this.Children(node)
      }
      .justifyContent(justifyContentOf(node.str('justifyContent')))
      .alignItems(rowAlignOf(node.str('alignItems')))
      .width(node.num('width', -1) >= 0 ? node.num('width') : '100%')
      .height(node.num('height', -1) >= 0 ? node.num('height') : '100%')
      .backgroundColor(node.str('backgroundColor', '#00000000'))
      .padding(node.num('padding', 0))
      .margin(node.num('margin', 0))
      .borderRadius(node.num('borderRadius', 0))
      .opacity(node.num('opacity', 1))
    } else {
      Column({ space: node.num('gap', 0) }) {
        this.Children(node)
      }
      .justifyContent(justifyContentOf(node.str('justifyContent')))
      .alignItems(columnAlignOf(node.str('alignItems')))
      .width(node.num('width', -1) >= 0 ? node.num('width') : '100%')
      .height(node.num('height', -1) >= 0 ? node.num('height') : '100%')
      .backgroundColor(node.str('backgroundColor', '#00000000'))
      .padding(node.num('padding', 0))
      .margin(node.num('margin', 0))
      .borderRadius(node.num('borderRadius', 0))
      .opacity(node.num('opacity', 1))
    }
  }

  build() {
    if (this.node === null) {
      Column()
        .width(0)
        .height(0)
    } else if (this.node.className === 'Text') {
      Text(this.node.textContent())
        .fontColor(this.node.str('color', '#FF000000'))
        .fontSize(this.node.num('fontSize', 14))
        .fontWeight(this.node.str('fontWeight') === 'bold' ? FontWeight.Bold : FontWeight.Normal)
        .textAlign(textAlignOf(this.node.str('textAlign')))
        .margin(this.node.num('margin', 0))
    } else if (this.node.className === 'Image') {
      Image(imageUriOf(this.node))
        .width(this.node.num('width', 100))
        .height(this.node.num('height', 100))
        .objectFit(imageFitOf(this.node.str('resizeMode', 'cover')))
        .borderRadius(this.node.num('borderRadius', 0))
        .margin(this.node.num('margin', 0))
        .alt('')
    } else if (this.node.className === 'ScrollView') {
      Scroll() {
        Column({ space: this.node.num('gap', 0) }) {
          this.Children(this.node)
        }
        .width('100%')
      }
      .scrollable(this.node.bool('horizontal') ? ScrollDirection.Horizontal : ScrollDirection.Vertical)
      .width(this.node.num('width', -1) >= 0 ? this.node.num('width') : '100%')
      .height(this.node.num('height', -1) >= 0 ? this.node.num('height') : '100%')
      .backgroundColor(this.node.str('backgroundColor', '#00000000'))
      .margin(this.node.num('margin', 0))
    } else if (this.node.className === 'TextInput') {
      TextInput({
        text: this.node.str('value'),
        placeholder: this.node.str('placeholder'),
      })
        .enabled(this.node.bool('editable', true))
        .fontSize(this.node.num('fontSize', 14))
        .fontColor(this.node.str('color', '#FF000000'))
        .margin(this.node.num('margin', 0))
        .width(this.node.num('width', -1) >= 0 ? this.node.num('width') : '100%')
    } else {
      // 'View', 'SafeAreaView', and any unregistered component render via
      // the container path so partially-mapped trees keep their children.
      this.RenderBox(this.node)
    }
  }
}

/** Root surface: mount a ShadowTree root node to render it. */
@Component
export struct RnSurface {
  root: ViewNode | null = null;

  build() {
    Column() {
      RnNodeView({ node: this.root })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
