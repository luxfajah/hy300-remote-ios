import SwiftUI

/// Quick Apps launcher sheet for HY300Pro (Stremio, UniTV, SmartTube, HDMI, Bluetooth, Ajustes, Keystone).
struct QuickAppsSheet: View {
    let client: ProjectorClient
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.obsidianBG.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ProjectorApp.allCases) { app in
                            Button {
                                HapticEngine.shared.tapMedium()
                                client.launchApp(app)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(app.accentColor.opacity(0.20))
                                            .frame(width: 42, height: 42)
                                        Image(systemName: app.systemImage)
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(app.accentColor)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(DesignTokens.labelPrimary)
                                            .lineLimit(1)
                                        Text(app.subtitle)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(DesignTokens.labelSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .hyGlassRounded(cornerRadius: 20, interactive: true)
                            .accessibilityLabel("Abrir \(app.title)")
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Aplicativos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.labelPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
