import SwiftUI

@main
struct HY300RemoteApp: App {
    @State private var client = ProjectorClient()
    @State private var discovery = BonjourDiscoveryService()
    @State private var updateService = GitHubUpdateService()

    var body: some Scene {
        WindowGroup {
            RemoteRootView(
                client: client,
                discovery: discovery,
                updateService: updateService
            )
            .preferredColorScheme(.dark)
        }
    }
}
