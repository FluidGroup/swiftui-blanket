import Foundation
import Testing

@testable import SwiftUIBlanket

struct DetentTests {
  private let context = BlanketDetent.Context(maxDetentValue: 600, contentHeight: 200)

  @Test func resolvesHeights() {
    #expect(BlanketDetent.content.resolve(in: context) == 200)
    #expect(BlanketDetent.height(100).resolve(in: context) == 100)
    #expect(BlanketDetent.fraction(0.5).resolve(in: context) == 300)
  }

  @Test func clampsEveryDetentToContainer() {
    #expect(
      BlanketDetent.content.resolve(in: .init(maxDetentValue: 100, contentHeight: 200)) == 100)
    #expect(BlanketDetent.height(900).resolve(in: context) == 600)
    #expect(BlanketDetent.fraction(2).resolve(in: context) == 600)
    #expect(BlanketDetent.height(-100).resolve(in: context) == 0)
    #expect(BlanketDetent.fraction(-1).resolve(in: context) == 0)
  }

  @Test func handlesNonFiniteInputs() {
    #expect(BlanketDetent.height(.nan).resolve(in: context) == 0)
    #expect(BlanketDetent.fraction(.nan).resolve(in: context) == 0)
    #expect(BlanketDetent.height(.infinity).resolve(in: context) == 600)
    #expect(BlanketDetent.height(-.infinity).resolve(in: context) == 0)
    #expect(BlanketDetent.content.resolve(in: .init(maxDetentValue: -1, contentHeight: 200)) == 0)
    #expect(BlanketDetent.content.resolve(in: .init(maxDetentValue: .nan, contentHeight: 200)) == 0)
  }

  @Test func emptyDetentsUseContent() {
    let resolved = ResolvedDetents([], context: context)
    #expect(resolved.detents == [.init(source: .content, height: 200)])
  }

  @Test func sortsAndDeduplicatesResolvedHeights() {
    let resolved = ResolvedDetents(
      [.fraction(1), .content, .height(100), .height(600)], context: context)
    #expect(resolved.detents.map(\.height) == [100, 200, 600])
    #expect(resolved.minimum.source == .height(100))
  }

  @Test func nearestHandlesBothBounds() {
    let resolved = ResolvedDetents([.height(100), .height(300), .height(600)], context: context)
    #expect(resolved.nearest(to: -100).height == 100)
    #expect(resolved.nearest(to: 900).height == 600)
    #expect(resolved.nearest(to: 170).height == 100)
    #expect(resolved.nearest(to: 240).height == 300)
    #expect(resolved.nearest(to: 300).height == 300)
  }

  @Test func velocitySelectsAdjacentDetent() {
    let resolved = ResolvedDetents([.height(100), .height(300), .height(600)], context: context)
    #expect(resolved.nearest(to: 140, velocity: -500).height == 300)
    #expect(resolved.nearest(to: 280, velocity: 500).height == 100)
  }

  @Test func adaptsToContentAndContainerChanges() {
    let sources: Set<BlanketDetent> = [.content, .fraction(1)]
    #expect(ResolvedDetents(sources, context: context).detents.map(\.height) == [200, 600])
    #expect(
      ResolvedDetents(sources, context: .init(maxDetentValue: 400, contentHeight: 250))
        .detents.map(\.height) == [250, 400])
  }

  @Test func springVelocityStaysFinite() {
    #expect(blanketSpringVelocity(100, distance: 0) == 0)
    #expect(blanketSpringVelocity(0, distance: 0) == 0)
    #expect(blanketSpringVelocity(.infinity, distance: 10) == 0)
    #expect(blanketSpringVelocity(100, distance: .nan) == 0)
    #expect(blanketSpringVelocity(100, distance: 10) == 10)
    #expect(blanketSpringVelocity(1000, distance: 1) == 20)
    #expect(blanketSpringVelocity(-1000, distance: 1) == -20)
  }
}

struct PresentationStateTests {
  @Test func initialPresentationEntersAfterMeasurement() throws {
    var state = BlanketPresentationState()
    #expect(state.phase == .hidden)
    state.present()
    #expect(state.phase == .measuring)
    let pending = state.prepareToEnter()
    let generation = try #require(pending)
    let didEnter = state.finishEntering(generation: generation)
    #expect(didEnter)
    #expect(state.phase == .presented)
  }

  @Test func dismissalCompletesOnlyOnce() throws {
    var state = BlanketPresentationState()
    let initialDismissal = state.dismiss()
    #expect(initialDismissal == nil)
    state.present()
    let pending = state.dismiss()
    let generation = try #require(pending)
    let repeatedDismissal = state.dismiss()
    #expect(repeatedDismissal == nil)
    let didDismiss = state.finishDismissal(generation: generation)
    let repeatedCompletion = state.finishDismissal(generation: generation)
    #expect(didDismiss)
    #expect(!repeatedCompletion)
    #expect(state.phase == .hidden)
  }

  @Test func dismissalCancelsPendingEntrance() throws {
    var state = BlanketPresentationState()
    state.present()
    let pendingEntrance = state.prepareToEnter()
    let entrance = try #require(pendingEntrance)
    let pendingDismissal = state.dismiss()
    let dismissal = try #require(pendingDismissal)
    let didEnter = state.finishEntering(generation: entrance)
    let didDismiss = state.finishDismissal(generation: dismissal)
    #expect(!didEnter)
    #expect(didDismiss)
  }

  @Test func rePresentationIgnoresStaleDismissal() throws {
    var state = BlanketPresentationState()
    state.present()
    let pendingDismissal = state.dismiss()
    let dismissal = try #require(pendingDismissal)
    state.present()
    let didDismiss = state.finishDismissal(generation: dismissal)
    #expect(!didDismiss)
    let pendingEntrance = state.prepareToEnter()
    let entrance = try #require(pendingEntrance)
    let didEnter = state.finishEntering(generation: entrance)
    #expect(didEnter)
    #expect(state.phase == .presented)
  }
}
