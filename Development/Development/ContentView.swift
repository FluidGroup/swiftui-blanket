//
//  ContentView.swift
//  Development
//
//  Created by Muukii on 2024/07/27.
//

import SwiftUI
import SwiftUIBlanket

struct ContentView: View {
  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink("[.content]", destination: InlinePreview(detents: [.content]))
          NavigationLink("[.content, .fraction(1)]", destination: InlinePreview(detents: [.content, .fraction(1)]))
        }
      }
    }
    
  }
}

struct SheetContent: View {
  
  @State var isExpanded = false
  
  private let title: String
  
  init(title: String) {
    self.title = title
  }
  
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20).fill(.background)
      VStack {
        HStack {
          VStack(alignment: .leading) {
            
            Text(title)
              .font(.title)
            
            HStack {
              RoundedRectangle(cornerRadius: 8)
                .fill(.tertiary)
                .frame(height: 100)
              
              ScrollView {
                VStack {
                  ForEach(0..<50) { index in
                    RoundedRectangle(cornerRadius: 8)
                      .fill(.tertiary)
                      .frame(height: 30)
                  }
                }
              }
              .frame(height: 300)
            }
            
            ScrollView(.horizontal) {
              HStack {
                ForEach(0..<50) { index in
                  RoundedRectangle(cornerRadius: 8)
                    .fill(.tertiary)
                    .frame(width: 60, height: 60)
                }
              }
            }
            
            if isExpanded {
              RoundedRectangle(cornerRadius: 8)
                .fill(.tertiary)
                .frame(height: 100)          
            }
            
            HStack {
              Spacer()
              Button("Detail") {
                withAnimation(.spring) {
                  isExpanded.toggle()
                }
              }
              .buttonBorderShape(.roundedRectangle)
            }
          }
          Spacer(minLength: 0)
        }
        .padding()
        Spacer(minLength: 0)
      }
    }
    .foregroundStyle(.primary)
    .backgroundStyle(.orange)
    .tint(.orange)
    .clipped()
    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 0)
    .padding(8)
  }
}

struct InlinePreview: View {
  
  @State var isPresented = false
  
  private let detents: Set<BlanketDetent>
  
  init(detents: Set<BlanketDetent>) {
    self.detents = detents
  }
  
  var body: some View {
    VStack {
      Button("Show") {
        isPresented.toggle()
      }
      Text("Showing : \(isPresented.description)")
      Rectangle()
        .fill(Color.purple)
        .ignoresSafeArea()
    }
    .blanket(isPresented: $isPresented) {
      SheetContent(title: "This is a blanket")
        .blanketContentDetents(detents)
    }
  }
}

#Preview("isPresented default"){
  
  return InlinePreview(detents: [])
  
}

#Preview("[.content, .fraction(1)]") {
  return InlinePreview(detents: [.content, .fraction(1)])
}

#Preview("item"){
  
  struct Item: Identifiable {
    let id = UUID()
    let title: String
  }
  
  struct Preview: View {
    
    @State var item: Item?
    
    var body: some View {
      VStack {
        Button("Show A") {
          item = .init(title: "This is a blanket A")
        }
        Button("Show B") {
          item = .init(title: "This is a blanket B")
        }
        Button("Show C") {
          item = .init(title: "This is a blanket C")
        }
        Rectangle()
          .fill(Color.purple)
          .ignoresSafeArea()
      }
      .blanket(item: $item) { item in
        SheetContent(
          title: item.title
        )
      }
    }
  }
  
  return Preview()
}

@available(iOS 16.0, *)
#Preview("Sheet"){
  
  struct Item: Identifiable {
    let id = UUID()
    let title: String
  }
    
  struct InlineView: View {
        
    @State var item: Item?
    
    var body: some View {
      VStack {
        
        Button("Auto") {
          Task {
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            item = .init(title: "1")
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            item = .init(title: "2")
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            item = .init(title: "3")
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            item = nil
            
          }
        }
        
        Button("Show A") {
          item = .init(title: "This is a blanket A")
        }
        Button("Show B") {
          item = .init(title: "This is a blanket B")
        }
        Button("Show C") {
          item = .init(title: "This is a blanket C")
        }
        Rectangle()
          .fill(Color.purple)
          .ignoresSafeArea()
      }
      .sheet(item: $item) { item in 
        SheetContent(
          title: item.title
        )
      }
    }
  }

  return InlineView()
}
