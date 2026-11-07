import Combine
import RubberBanding
import SwiftUI
import SwiftUIScrollViewInteroperableDragGesture

/// A resting height for a blanket, measured within its container's safe area.
public struct BlanketDetent: Hashable, Sendable {

  struct Context {
    let maxDetentValue: CGFloat
    let contentHeight: CGFloat
  }

  enum Node: Hashable, Sendable {
    case fraction(CGFloat)
    case height(CGFloat)
    case content
  }

  struct Resolved: Equatable {
    let source: BlanketDetent
    let height: CGFloat
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
    let maximum = context.maxDetentValue.isFinite ? max(0, context.maxDetentValue) : 0
    let proposed: CGFloat
    switch node {
    case .content:
      proposed = context.contentHeight
    case .fraction(let fraction):
      proposed = maximum * fraction
    case .height(let height):
      proposed = height
    }
    return proposed.isNaN ? 0 : min(maximum, max(0, proposed))
  }
}

public struct BlanketConfiguration {

  public struct Inline {
    public init() {}
  }

  public struct Presentation {
    public let backgroundColor: Color
    /// Whether the backdrop intercepts taps and dismisses the blanket.
    public let handlesOutOfContent: Bool

    public init(
      backgroundColor: Color = .black.opacity(0.2),
      handlesOutOfContent: Bool = true
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

  public init(mode: Mode = .inline(.init())) {
    self.mode = mode
  }
}

struct ResolvedDetents: Equatable {
  let detents: [BlanketDetent.Resolved]

  init(_ detents: Set<BlanketDetent>, context: BlanketDetent.Context) {
    let sources: Set<BlanketDetent> = detents.isEmpty ? [.content] : detents
    let ordered = sources.map {
      BlanketDetent.Resolved(source: $0, height: $0.resolve(in: context))
    }.sorted { lhs, rhs in
      if lhs.height != rhs.height { return lhs.height < rhs.height }
      return Self.priority(lhs.source) < Self.priority(rhs.source)
    }
    self.detents = ordered.reduce(into: []) { result, next in
      if result.last?.height != next.height { result.append(next) }
    }
  }

  var minimum: BlanketDetent.Resolved { detents[0] }
  var maximum: BlanketDetent.Resolved { detents[detents.count - 1] }

  func nearest(to height: CGFloat, velocity: CGFloat = 0) -> BlanketDetent.Resolved {
    guard height > minimum.height else { return minimum }
    guard height < maximum.height else { return maximum }
    let lower = detents.last(where: { $0.height <= height }) ?? minimum
    let higher = detents.first(where: { $0.height >= height }) ?? maximum
    if velocity < -300 { return higher }
    if velocity > 300 { return lower }
    return height - lower.height < higher.height - height ? lower : higher
  }

  private static func priority(_ detent: BlanketDetent) -> Int {
    switch detent.node {
    case .content: return 0
    case .height: return 1
    case .fraction: return 2
    }
  }
}

struct BlanketPresentationState: Equatable {
  enum Phase: Equatable {
    case hidden, measuring, entering, presented, dismissing
  }

  private(set) var phase: Phase = .hidden
  private(set) var generation = 0

  mutating func present() {
    generation += 1
    phase = .measuring
  }

  mutating func prepareToEnter() -> Int? {
    guard phase == .measuring else { return nil }
    phase = .entering
    return generation
  }

  mutating func finishEntering(generation: Int) -> Bool {
    guard self.generation == generation, phase == .entering else { return false }
    phase = .presented
    return true
  }

  mutating func dismiss() -> Int? {
    guard phase != .hidden, phase != .dismissing else { return nil }
    generation += 1
    phase = .dismissing
    return generation
  }

  mutating func finishDismissal(generation: Int) -> Bool {
    guard self.generation == generation, phase == .dismissing else { return false }
    phase = .hidden
    return true
  }
}

func blanketSpringVelocity(_ velocity: CGFloat, distance: CGFloat) -> CGFloat {
  guard velocity.isFinite, distance.isFinite, abs(distance) > 0.5 else { return 0 }
  return min(20, max(-20, velocity / distance))
}

private struct ContentDescriptor: Equatable {
  var maximumSize: CGSize = .zero
  var contentHeight: CGFloat?
  var detents: Set<BlanketDetent> = []
  var safeAreaBottom: CGFloat = 0
}

@MainActor
private final class Model: ObservableObject {
  var presentingOffset: CGFloat = 0
  var dragStartHeight: CGFloat?
}

@available(iOS 18.0, *)
public struct BlanketModifier<DisplayContent: View>: ViewModifier {
  private let displayContent: () -> DisplayContent
  private let configuration: BlanketConfiguration
  private let onDismiss: (() -> Void)?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Binding private var isPresented: Bool
  @State private var presentation = BlanketPresentationState()
  @State private var descriptor = ContentDescriptor()
  @State private var selectedDetent: BlanketDetent?
  @State private var dragHeight: CGFloat?
  @State private var contentOffset: CGFloat = 0
  @State private var isScrollLockEnabled = true
  @StateObject private var model = Model()

  public init(
    isPresented: Binding<Bool>,
    configuration: BlanketConfiguration = .init(),
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder displayContent: @escaping () -> DisplayContent
  ) {
    self._isPresented = isPresented
    self.configuration = configuration
    self.onDismiss = onDismiss
    self.displayContent = displayContent
  }

  private var resolved: ResolvedDetents? {
    guard let contentHeight = descriptor.contentHeight, descriptor.maximumSize.height > 0 else {
      return nil
    }
    return .init(descriptor.detents, context: .init(
      maxDetentValue: descriptor.maximumSize.height,
      contentHeight: contentHeight
    ))
  }

  private var restingHeight: CGFloat? {
    guard let resolved else { return nil }
    return resolved.detents.first(where: { $0.source == selectedDetent })?.height
      ?? resolved.minimum.height
  }

  private var hidingOffset: CGFloat {
    (dragHeight ?? restingHeight ?? descriptor.maximumSize.height) + descriptor.safeAreaBottom
  }

  private var animation: Animation {
    reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.85)
  }

  public func body(content: Content) -> some View {
    content
      .modifier(SizingModifier { descriptor.maximumSize = $0 })
      .onGeometryChange(for: CGFloat.self, of: { $0.safeAreaInsets.bottom }) {
        descriptor.safeAreaBottom = $0
      }
      .overlay(alignment: .bottom) {
        if presentation.phase != .hidden {
          display
        }
      }
      .coordinateSpace(name: CoordinateSpaceTag.transition)
      .onChange(of: isPresented, initial: true) { _, isPresented in
        if isPresented {
          present()
        } else {
          dismiss()
        }
      }
      .onChange(of: descriptor) { _, _ in resolve() }
  }

  private var display: some View {
    ZStack(alignment: .bottom) {
      if case .presentation(let configuration) = configuration.mode {
        configuration.backgroundColor
          .opacity(presentation.phase == .presented ? 1 : 0)
          .animation(animation, value: presentation.phase)
          .contentShape(Rectangle())
          .onTapGesture { isPresented = false }
          .allowsHitTesting(configuration.handlesOutOfContent)
          .accessibilityHidden(true)
      }

      ContentSizingView(onChange: { descriptor.contentHeight = $0.height }) {
        displayContent()
          .onPreferenceChange(BlanketContentDetentsPreferenceKey.self) {
            descriptor.detents = $0
          }
      }
      .frame(height: dragHeight ?? restingHeight)
      .frame(maxWidth: .infinity)
      .gesture(ScrollViewInteroperableDragGesture(
        configuration: .init(ignoresScrollView: false, targetEdges: .top, sticksToEdges: false),
        isScrollLockEnabled: $isScrollLockEnabled,
        coordinateSpaceInDragging: .named(CoordinateSpaceTag.transition),
        onChange: { onChange(translation: $0.translation) },
        onEnd: { onEnd(velocity: $0.velocity.height) }
      ))
      ._animatableOffset(y: contentOffset) { model.presentingOffset = $0 }
      .opacity(presentation.phase == .measuring ? 0 : 1)
      .accessibilityAction(.escape) { isPresented = false }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .allowsHitTesting(presentation.phase == .presented)
    .accessibilityHidden(presentation.phase != .presented)
  }

  private func present() {
    if presentation.phase == .hidden {
      descriptor.contentHeight = nil
      descriptor.detents = []
    }
    model.dragStartHeight = nil
    selectedDetent = nil
    dragHeight = nil
    isScrollLockEnabled = true
    presentation.present()
    resolve()
  }

  private func resolve() {
    guard let resolved else { return }
    if presentation.phase == .measuring || presentation.phase == .entering {
      selectedDetent = resolved.minimum.source
    } else if let selectedDetent, !resolved.detents.contains(where: { $0.source == selectedDetent }) {
      self.selectedDetent = resolved.nearest(to: selectedDetent.resolve(in: .init(
        maxDetentValue: descriptor.maximumSize.height,
        contentHeight: descriptor.contentHeight ?? 0
      ))).source
    } else if selectedDetent == nil {
      selectedDetent = resolved.minimum.source
    }
    if model.dragStartHeight == nil {
      isScrollLockEnabled = (restingHeight ?? 0) < resolved.maximum.height
    }
    guard let generation = presentation.prepareToEnter() else { return }
    contentOffset = hidingOffset
    model.presentingOffset = contentOffset
    Task { @MainActor in
      await Task.yield()
      guard isPresented, presentation.generation == generation else { return }
      withAnimation(animation) {
        if presentation.finishEntering(generation: generation) {
          contentOffset = 0
        }
      }
    }
  }

  private func dismiss() {
    guard let generation = presentation.dismiss() else { return }
    model.dragStartHeight = nil
    withAnimation(animation, completionCriteria: .removed) {
      contentOffset = hidingOffset
    } completion: {
      guard presentation.finishDismissal(generation: generation) else { return }
      selectedDetent = nil
      dragHeight = nil
      contentOffset = 0
      model.presentingOffset = 0
      onDismiss?()
    }
  }

  private func onChange(translation: CGSize) {
    guard presentation.phase == .presented, let resolved else { return }
    if model.dragStartHeight == nil {
      guard abs(translation.height) > abs(translation.width) else { return }
      model.dragStartHeight = (dragHeight ?? restingHeight ?? 0) - model.presentingOffset
    }
    let proposed = (model.dragStartHeight ?? 0) - translation.height
    if proposed < resolved.minimum.height {
      dragHeight = resolved.minimum.height
      contentOffset = resolved.minimum.height - proposed
    } else {
      contentOffset = 0
      dragHeight = rubberBand(
        value: proposed, min: resolved.minimum.height, max: resolved.maximum.height, bandLength: 20
      )
    }
    isScrollLockEnabled = proposed < resolved.maximum.height
  }

  private func onEnd(velocity: CGFloat) {
    guard model.dragStartHeight != nil, let resolved else { return }
    model.dragStartHeight = nil
    if contentOffset > 0,
      velocity > 300 || contentOffset > min(100, max(30, resolved.minimum.height * 0.25))
    {
      isPresented = false
      return
    }
    let height = dragHeight ?? restingHeight ?? resolved.minimum.height
    let nearest = resolved.nearest(to: height, velocity: velocity)
    let springVelocity = blanketSpringVelocity(-velocity, distance: nearest.height - height)
    let snap: Animation = reduceMotion ? animation : .interpolatingSpring(
      mass: 1, stiffness: 200, damping: 25, initialVelocity: springVelocity
    )
    withAnimation(snap) {
      selectedDetent = nearest.source
      dragHeight = nil
      contentOffset = 0
    }
    isScrollLockEnabled = nearest.height < resolved.maximum.height
  }
}

private enum CoordinateSpaceTag: Hashable {
  case transition
}

@available(iOS 18.0, *)
extension View {
  /// Displays a blanket within this view's bounds. An empty detent set uses `.content`.
  public func blanket<Content: View>(
    isPresented: Binding<Bool>,
    configuration: BlanketConfiguration = .init(),
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    modifier(BlanketModifier(
      isPresented: isPresented,
      configuration: configuration,
      onDismiss: onDismiss,
      displayContent: content
    ))
  }

  /// Replacing an item's identity replaces the blanket's content without dismissing it.
  public func blanket<Item: Identifiable, Content: View>(
    item: Binding<Item?>,
    configuration: BlanketConfiguration = .init(),
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View {
    modifier(ItemBlanketModifier(
      item: item, configuration: configuration, onDismiss: onDismiss, displayContent: content
    ))
  }
}

@available(iOS 18.0, *)
private struct ItemBlanketModifier<Item: Identifiable, DisplayContent: View>: ViewModifier {
  @Binding var item: Item?
  let configuration: BlanketConfiguration
  let onDismiss: (() -> Void)?
  @ViewBuilder let displayContent: (Item) -> DisplayContent
  @State private var retainedItem = ItemCache<Item>()

  init(
    item: Binding<Item?>,
    configuration: BlanketConfiguration,
    onDismiss: (() -> Void)?,
    @ViewBuilder displayContent: @escaping (Item) -> DisplayContent
  ) {
    self._item = item
    self.configuration = configuration
    self.onDismiss = onDismiss
    self.displayContent = displayContent
  }

  func body(content: Content) -> some View {
    let displayedItem = item ?? retainedItem.value
    content
      .blanket(isPresented: .init(
        get: { item != nil },
        set: { if !$0 { item = nil } }
      ), configuration: configuration, onDismiss: {
        retainedItem.value = nil
        onDismiss?()
      }) {
        if let displayedItem {
          displayContent(displayedItem)
            .id(displayedItem.id)
        }
      }
      .onReceive(Just(item)) { item in
        if let item { retainedItem.value = item }
      }
  }
}

@MainActor
private final class ItemCache<Item> {
  // Retain the latest value for the exit animation without requiring Item to be Equatable.
  var value: Item?
}

enum BlanketContentDetentsPreferenceKey: PreferenceKey {
  static var defaultValue: Set<BlanketDetent> { [] }

  static func reduce(value: inout Set<BlanketDetent>, nextValue: () -> Set<BlanketDetent>) {
    value.formUnion(nextValue())
  }
}

extension View {
  public func blanketContentDetents(
    _ firstDetent: BlanketDetent, _ detents: BlanketDetent...
  ) -> some View {
    blanketContentDetents(Set(CollectionOfOne(firstDetent) + detents))
  }

  public func blanketContentDetents(_ detent: BlanketDetent) -> some View {
    blanketContentDetents(Set([detent]))
  }

  public func blanketContentDetents(_ detents: some Collection<BlanketDetent>) -> some View {
    blanketContentDetents(Set(detents))
  }

  public func blanketContentDetents(_ detents: Set<BlanketDetent>) -> some View {
    preference(key: BlanketContentDetentsPreferenceKey.self, value: detents)
  }
}
