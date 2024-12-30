import RubberBanding
import SwiftUI
import SwiftUIScrollViewInteroperableDragGesture
import SwiftUISupportDescribing
import SwiftUISupportSizing
import SwiftUISupportBackport
import os.log

// MARK: - Log

/// A utility enum for logging debug and error messages with timestamps.
enum Log {
  // MARK: - Debug Logging
  
  /// Logs debug messages, including a timestamp for the current time.
  /// Only enabled in debug builds (`DEBUG` flag).
  /// - Parameter values: The values to log, which will be converted to string and printed.
  static func debug(_ values: Any...) {
    #if DEBUG
    let date = Date().formatted(.iso8601)
    print("[\(date)] \(values.map { "\($0)" }.joined(separator: " "))")
    #endif
  }

  // MARK: - Error Logging
  
  /// Logs error messages, including a timestamp and an error emoji.
  /// Only enabled in debug builds (`DEBUG` flag).
  /// - Parameter values: The error details to log, which will be converted to string and printed.
  static func error(_ values: Any...) {
    #if DEBUG
    let date = Date().formatted(.iso8601)
    print("[\(date)] ❌ \(values.map { "\($0)" }.joined(separator: " "))")
    #endif
  }
}

/// A struct representing a detent in the Blanket view system, defining how the view behaves
/// when it's presented at different heights or fractions of the screen.
public struct BlanketDetent: Hashable {

  // MARK: - Context

  /// A context containing the necessary data to resolve the detent's value.
  /// It includes the maximum allowed detent value and the content height.
  struct Context {
    let maxDetentValue: CGFloat
    let contentHeight: CGFloat
  }

  // MARK: - Node Definition

  /// An enum representing different types of detents that can be used.
  /// A detent can be defined as a fraction of the screen's maximum height,
  /// a specific height value, or as the content's natural height.
  enum Node: Hashable {
    
    /// A fraction of the maximum height of the detent (e.g., 0.5 for 50% height).
    case fraction(CGFloat)
    
    /// A fixed height for the detent.
    case height(CGFloat)
    
    /// A special case for the content's natural height.
    case content
  }

  // MARK: - Resolved Detent

  /// A resolved detent, which is the result of evaluating a `BlanketDetent` in a given context.
  /// It includes the detent source and its resolved offset (height) in the layout.
  struct Resolved: Hashable {
    /// The original detent source.
    let source: BlanketDetent
    
    /// The resolved offset (height) for this detent.
    let offset: CGFloat
  }

  // MARK: - Properties

  /// The detent's node, which can be a fraction, a height, or content.
  let node: Node

  // MARK: - Initializers

  /// Creates a detent with a fixed height.
  /// - Parameter height: The height value for the detent.
  public static func height(_ height: CGFloat) -> Self {
    .init(node: .height(height))
  }

  /// Creates a detent with a fraction of the maximum height.
  /// - Parameter fraction: The fraction of the maximum height (e.g., 0.5 for 50%).
  public static func fraction(_ fraction: CGFloat) -> Self {
    .init(node: .fraction(fraction))
  }

  /// A special case for the content's natural height as a detent.
  public static var content: Self {
    .init(node: .content)
  }

  // MARK: - Methods

  /// Resolves the detent's offset in the given context.
  /// This will calculate the detent's value based on the `maxDetentValue` and `contentHeight` from the context.
  /// - Parameter context: The context containing the max height and content height.
  /// - Returns: The resolved offset (height) for this detent.
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

// MARK: - BlanketConfiguration

/// A configuration struct that defines how a `Blanket` view behaves, including its appearance
/// and interaction mode. It supports two modes: inline and presentation.
public struct BlanketConfiguration {

  // MARK: - Inline Configuration

  /// A struct representing the configuration for the inline mode of the Blanket view.
  /// The inline mode typically involves simpler configurations, possibly without animations or 
  /// full-screen presentation behavior.
  public struct Inline {

    /// Initializes the `Inline` configuration. 
    /// This struct does not have any properties but may be expanded in the future.
    public init() {

    }
  }

  // MARK: - Presentation Configuration

  /// A struct representing the configuration for the presentation mode of the Blanket view.
  /// The presentation mode typically involves a more complex configuration, such as setting 
  /// background color and deciding whether to allow interaction with content outside the blanket.
  public struct Presentation {
    /// The background color of the presentation. This can be used to set a dimming effect
    /// or background for the blanket view.
    public let backgroundColor: Color

    /// A boolean flag that determines whether the blanket should handle interactions with content
    /// outside of its bounds (e.g., allowing taps or gestures outside the blanket).
    public let handlesOutOfContent: Bool

    /// Initializes the `Presentation` configuration.
    /// - Parameters:
    ///   - backgroundColor: The background color of the blanket when in presentation mode.
    ///   - handlesOutOfContent: A flag that controls whether the blanket can handle interactions outside its bounds.
    public init(
      backgroundColor: Color,
      handlesOutOfContent: Bool
    ) {
      self.backgroundColor = backgroundColor
      self.handlesOutOfContent = handlesOutOfContent
    }
  }

  // MARK: - Mode Enum

  /// An enum that defines the two available modes for the `Blanket` view.
  /// - `.inline`: Uses the `Inline` configuration for simpler behavior.
  /// - `.presentation`: Uses the `Presentation` configuration for more complex behavior.
  public enum Mode {
    case inline(Inline)
    case presentation(Presentation)
  }

  // MARK: - Properties

  /// The mode in which the `Blanket` view operates. This determines the configuration to be used.
  public let mode: Mode

  // MARK: - Initializer

  /// Initializes the `BlanketConfiguration` with a specified mode.
  /// - Parameter mode: The mode that defines the configuration (`inline` or `presentation`).
  public init(mode: Mode) {
    self.mode = mode
  }
}

// MARK: - Resolved

/// A private struct used to represent the resolved detents for a `Blanket` view, 
/// containing information about the detents and providing methods to resolve detent positions
/// based on offset and velocity.
private struct Resolved: Equatable {
  // MARK: - Properties

  /// An array of resolved detents that describe the positions of the blanket's detents.
  let detents: [BlanketDetent.Resolved]

  /// The maximum detent in the array, i.e., the last detent.
  var maxDetent: BlanketDetent.Resolved {
    detents.last!
  }

  /// The minimum detent in the array, i.e., the first detent.
  var minDetent: BlanketDetent.Resolved! {
    detents.first
  }
  
  // MARK: - Methods

  /// Returns the lower and higher detents relative to the given offset.
  /// 
  /// - Parameter offset: The current offset to compare against.
  /// - Returns: A tuple of optional `BlanketDetent.Resolved` values: 
  ///   - `lower`: The detent that is less than or equal to the offset.
  ///   - `higher`: The detent that is greater than the offset.
  func range(for offset: CGFloat) -> (lower: BlanketDetent.Resolved?, higher: BlanketDetent.Resolved?) {
    var lower: BlanketDetent.Resolved?
    var higher: BlanketDetent.Resolved?
    
    for e in detents {
      if e.offset <= offset {
        lower = e
        continue
      }
      
      // Assign higher when the lower is already found and we're past the offset
      if higher == nil, lower != nil {
        higher = e
        break
      }
    }
    
    return (lower, higher)
  }

  /// Returns the nearest detent to the given offset, considering the offset and velocity.
  /// 
  /// - Parameters:
  ///   - offset: The current offset position to calculate the nearest detent.
  ///   - velocity: The velocity of the movement. This affects whether we choose the lower or higher detent.
  /// - Returns: The `BlanketDetent.Resolved` that is nearest to the offset, adjusted for velocity.
  func nearestDetent(to offset: CGFloat, velocity: CGFloat) -> BlanketDetent.Resolved {
    let (lower, higher) = range(for: offset)
    
    // If there's no higher detent, return the last detent (maxDetent)
    guard higher != nil else {
      return detents.last!
    }
    
    // Calculate the distances to the lower and higher detents
    let lowerDistance = abs(lower!.offset - offset)
    let higherDistance = abs(higher!.offset - offset)        
    
    var proposed: BlanketDetent.Resolved
    
    // Determine which detent is closer based on distance
    if lowerDistance < higherDistance {
      proposed = lower!
    } else {
      proposed = higher!
    }
    
    // Adjust detent based on velocity (thresholds for fast movements)
    if velocity < -50 {
      proposed = higher!
    }
    
    if velocity > 50 {
      proposed = lower!
    }
    
    return proposed
  }
}

/// A private class that models the state and behavior of a presenting view, 
/// including its offset and other ephemeral states related to the interaction.
@MainActor
private final class Model: ObservableObject {
  // MARK: - Properties

  /// The current offset of the presenting content.
  var presentingContentOffset: CGSize

  /// The resolved detent positions for the blanket view.
  var resolved: Resolved?

  // MARK: - Ephemeral State

  /// A temporary offset used for calculating translations or adjustments.
  var baseOffset: CGSize?

  /// A temporary translation value used for calculating view movement.
  var baseTranslation: CGSize?

  /// A temporary custom height used in calculating the height adjustments of the view.
  var baseCustomHeight: CGFloat?

  // MARK: - Initializer

  /// Initializes the `Model` with a given presenting content offset.
  ///
  /// - Parameter presentingContentOffset: The initial offset of the content that is being presented.
  init(presentingContentOffset: CGSize) {
    self.presentingContentOffset = presentingContentOffset
  }
}

// MARK: - ContentDescriptor

/// A descriptor that holds information about the content's state and layout configuration.
private struct ContentDescriptor: Hashable {
  /// The offset at which the content is hidden, typically used for sliding or animated transitions.
  var hidingOffset: CGFloat = 0

  /// The size of the content. It may be `nil` if the content size is unknown or not set.
  var contentSize: CGSize?

  /// The maximum allowable size for the content, providing a constraint on how large it can become.
  var maximumSize: CGSize?

  /// The set of possible detents (positions or sizes) for the blanket, if applicable.
  var detents: Set<BlanketDetent>?
}

// MARK: - Phase

/// An enum representing different phases in the lifecycle of the content.
private enum Phase {
  /// The content has been added to the view hierarchy but is not yet visible or loaded.
  case contentMounted
  
  /// The content has been removed or is no longer visible.
  case contentUnloaded
  
  /// The content has been fully loaded and is ready for display.
  case contentLoaded
  
  /// The content is currently being displayed or presented on the screen.
  case displaying
}

// MARK: - Pair

/// A generic pair struct that holds two equatable values of types `T1` and `T2`.
private struct Pair<T1: Equatable, T2: Equatable>: Equatable {
  /// The first value of the pair.
  let t1: T1

  /// The second value of the pair.
  let t2: T2
}

public struct BlanketModifier<DisplayContent: View>: ViewModifier {
  
  private let displayContent: () -> DisplayContent
  
  @State private var phase: Phase = .contentUnloaded
  
  @Binding var isPresented: Bool
  
  @State private var contentOffset: CGSize = .zero

  @State private var contentDescriptor: ContentDescriptor = .init()

  @State private var safeAreaInsets: EdgeInsets = .init()

  @State var customHeight: CGFloat?

  private let onDismiss: (() -> Void)?
  
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
    
    content
      .modifier(SizingModifier.init(onChange: { size in
        
        contentDescriptor.maximumSize = size
        
        dipatchResolve(newValue: contentDescriptor)
        
      }))
      .overlay(
        Group {
          if phase == .contentMounted || phase == .contentLoaded || phase == .displaying {
            _display              
          }
        },
        alignment: .bottom        
      )
      .onChange(of: isPresented) { isPresented in 
        switch isPresented {
        case true:
          self.phase = .contentMounted
        case false:
          self.phase = .contentUnloaded
        }
      }    
      .onChange(of: phase) { phase in
        
        print(phase)
        
        switch phase {
        case .contentMounted:
          break
        case .contentLoaded:
          self.contentOffset.height = contentDescriptor.hidingOffset
          // to animate sliding in
          Task { @MainActor in
            self.phase = .displaying
          }
          
        case .displaying:
          withAnimation(.spring(response: 0.45)) {
            contentOffset.height = 0
          }
        case .contentUnloaded:
          break
        }
        
      }    
      .onChange(
        of: contentDescriptor
      ) { newValue in          
        dipatchResolve(newValue: newValue)          
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
      switch configuration.mode {
      case .inline:
        view
      case .presentation(let presentation):
        view
          .background(presentation.backgroundColor.opacity(isPresented ? 0.2 : 0))
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
           
    .readingGeometry(
      transform: \.safeAreaInsets,
      target: $safeAreaInsets
    )
 
  }
  
  private func dipatchResolve(
    newValue: ContentDescriptor
  ) {
    guard 
      let contentSize = newValue.contentSize,
      let detents = newValue.detents,
      let maximumSize = newValue.maximumSize
    else { 
      return
    }      
    
    guard customHeight == nil else { 
      return
    }
    
    resolve(
      contentSize: contentSize,
      detents: detents,
      maximumSize: maximumSize
    )
  }

  private func resolve(
    contentSize: CGSize,
    detents: Set<BlanketDetent>,
    maximumSize: CGSize
  ) {

    Log.debug("resolve", maximumSize)
    
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

    var resolvedDetents = usingDetents.map {
      return BlanketDetent.Resolved(
        source: $0,
        offset: $0.resolve(in: context)
      )
    }
    .sorted(by: { $0.offset < $1.offset })

    // remove duplicates
    resolvedDetents = resolvedDetents.reduce(into: []) { result, next in
      if !result.contains(next) {
        result.append(next)
      }
    }

    // remove smaller than content
    if let contentSizeDetent = resolvedDetents.first(where: { $0.source.node == .content }) {
      resolvedDetents.removeAll {
        $0.offset < contentSizeDetent.offset
      }
    }
    
    let hiddenDetent = BlanketDetent.Resolved(
      source: .fraction(0),
      offset: (contentSize.height + safeAreaInsets.bottom)
    )

    if self.contentDescriptor.hidingOffset != hiddenDetent.offset {      
      self.contentDescriptor.hidingOffset = hiddenDetent.offset
    }
    
    let newResolved = Resolved(detents: resolvedDetents)
        
    if self.model.resolved != newResolved {
      self.model.resolved = newResolved
    }
    
    if phase == .contentMounted {
      phase = .contentLoaded        
    }
    
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

    guard let resolved = self.model.resolved else {
      Log.error("resolved object is not created")
      return
    }
            
    if model.baseCustomHeight == nil {
      model.baseCustomHeight = customHeight ?? contentDescriptor.contentSize?.height ?? 0
    }
    
    let baseCustomHeight = model.baseCustomHeight!

    let proposedHeight = baseCustomHeight - translation.height

    let lowestDetent = resolved.minDetent.offset
    let highestDetent = resolved.maxDetent.offset
    
    if proposedHeight < lowestDetent {
      
      // moving view
      
      if model.baseOffset == nil {
        model.baseOffset = model.presentingContentOffset
      }
      
      if model.baseTranslation == nil {
        model.baseTranslation = translation
      }
      
      let baseOffset = model.baseOffset!
      let baseTranslation = model.baseTranslation!

      Log.debug("Use intrinsict height")

      // release hard frame
      customHeight = nil
      isScrollLockEnabled = true

      let proposedOffset = CGSize(
        width: baseOffset.width + translation.width - baseTranslation.width,
        height: baseOffset.height + translation.height - baseTranslation.height
      )
      
//      withAnimation(.interactiveSpring()) {

        contentOffset.height = rubberBand(
          value: proposedOffset.height,
          min: 0,
          max: .infinity,
          bandLength: 50
        )

//      }

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
        
    model.baseOffset = nil
    model.baseTranslation = nil
    model.baseCustomHeight = nil
    
    guard let resolved = self.model.resolved else { return }    
    
    if let customHeight = self.customHeight {
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
      let willHide: Bool

      if velocity.dy > 50 || contentOffset.height > 50 {
        
        // hides
        targetOffset = .init(width: 0, height: contentDescriptor.hidingOffset)
        willHide = true
                
      } else {
        
        willHide = false
        targetOffset = .zero
      }

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
          if willHide {
            isPresented = false
          }
        }

      } else {
        
        // TODO: update isPresented

        withAnimation(
          animationY
        ) {
          animation()
        }
      }

    }
    
    isScrollLockEnabled = false

    // managing scrollview
    
//    if let customHeight = self.customHeight {      
//      
//      let currentRange = resolved.range(for: customHeight)
//      
//      Log.debug(customHeight, resolved.maxDetent.offset)
//      
//      if customHeight >= resolved.maxDetent.offset {
//        isScrollLockEnabled = false
//      } else {
//        isScrollLockEnabled = true
//      }
//      
//    } else {
//      isScrollLockEnabled = true
//    }
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
