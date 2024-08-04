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

public struct BlanketDetent: Hashable {

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

    let source: BlanketDetent
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
  
  struct State {
    
    let lower: BlanketDetent.Resolved?
    let higher: BlanketDetent.Resolved?
    
  }

  let detents: [BlanketDetent.Resolved]

  var maxDetent: BlanketDetent.Resolved {
    detents.last!
  }

  var minDetent: BlanketDetent.Resolved! {
    detents.first
  }
  
  func range(for offset: CGFloat) -> (lower: BlanketDetent.Resolved?, higher: BlanketDetent.Resolved?) {
    
    var lower: BlanketDetent.Resolved?
    var higher: BlanketDetent.Resolved?
    
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
    
    return (lower, higher)
  }


  func nearestDetent(to offset: CGFloat, velocity: CGFloat) -> BlanketDetent.Resolved {
    
    let (lower, higher) = range(for: offset)
    
    guard higher != nil else {
      return detents.last!
    }
            
    let lowerDistance = abs(lower!.offset - offset)
    let higherDistance = abs(higher!.offset - offset)        
    
    var proposed: BlanketDetent.Resolved
    
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

@MainActor
private final class Model: ObservableObject {
  
  var presentingContentOffset: CGSize
  
  init(presentingContentOffset: CGSize) {
    self.presentingContentOffset = presentingContentOffset
  }
  
}

private struct ContentDescriptor: Hashable {
  var contentSize: CGSize?
  var detents: Set<BlanketDetent>?
}

public struct BlanketModifier<DisplayContent: View>: ViewModifier {
  
  private let displayContent: () -> DisplayContent
  @Binding var isPresented: Bool

  @State private var contentOffset: CGSize = .zero
  @State private var targetOffset: CGSize = .zero

  @State private var contentDescriptor: ContentDescriptor = .init()

  @State private var maximumSize: CGSize?
  @State private var safeAreaInsets: EdgeInsets = .init()

  // Ephemeral state
  @State private var baseOffset: CGSize?
  @State private var baseTranslation: CGSize?
  // Ephemeral state
  @State private var baseCustomHeight: CGFloat?

  @State var customHeight: CGFloat?

  private let onDismiss: (() -> Void)?

  @State private var hidingOffset: CGFloat = 0

  @State private var resolved: Resolved?
  
  @State private var isScrollLockEnabled: Bool = true
  
  @StateObject private var model: Model = .init(presentingContentOffset: .zero)

  private let configuration: BlanketConfiguration = .init(mode: .inline(.init()))

  public init(
    isPresented: Binding<Bool>,
    onDismiss: (() -> Void)?,
    @ViewBuilder displayContent: @escaping () -> DisplayContent
  ) {
    self._isPresented = isPresented
    self.onDismiss = onDismiss
    self.displayContent = displayContent
  }

  public func body(content: Content) -> some View {
    
    ZStack {
      content
      _display
    }
  }

  private var _display: some View {
        
    return VStack {

      Spacer()
        .layoutPriority(1)

      displayContent()
        .onPreferenceChange(BlanketContentDetentsPreferenceKey.self, perform: { detents in
          self.contentDescriptor.detents = detents
        })
        .readingGeometry(
          transform: \.size,
          target: $contentDescriptor.contentSize
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
        view
          .gesture(
            _gesture()
          )
      } else {
        view.gesture(compatibleGesture())
      }
    }

    ._animatableOffset(
      y: contentOffset.height,
      onUpdate: { height in
        model.presentingContentOffset.height = height
    })
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
    .onChange(
      of: contentDescriptor,
      perform: { descriptor in      
        
        guard let contentSize = descriptor.contentSize,
              let detents = descriptor.detents else { return }      
        guard customHeight == nil else { return }
        
        resolve(contentSize: contentSize, detents: detents)
        
    })
    .onChange(of: hidingOffset) { hidingOffset in
      if isPresented == false {
        // init
        self.contentOffset.height = hidingOffset
      }
    }
  }

  private func resolve(contentSize: CGSize, detents: Set<BlanketDetent>) {

    guard let maximumSize else {
      return
    }

    Log.debug("resolve")
    
    let usingDetents: Set<BlanketDetent>
    
    if detents.isEmpty {
      usingDetents = .init(arrayLiteral: .content)
    } else {      
      usingDetents = consume detents
    }

    let context = BlanketDetent.Context(
      maxDetentValue: maximumSize.height - 30,
      contentHeight: contentSize.height
    )

    var resolved = usingDetents.map {
      return BlanketDetent.Resolved(
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
    
    let hiddenDetent = BlanketDetent.Resolved(
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
  private func _gesture()
    -> ScrollViewInteroperableDragGesture
  {
    
    return ScrollViewInteroperableDragGesture(
      configuration: .init(
        ignoresScrollView: false,                
        targetEdges: .top,              
        sticksToEdges: false
      ),
      isScrollLockEnabled: $isScrollLockEnabled,
      coordinateSpaceInDragging: .named(_CoordinateSpaceTag.transition),
      onChange: { value in

        onChange(
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
    translation: CGSize
  ) {

    guard let resolved else { return }
            
    if baseCustomHeight == nil {
      self.baseCustomHeight = customHeight ?? contentDescriptor.contentSize?.height ?? 0
    }
    
    let baseCustomHeight = self.baseCustomHeight!

    let proposedHeight = baseCustomHeight - translation.height

    let lowestDetent = resolved.minDetent.offset
    let highestDetent = resolved.maxDetent.offset
    
    if proposedHeight < lowestDetent {
      
      // moving view
      
      if baseOffset == nil {
        self.baseOffset = model.presentingContentOffset
      }
      
      if baseTranslation == nil {
        self.baseTranslation = translation
      }
      
      let baseOffset = self.baseOffset!
      let baseTranslation = self.baseTranslation!

      Log.debug("Use intrinsict height")

      // release hard frame
      customHeight = nil
      isScrollLockEnabled = true

      let proposedOffset = CGSize(
        width: baseOffset.width + translation.width - baseTranslation.width,
        height: baseOffset.height + translation.height - baseTranslation.height
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
      
      // reaching max
      
      // set hard frame
      customHeight = rubberBand(value: proposedHeight, min: highestDetent, max: highestDetent, bandLength: 20)
      
      isScrollLockEnabled = false

    } else {

      // stretching view
      contentOffset.height = 0
                  
      isScrollLockEnabled = true
      
      // set hard frame
      customHeight = proposedHeight
    }

  }

  private func onEnd(velocity: CGVector) {
        
    self.baseOffset = nil
    self.baseTranslation = nil
    self.baseCustomHeight = nil
    
    guard let resolved else { return }
    
    if let customHeight {      
      
      let currentRange = resolved.range(for: customHeight)
      
      Log.debug(customHeight, resolved.maxDetent.offset)
      
      if customHeight >= resolved.maxDetent.offset {
        isScrollLockEnabled = false
      } else {
        isScrollLockEnabled = true
      }
      
    } else {
      isScrollLockEnabled = false
    }
    
    Log.debug("End", "isScrollLockEnabled", isScrollLockEnabled)
    
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
      
      @MainActor
      func animation() {
        contentOffset.height = targetOffset.height        
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

    }

  }

}

private enum _CoordinateSpaceTag: Hashable {
//  case pointInView
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

private struct BlanketContentWrapperView<Content: View>: View {
  
  let content: Content
  let detents: Set<BlanketDetent>
  
  init(
    content: Content,
    detents: Set<BlanketDetent>
  ) {
    self.content = content
    self.detents = detents
  }
  
  var body: some View {
    content
      .preference(key: BlanketContentDetentsPreferenceKey.self, value: detents)
  }
  
}

enum BlanketContentDetentsPreferenceKey: PreferenceKey {
  
  static var defaultValue: Set<BlanketDetent> {
    .init()
  }
  
  static func reduce(value: inout Set<BlanketDetent>, nextValue: () -> Set<BlanketDetent>) {
    value = nextValue()
  }
  
}

extension View {
  
  public func blanketContentDetents(
    _ firstDetent: BlanketDetent,
    _ detents: BlanketDetent...
  ) -> some View {
    self.blanketContentDetents(CollectionOfOne(firstDetent) + detents) 
  }
  
  public func blanketContentDetents(
    _ detent: BlanketDetent
  ) -> some View {
    self.blanketContentDetents(CollectionOfOne(detent))        
  }
  
  public func blanketContentDetents(
    _ detents: some Collection<BlanketDetent>
  ) -> some View {
    self.blanketContentDetents(Set.init(detents))
  }
    
  public func blanketContentDetents(
    _ detens: Set<BlanketDetent>
  ) -> some View {
    BlanketContentWrapperView(
      content: self,
      detents: detens
    )
  }
  
}
