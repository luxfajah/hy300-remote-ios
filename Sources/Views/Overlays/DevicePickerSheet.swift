import SwiftUI

/// Device picker and live connection diagnostics sheet:
/// Displays active TCP NDJSON status, RTT latency, daemon state, resolution,
/// Bonjour/UDP discovered projectors, and manual IP entry.
struct DevicePickerSheet: View {
    let client: ProjectorClient
    let discovery: BonjourDiscoveryService

    @Environment(\.dismiss) private var dismiss
    @State private var manualHost: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.obsidianBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        activeConnectionCard
                        discoveredSection
                        manualConnectSection
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Projetores")
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
        .onAppear {
            manualHost = client.host
            discovery.startScan()
        }
    }

    // MARK: - Active Connection Diagnostics Card

    private var activeConnectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 11, height: 11)
                    .shadow(color: statusColor.opacity(0.6), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(client.deviceName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignTokens.labelPrimary)
                    Text("\(client.host):\(client.tcpPort)")
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(DesignTokens.labelSecondary)
                }

                Spacer()

                Button {
                    HapticEngine.shared.tapLight()
                    client.reconnectNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignTokens.labelPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .hyGlassCircle(interactive: true)
                .accessibilityLabel("Reconectar")
            }

            Divider().overlay(Color.white.opacity(0.08))

            // Telemetry Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                telemetryCell(
                    label: "Estado",
                    value: client.connectionState.isConnected
                        ? (client.isAwake ? "Ligado" : "Standby")
                        : client.connectionState.label
                )
                telemetryCell(
                    label: "Latência TCP",
                    value: client.latencyMs.map { "\($0) ms" } ?? "—"
                )
                telemetryCell(
                    label: "Resolução",
                    value: client.resolution
                )
                telemetryCell(
                    label: "Daemon Nativo",
                    value: client.isDaemonActive ? "Ativo (v2)" : "Aguardando"
                )
            }
        }
        .padding(16)
        .hyGlassRounded(cornerRadius: 24, interactive: false)
    }

    private func telemetryCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.labelTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(DesignTokens.labelPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Discovered Projectors (Bonjour + UDP 8092)

    private var discoveredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ENCONTRADOS NA REDE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.labelTertiary)

                Spacer()

                Button {
                    HapticEngine.shared.selection()
                    discovery.refresh()
                } label: {
                    HStack(spacing: 5) {
                        if discovery.isScanning {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(discovery.isScanning ? "Buscando…" : "Buscar")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(DesignTokens.labelSecondary)
                }
                .buttonStyle(.plain)
            }

            if discovery.discovered.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "wifi")
                        .foregroundStyle(DesignTokens.labelTertiary)
                    Text(discovery.isScanning
                         ? "Procurando projetores HY300 via Bonjour e UDP…"
                         : "Nenhum projetor descoberto automaticamente.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.labelSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .hyGlassRounded(cornerRadius: 18, interactive: false)
            } else {
                VStack(spacing: 8) {
                    ForEach(discovery.discovered) { projector in
                        let isSelected = projector.host == client.host
                        Button {
                            HapticEngine.shared.tapMedium()
                            manualHost = projector.host
                            client.connect(
                                to: projector.host,
                                tcpPort: projector.tcpPort,
                                httpPort: projector.httpPort
                            )
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "videoprojector.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(isSelected ? DesignTokens.statusAwake : DesignTokens.labelSecondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(projector.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DesignTokens.labelPrimary)
                                    Text("\(projector.host) • \(projector.source.rawValue)")
                                        .font(.system(size: 12).monospacedDigit())
                                        .foregroundStyle(DesignTokens.labelSecondary)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DesignTokens.statusAwake)
                                }
                            }
                            .padding(14)
                        }
                        .buttonStyle(.plain)
                        .hyGlassRounded(cornerRadius: 18, interactive: true)
                    }
                }
            }
        }
    }

    // MARK: - Manual IP Entry

    private var manualConnectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONEXÃO MANUAL POR IP")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.labelTertiary)

            HStack(spacing: 10) {
                TextField("192.168.1.7", text: $manualHost)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(DesignTokens.labelPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )

                Button {
                    let trimmed = manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    HapticEngine.shared.tapMedium()
                    client.connect(to: trimmed)
                    dismiss()
                } label: {
                    Text("Conectar")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .hyGlassProminentButton()
                .tint(.blue)
            }
        }
    }

    private var statusColor: Color {
        if !client.connectionState.isConnected {
            return DesignTokens.statusOffline
        }
        return client.isAwake ? DesignTokens.statusAwake : DesignTokens.statusStandby
    }
}
