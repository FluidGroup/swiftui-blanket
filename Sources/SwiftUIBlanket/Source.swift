import RubberBanding
import SwiftUI
import SwiftUIScrollViewInteroperableDragGesture
import SwiftUISupportDescribing
import SwiftUISupportSizing
import os.log

enum Log {

  static func debug(_ values: Any...) {
    #if DEBUG
    let date = Date().formatted(.iso8601)
    print("[\(date)] \(values.map { "\($0)" }.joined(separator: " "))")
    #endif
  }

}

public struct BlancketDetent: Hashable {

  struct Context {
    let maxDetentValue: CGFloat
    let contentHeight: CGFloat
  }

  enum Node: Hashable {

    case fraction(CGFloat)
    case height(CGFloat)
    case content
  }

  struct Resolved: Hashable {

    let source: BlancketDetent
    let offset: CGFloat

  }

  let node: Node

  public static func height(_ height: CGFloat) -> Self {
    .init(node: .height(height))
  }

  public static func fraction(_ fraction: CGFloat) -> Self {
    .init(node: .fraction(fraction))
  }

  public static var content: Self {
    .init(node: .content)
  }

  func resolve(in context: Context) -> CGFloat {
    switch node {
    case .content:
      return context.contentHeight
    case .fraction(let fraction):
      return context.maxDetentValue * fraction
    case .height(let height):
      return min(height, context.maxDetentValue)
    }
  }

}

public struct BlanketConfiguration {

  public struct Inline {

    public init() {

    }
  }

  public struct Presentation {

    public let backgroundColor: Color
    public let handlesOutOfContent: Bool

    public init(
      backgroundColor: Color,
      handlesOutOfContent: Bool
    ) {
      self.backgroundColor = backgroundColor
      self.handlesOutOfContent = handlesOutOfContent
    }
  }

  public enum Mode {
    case inline(Inline)
    case presentation(Presentation)
  }

  public let mode: Mode

  public init(mode: Mode) {
    self.mode = mode
  }

}

private struct Resolved {

  let detents: [BlancketDetent.Resolved]

  var maxDetent: BlancketDetent.Resolved {
    detents.last!
  }

  var minDetent: BlancketDetent.Resolved! {
    detents.first
  }

  func nearestDetent(to offset: CGFloat, velocity: CGFloat) -> BlancketDetent.Resolved {
    
    var lower: BlancketDetent.Resolved?
    var higher: BlancketDetent.Resolved?
    
    for e in detents {
      if e.offset <= offset {
        lower = e
        continue
      }
      
      if higher == nil, lower != nil {
        higher = e
        break
      }
    }
    
    guard higher != nil else {
      return detents.last!
    }
            
    let lowerDistance = abs(lower!.offset - offset)
    let higherDistance = abs(higher!.offset - offset)        
    
    var proposed: BlancketDetent.Resolved
    
    if lowerDistance < higherDistance {
      proposed = lower!
    } else {
      proposed = higher!
    }
    
    if velocity < -50 {
      proposed = higher!
    }
    
    if velocity > 50 {
      proposed = lower!
    }
    
    return proposed
    
  }

}

public struct BlanketModifier<DisplayContent: View>: ViewModifier {

  private let displayContent: () -> DisplayContent
  @Binding var isPresented: Bool

  @State private var contentOffset: CGSize = .zero
  @State private var presentingContentOffset: CGSize = .zero
  @State private var targetOffset: CGSize = .zero

  @State private var contentSize: CGSize?
  @State private var maximumSize: CGSize?
  @State private var safeAreaInsets: EdgeInsets = .init()

  @State var customHeight: CGFloat?

  private let onDismiss: (() -> Void)?

  @State private var hidingOffset: CGFloat = 0

  @State private var resolved: Resolved?

  private let detents: Set<BlancketDetent>

  private let configuration: BlanketConfiguration = .init(mode: .inline(.init()))

  public init(
    isPresented: Binding<Bool>,
    onDismiss: (() -> Void)?,
    @ViewBuilder displayContent: @escaping () -> DisplayContent
  ) {
    self._isPresented = isPresented
    self.onDismiss = onDismiss
    self.displayContent = displayContent

    self.detents = .init([.content, .fraction(0.8), .fraction(1)])
  }

  public func body(content: Content) -> some View {

    ZStack {
      content
      _display
    }
  }

  private var _display: some View {

    VStack {

      Spacer()
        .layoutPriority(1)

      displayContent()
        .readingGeometry(
          transform: \.size,
          target: $contentSize
        )
        .frame(height: customHeight)

    }

    .background(
      Rectangle()
        .hidden()
        .readingGeometry(
          transform: \.size,
          target: $maximumSize
        )
    )
    .map { view in
      switch configuration.mode {
      case .inline:
        view
      case .presentation(let presentation):
        if presentation.handlesOutOfContent {
          view
            .contentShape(Rectangle())
        } else {
          view
        }
      }      
    }
    .map { view in
      if #available(iOS 18, *) {
        
        // make this draggable
        view.gesture(_gesture(configuration: .init(ignoresScrollView: false, sticksToEdges: true)))
      } else {
        view.gesture(compatibleGesture())
      }
    }

    ._animatableOffset(y: contentOffset.height, presenting: $presentingContentOffset.height)
    .map { view in
      switch configuration.mode {
      case .inline:
        view
      case .presentation(let presentation):
        view
          .background(presentation.backgroundColor.opacity(isPresented ? 0.2 : 0))
      }
    }
    .animation(.smooth, value: isPresented)
    .readingGeometry(
      transform: \.safeAreaInsets,
      target: $safeAreaInsets
    )
    .onChange(of: isPresented) { isPresented in
      if isPresented {
        withAnimation(.spring(response: 0.45)) {
          contentOffset.height = 0
        }
      } else {
        withAnimation(.spring(response: 0.45)) {
          contentOffset.height = hidingOffset
        }
      }
    }
    .onChange(of: contentSize) { contentSize in
      guard let contentSize else { return }
      guard customHeight == nil else { return }
      resolve(contentSize: contentSize)
    }
    .onChange(of: hidingOffset) { hidingOffset in
      if isPresented == false {
        // init
        self.contentOffset.height = hidingOffset
      }
    }
  }

  private func resolve(contentSize: CGSize) {

    guard let maximumSize else {
      return
    }

    Log.debug("resolve")

    let context = BlancketDetent.Context(
      maxDetentValue: maximumSize.height - 30,
      contentHeight: contentSize.height
    )

    var resolved = detents.map {
      return BlancketDetent.Resolved(
        source: $0,
        offset: $0.resolve(in: context)
      )
    }
    .sorted(by: { $0.offset < $1.offset })

    // remove duplicates
    resolved = resolved.reduce(into: []) { result, next in
      if !result.contains(next) {
        result.append(next)
      }
    }

    // remove smaller than content
    if let contentSizeDetent = resolved.first(where: { $0.source.node == .content }) {
      resolved.removeAll {
        $0.offset < contentSizeDetent.offset
      }
    }
    
    let hiddenDetent = BlancketDetent.Resolved(
      source: .fraction(0),
      offset: (contentSize.height + safeAreaInsets.bottom)
    )

    hidingOffset = hiddenDetent.offset

    self.resolved = .init(detents: resolved)

  }

  @available(iOS 18.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  @available(visionOS, unavailable)
  private func _gesture(
    configuration: ScrollViewInteroperableDragGesture.Configuration
  )
    -> ScrollViewInteroperableDragGesture
  {

    let baseOffset = presentingContentOffset
    let baseCustomHeight = customHeight ?? contentSize?.height ?? 0

    return ScrollViewInteroperableDragGesture(
      configuration: configuration,
      coordinateSpaceInDragging: .named(_CoordinateSpaceTag.transition),
      onChange: { value in

        onChange(
          baseOffset: baseOffset,
          baseCustomHeight: baseCustomHeight,
          translation: value.translation
        )

      },
      onEnd: { value in
        onEnd(
          velocity: .init(
            dx: value.velocity.width,
            dy: value.velocity.height
          )
        )
      }
    )
  }
  
  private func compatibleGesture() -> some Gesture {
    DragGesture(minimumDistance: 10, coordinateSpace: .named(_CoordinateSpaceTag.transition))
      .onChanged { value in
        onChange(
          baseOffset: presentingContentOffset,
          baseCustomHeight: customHeight ?? contentSize?.height ?? 0,
          translation: value.translation
        )
      }
      .onEnded { value in
        onEnd(
          velocity: .init(
            dx: value.predictedEndLocation.x - value.location.x,
            dy: value.predictedEndLocation.y - value.location.y
          )
        )
      }
  }

  private func onChange(
    baseOffset: CGSize,
    baseCustomHeight: CGFloat,
    translation: CGSize
  ) {

    guard let resolved else { return }

    let proposedHeight = baseCustomHeight - translation.height

    let lowestDetent = resolved.minDetent.offset
    let highestDetent = resolved.maxDetent.offset

    if proposedHeight < lowestDetent {

      // moving view

      Log.debug("Use intrinsict height")

      customHeight = nil

      let proposedOffset = CGSize(
        width: baseOffset.width + translation.width,
        height: baseOffset.height + translation.height
      )

      withAnimation(.interactiveSpring()) {

        contentOffset.height = rubberBand(
          value: proposedOffset.height,
          min: 0,
          max: .infinity,
          bandLength: 50
        )

      }

    } else if proposedHeight > highestDetent {

      Log.debug("reached max")
      customHeight = rubberBand(value: proposedHeight, min: highestDetent, max: highestDetent, bandLength: 20)

    } else {

      // stretching view
      Log.debug("Use custom height", proposedHeight)
      contentOffset.height = 0
      customHeight = proposedHeight
    }

  }

  private func onEnd(velocity: CGVector) {

    guard let resolved else { return }

    if let customHeight {
      Log.debug("End - stretching")

      let nearest = resolved.nearestDetent(to: customHeight, velocity: velocity.dy)
      
      Log.debug("\(nearest)")

      let distance = CGSize(
        width: 0,
        height: nearest.offset - customHeight
      )

      let mappedVelocity = CGVector(
        dx: velocity.dx / distance.width,
        dy: velocity.dy / distance.height
      )

      var animationY: Animation {
        .interpolatingSpring(
          mass: 1,
          stiffness: 200,
          damping: 20,
          initialVelocity: -mappedVelocity.dy
        )
      }
      
      @MainActor
      func animation() {
        if nearest == resolved.minDetent {
          self.customHeight = nil
        } else {
          self.customHeight = nearest.offset
        }
      }

      if #available(iOS 17.0, *) {

        withAnimation(animationY) {
          animation()
        } completion: {

        }

      } else {

        withAnimation(
          animationY
        ) {
          animation()
        }
      }

    } else {

      Log.debug("End - moving", velocity.dy, contentOffset.height)

      let targetOffset: CGSize

      if velocity.dy > 50 || contentOffset.height > 50 {
        targetOffset = .init(width: 0, height: hidingOffset)
      } else {
        targetOffset = .zero
      }

      self.targetOffset = targetOffset

      let distance = CGSize(
        width: targetOffset.width - contentOffset.width,
        height: targetOffset.height - contentOffset.height
      )

      let mappedVelocity = CGVector(
        dx: velocity.dx / distance.width,
        dy: velocity.dy / distance.height
      )

      var animationY: Animation {
        .interpolatingSpring(
          mass: 1,
          stiffness: 200,
          damping: 20,
          initialVelocity: mappedVelocity.dy
        )
      }

      if #available(iOS 17.0, *) {

        withAnimation(animationY) {
          contentOffset.height = targetOffset.height
        } completion: {

        }

      } else {

        withAnimation(
          animationY
        ) {
          contentOffset.height = targetOffset.height
        }
      }

    }

  }

}

private enum _CoordinateSpaceTag: Hashable {
  case pointInView
  case transition
}

extension View {

  public func blanket<Item, Content>(
    item: Binding<Item?>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View where Item: Identifiable, Content: View {

    self.modifier(
      BlanketModifier(
        isPresented: .init(
          get: { item.wrappedValue != nil },
          set: { if !$0 { item.wrappedValue = nil } }
        ),
        onDismiss: onDismiss,
        displayContent: {
          if let item = item.wrappedValue {
            content(item)
          }
        }
      )
    )

  }

  public func blanket<Content>(
    isPresented: Binding<Bool>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View where Content: View {

    self.modifier(
      BlanketModifier(isPresented: isPresented, onDismiss: onDismiss, displayContent: content)
    )

  }

}

