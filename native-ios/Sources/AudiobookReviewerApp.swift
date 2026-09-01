import SwiftUI

@main
struct AudiobookReviewerApp: App {
    @StateObject private var model = ReaderViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}
