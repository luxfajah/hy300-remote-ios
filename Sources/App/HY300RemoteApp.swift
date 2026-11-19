import SwiftUI

@main
struct HY300RemoteApp: App {
    @State private var client = ProjectorClient()
    @State private var discovery = BonjourDiscoveryService()

    var body: some Scene {
        WindowGroup {
            RemoteRootView(client: client, discovery: discovery)
                .preferredColorScheme(.dark)
        }
    }
}
