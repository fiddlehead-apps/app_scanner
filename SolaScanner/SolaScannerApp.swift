import SwiftUI

@main
struct SolaScannerApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
                .tint(Color.brand)
        }
    }
}
