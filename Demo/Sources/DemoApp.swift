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
    @State private var selectedDoc: DocChoice? = .streaming

    enum DocChoice: String, CaseIterable, Identifiable {
        case streaming = "Streaming Demo"
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
            switch selectedDoc {
            case .streaming:
                StreamingDemoView()
            case .infinite:
                DocView(document: SampleData.infiniteDoc)
                    .id(DocChoice.infinite)
            case .architecture:
                DocView(document: Document(sections: [SampleData.architectureDecisionDoc]))
                    .id(DocChoice.architecture)
            case .flattening:
                DocView(document: Document(sections: [SampleData.flatteningStrategyDoc]))
                    .id(DocChoice.flattening)
            case .chat:
                DocView(document: Document(sections: [SampleData.chatSessionDemo]))
                    .id(DocChoice.chat)
            case nil:
                Text("Select a document")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
