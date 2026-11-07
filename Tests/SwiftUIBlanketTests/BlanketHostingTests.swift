import Observation
import SwiftUI
import Testing
import UIKit
@testable import SwiftUIBlanket

@Suite(.serialized)
@MainActor
struct BlanketHostingTests {
  @Test func initiallyPresentedDismissesAndPresentsAgain() async throws {
    let state = HostState()
    state.isPresented = true
    try await withHost(BooleanHost(state: state)) {
      #expect(await eventually { state.appearances == 1 && state.measuredHeight == 120 })
      state.isPresented = false
      #expect(await eventually { state.dismissals == 1 && state.disappearances == 1 })
      state.isPresented = true
      #expect(await eventually { state.appearances == 2 && state.measuredHeight == 120 })
      state.isPresented = false
      #expect(await eventually { state.dismissals == 2 && state.disappearances == 2 })
    }
  }

  @Test func initiallyHiddenDoesNotDismiss() async throws {
    let state = HostState()
    try await withHost(BooleanHost(state: state)) {
      try await Task.sleep(for: .milliseconds(100))
      #expect(state.appearances == 0)
      #expect(state.dismissals == 0)
    }
  }

  @Test func contentHeightTracksChangesWithoutRePresenting() async throws {
    let state = HostState()
    state.isPresented = true
    try await withHost(BooleanHost(state: state)) {
      #expect(await eventually { state.measuredHeight == 120 })
      state.contentHeight = 240
      #expect(await eventually { state.measuredHeight == 240 })
      #expect(state.appearances == 1)
      #expect(state.dismissals == 0)
    }
  }

  @Test func fractionsTrackContainerResizingAndDetentChanges() async throws {
    let state = HostState()
    state.isPresented = true
    state.detents = [.fraction(0.5)]
    try await withHost(BooleanHost(state: state)) {
      #expect(await eventually { state.measuredHeight == 300 })
      state.containerHeight = 400
      #expect(await eventually { state.measuredHeight == 200 })
      state.detents = [.height(900)]
      #expect(await eventually { state.measuredHeight == 400 })
      state.detents = []
      #expect(await eventually { state.measuredHeight == 120 })
    }
  }

  @Test func startsAtSmallestConfiguredDetent() async throws {
    let state = HostState()
    state.isPresented = true
    state.detents = [.height(80), .fraction(1)]
    try await withHost(BooleanHost(state: state)) {
      #expect(await eventually { state.measuredHeight == 80 })
    }
  }

  @Test func itemReplacementAndLatestValueSurviveDismissal() async throws {
    let state = HostState()
    state.item = .init(id: 1, title: "First")
    try await withHost(ItemHost(state: state)) {
      #expect(await eventually { state.displayedTitle == "First" })
      state.item = .init(id: 2, title: "Second")
      #expect(await eventually { state.displayedTitle == "Second" })
      #expect(state.dismissals == 0)
      state.item = .init(id: 2, title: "Updated")
      #expect(await eventually { state.displayedTitle == "Updated" })
      state.item = nil
      #expect(await eventually { state.dismissals == 1 && state.lastRemovedTitle == "Updated" })
      state.item = .init(id: 3, title: "Third")
      #expect(await eventually { state.displayedTitle == "Third" })
    }
  }

  private func withHost<Content: View>(
    _ content: Content,
    perform: () async throws -> Void
  ) async throws {
    let controller = UIHostingController(rootView: content.environment(\.accessibilityReduceMotion, true))
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.view.layoutIfNeeded()
    defer { window.isHidden = true }
    try await perform()
  }

  private func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<150 {
      if condition() { return true }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
  }
}

@MainActor
@Observable
private final class HostState {
  var isPresented = false
  var contentHeight: CGFloat = 120
  var containerHeight: CGFloat = 600
  var detents: Set<BlanketDetent> = []
  var appearances = 0
  var disappearances = 0
  var dismissals = 0
  var measuredHeight: CGFloat = 0
  var item: HostItem?
  var displayedTitle: String?
  var lastRemovedTitle: String?
}

private struct HostItem: Identifiable {
  let id: Int
  let title: String
}

private struct BooleanHost: View {
  @Bindable var state: HostState

  var body: some View {
    Color.clear
      .frame(width: 320, height: state.containerHeight)
      .blanket(isPresented: $state.isPresented, onDismiss: { state.dismissals += 1 }) {
        Text("Content")
          .frame(height: state.contentHeight)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { state.measuredHeight = $0 }
          .blanketContentDetents(state.detents)
          .onAppear { state.appearances += 1 }
          .onDisappear { state.disappearances += 1 }
      }
  }
}

private struct ItemHost: View {
  @Bindable var state: HostState

  var body: some View {
    Color.clear
      .frame(width: 320, height: 600)
      .blanket(item: $state.item, onDismiss: { state.dismissals += 1 }) { item in
        Text(item.title)
          .frame(height: 120)
          .onChange(of: item.title, initial: true) { _, title in state.displayedTitle = title }
          .onDisappear { state.lastRemovedTitle = item.title }
      }
  }
}
