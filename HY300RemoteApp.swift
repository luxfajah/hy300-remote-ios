import SwiftUI

/// HY300Pro Remote Control — Built with Apple's Liquid Glass Design System (iOS 26 / iOS 27)
/// Uses GlassEffectContainer, .glassEffect(.regular.interactive()), .backgroundExtensionEffect(), and .buttonStyle(.glassProminent)
@main
struct HY300RemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

@MainActor
final class ProjectorClient: ObservableObject {
    @Published var baseURL: String = "http://192.168.1.7:8090"
    @Published var isAwake: Bool = true
    @Published var resolution: String = "1920x1080"
    @Published var ramUsage: String = "—"
    @Published var statusText: String = "Conectado"

    func send(_ path: String, body: [String: Any]? = nil) async {
        guard let url = URL(string: baseURL + path) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        _ = try? await URLSession.shared.data(for: req)
        await refresh()
    }

    func refresh() async {
        guard let url = URL(string: baseURL + "/api/status"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            statusText = "Offline"
            return
        }
        isAwake = (json["awake"] as? Bool) ?? false
        resolution = ((json["size"] as? String) ?? "1280x720").replacingOccurrences(of: "Override size: ", with: "")
        ramUsage = (json["mem"] as? String) ?? "—"
        statusText = isAwake ? "Ligado • \(resolution)" : "Standby • Wi-Fi Ativo"
    }
}

struct ContentView: View {
    @StateObject private var client = ProjectorClient()
    @Namespace private var glassNS
    @State private var showKeystoneSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.07, green: 0.12, blue: 0.22), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .hyBackgroundExtension()

                ScrollView {
                    VStack(spacing: 20) {
                        // Power & Status Liquid Glass Platter
                        HYGlassContainer(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("HY300Pro Cinema")
                                        .font(.title2.bold())
                                    Text(client.statusText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    Task { await client.send(client.isAwake ? "/api/power/standby" : "/api/power/wake") }
                                } label: {
                                    Label(client.isAwake ? "Standby" : "Ligar", systemImage: "power")
                                }
                                .hyGlassProminentButton()
                                .tint(client.isAwake ? .orange : .blue)
                                .hyGlassID("powerBtn", in: glassNS)
                            }
                            .padding(20)
                            .hyGlassCard(cornerRadius: 34)
                        }

                        // Quick Apps Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            appButton("Stremio", icon: "film.stack", path: "/api/app/stremio", tint: .indigo)
                            appButton("UniTV", icon: "tv", path: "/api/app/unitv", tint: .cyan)
                            appButton("SmartTube", icon: "play.rectangle.fill", path: "/api/app/smarttube", tint: .red)
                            appButton("HDMI", icon: "cable.connector.horizontal", path: "/api/app/hdmi", tint: .green)
                            appButton("Keystone", icon: "trapezoid.and.line.horizontal", path: nil, tint: .orange) {
                                showKeystoneSheet = true
                            }
                            appButton("Ajustes", icon: "gearshape", path: "/api/app/settings", tint: .gray)
                        }

                        // Apple TV Style Liquid Glass D-Pad
                        HYGlassContainer(spacing: 14) {
                            VStack(spacing: 14) {
                                dpadButton("chevron.up", key: "up")
                                HStack(spacing: 22) {
                                    dpadButton("chevron.left", key: "left")
                                    Button("OK") {
                                        Task { await client.send("/api/key/ok") }
                                    }
                                    .font(.headline)
                                    .frame(width: 72, height: 72)
                                    .hyGlassProminentButton()
                                    .hyGlassID("okBtn", in: glassNS)
                                    dpadButton("chevron.right", key: "right")
                                }
                                dpadButton("chevron.down", key: "down")

                                HStack(spacing: 12) {
                                    navPill("arrow.uturn.backward", key: "back")
                                    navPill("house", key: "home")
                                    navPill("speaker.wave.1", key: "vol_down")
                                    navPill("speaker.wave.3", key: "vol_up")
                                }
                            }
                            .padding(22)
                            .hyGlassCard(cornerRadius: 34)
                        }
                    }
                    .padding(16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keystone", systemImage: "viewfinder") {
                        showKeystoneSheet = true
                    }
                }
            }
            .sheet(isPresented: $showKeystoneSheet) {
                KeystoneSheetView(client: client)
                    .presentationDetents([.medium, .large])
            }
            .task { await client.refresh() }
        }
    }

    private func appButton(_ title: String, icon: String, path: String?, tint: Color, customAction: (() -> Void)? = nil) -> some View {
        Button {
            if let customAction { customAction() }
            else if let path { Task { await client.send(path) } }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 82)
        }
        .hyGlassInteractiveCard(cornerRadius: 22)
    }

    private func dpadButton(_ symbol: String, key: String) -> some View {
        Button {
            Task { await client.send("/api/key/\(key)") }
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .hyGlassCircle()
    }

    private func navPill(_ symbol: String, key: String) -> some View {
        Button {
            Task { await client.send("/api/key/\(key)") }
        } label: {
            Image(systemName: symbol)
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .hyGlassButton()
    }
}

struct KeystoneSheetView: View {
    @ObservedObject var client: ProjectorClient
    var body: some View {
        VStack(spacing: 16) {
            Text("Keystone & Resolução")
                .font(.title3.bold())
            HStack(spacing: 12) {
                Button("1080p HD") { Task { await client.send("/api/resolution/1080p") } }
                    .hyGlassProminentButton()
                Button("720p TV") { Task { await client.send("/api/resolution/720p_tv") } }
                    .hyGlassButton()
            }
            Button("Resetar Keystone 100%") {
                Task { await client.send("/api/keystone/reset") }
            }
            .hyGlassButton()
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Liquid Glass Compatibility Layer (iOS 26 native + iOS 18 translucent fallback)

private struct HYGlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
        #else
        content()
        #endif
    }
}

private extension View {
    @ViewBuilder func hyBackgroundExtension() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder func hyGlassID(_ id: String, in ns: Namespace.ID) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffectID(id, in: ns)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder func hyGlassCard(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        }
        #else
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        #endif
    }

    @ViewBuilder func hyGlassInteractiveCard(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.buttonStyle(.plain)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        }
        #else
        self.buttonStyle(.plain)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        #endif
    }

    @ViewBuilder func hyGlassCircle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
        }
        #else
        self.buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
        #endif
    }

    @ViewBuilder func hyGlassButton() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
                .clipShape(Capsule())
        }
        #else
        self.buttonStyle(.bordered)
            .clipShape(Capsule())
        #endif
    }

    @ViewBuilder func hyGlassProminentButton() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
                .clipShape(Capsule())
        }
        #else
        self.buttonStyle(.borderedProminent)
            .clipShape(Capsule())
        #endif
    }
}
