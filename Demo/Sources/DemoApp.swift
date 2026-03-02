import SwiftUI
import WuhuDocView

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 700)
        #endif
    }
}

struct ContentView: View {
    @State private var selectedDoc: DocChoice? = .infinite

    enum DocChoice: String, CaseIterable, Identifiable {
        case infinite = "Infinite Doc (All)"
        case architecture = "Architecture Decision"
        case flattening = "Flattening Strategy"
        case chat = "Chat Session Demo"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationSplitView {
            List(DocChoice.allCases, selection: $selectedDoc) { choice in
                Text(choice.rawValue)
                    .tag(choice)
            }
            .navigationTitle("Documents")
        } detail: {
            if let choice = selectedDoc {
                DocView(document: document(for: choice))
                    .id(choice)
            } else {
                Text("Select a document")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func document(for choice: DocChoice) -> Document {
        switch choice {
        case .infinite:
            return SampleData.infiniteDoc
        case .architecture:
            return Document(sections: [SampleData.architectureDecisionDoc])
        case .flattening:
            return Document(sections: [SampleData.flatteningStrategyDoc])
        case .chat:
            return Document(sections: [SampleData.chatSessionDemo])
        }
    }
}
