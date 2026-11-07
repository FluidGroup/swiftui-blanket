import SwiftUI
import SwiftUIBlanket

struct ContentView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("Inline") {
          NavigationLink("Content height") {
            BlanketPreview(detents: [.content])
          }
          NavigationLink("Multiple detents") {
            BlanketPreview(detents: [.height(240), .content, .fraction(1)])
          }
          NavigationLink("Initially presented") {
            BlanketPreview(detents: [.content, .fraction(1)], initiallyPresented: true)
          }
        }
        Section("Presentation") {
          NavigationLink("Tap the backdrop to dismiss") {
            BlanketPreview(
              detents: [.content, .fraction(1)],
              configuration: .init(mode: .presentation(.init()))
            )
          }
        }
        Section("Items") {
          NavigationLink("Replace content while presented") { ItemPreview() }
        }
      }
      .navigationTitle("SwiftUI Blanket")
    }
  }
}

private struct BlanketPreview: View {
  let detents: Set<BlanketDetent>
  var configuration = BlanketConfiguration()
  @State private var isPresented: Bool
  @State private var dismissalCount = 0

  init(
    detents: Set<BlanketDetent>,
    configuration: BlanketConfiguration = .init(),
    initiallyPresented: Bool = false
  ) {
    self.detents = detents
    self.configuration = configuration
    self._isPresented = .init(initialValue: initiallyPresented)
  }

  var body: some View {
    VStack {
      HStack {
        Button("Show") { isPresented = true }
          .accessibilityIdentifier("show-blanket")
        Button("Dismiss") { isPresented = false }
          .accessibilityIdentifier("dismiss-blanket")
      }
      Text("Presented: \(isPresented.description) · Dismissals: \(dismissalCount)")
        .font(.caption)
        .accessibilityIdentifier("presentation-status")
      Spacer()
      Text("Drag the blanket. At its largest detent, scroll the list.")
        .multilineTextAlignment(.center)
      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.purple.opacity(0.15))
    .blanket(isPresented: $isPresented, configuration: configuration, onDismiss: didDismiss) {
      SheetContent(title: "This is a blanket", onClose: { isPresented = false })
        .blanketContentDetents(detents)
    }
    .navigationTitle("Blanket")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func didDismiss() { dismissalCount += 1 }
}

private struct SheetContent: View {
  let title: String
  let onClose: () -> Void
  @State private var isExpanded = false

  var body: some View {
    VStack(spacing: 12) {
      Capsule()
        .fill(.secondary)
        .frame(width: 36, height: 5)
        .accessibilityHidden(true)
      HStack {
        Text(title).font(.headline)
        Spacer()
        Button("Close", action: onClose)
      }
      ScrollView(.horizontal) {
        HStack {
          ForEach(0..<20) { index in
            Text("\(index)")
              .frame(width: 60, height: 60)
              .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
      ScrollView {
        LazyVStack {
          ForEach(0..<50) { index in
            Text("Row \(index)")
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(8)
              .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
      .frame(idealHeight: 200)
      if isExpanded {
        Text("The content detent follows changes to the content's ideal height.")
          .frame(height: 80)
      }
      Button(isExpanded ? "Less content" : "More content") {
        withAnimation { isExpanded.toggle() }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    .padding(8)
  }
}

private struct ItemPreview: View {
  private struct Item: Identifiable {
    let id = UUID()
    let title: String
  }

  @State private var item: Item?
  @State private var dismissalCount = 0

  var body: some View {
    VStack {
      HStack {
        Button("Show A") { item = .init(title: "Blanket A") }
        Button("Show B") { item = .init(title: "Blanket B") }
        Button("Clear") { item = nil }
      }
      Text("Dismissals: \(dismissalCount)")
      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.orange.opacity(0.1))
    .blanket(item: $item, onDismiss: didDismiss) { item in
      SheetContent(title: item.title, onClose: { self.item = nil })
        .blanketContentDetents(.content, .fraction(1))
    }
    .navigationTitle("Item replacement")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func didDismiss() { dismissalCount += 1 }
}

#Preview { ContentView() }
