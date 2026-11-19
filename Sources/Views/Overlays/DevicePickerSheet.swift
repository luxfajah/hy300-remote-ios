import CoreBluetooth
import SwiftUI

/// Device picker and live connection diagnostics sheet:
/// Displays active Wi-Fi TCP or Bluetooth LE GATT status, RTT latency, daemon state,
/// live Bluetooth LE scan (`A300`), Bonjour/UDP discovered Wi-Fi projectors, and manual IP entry.
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
                        bluetoothSection
                        wifiDiscoveredSection
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
            client.bluetooth.startScan()
        }
        .onDisappear {
            client.bluetooth.stopScan()
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
                    HStack(spacing: 6) {
                        Text(client.deviceName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignTokens.labelPrimary)

                        Label(client.activeTransport.label, systemImage: client.activeTransport.systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(
                                client.activeTransport == .bluetooth
                                    ? Color(red: 0.38, green: 0.68, blue: 1.0)
                                    : DesignTokens.labelSecondary
                            )
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(
                                        client.activeTransport == .bluetooth
                                            ? Color.blue.opacity(0.18)
                                            : Color.white.opacity(0.08)
                                    )
                            )
                    }

                    Text(
                        client.activeTransport == .bluetooth
                            ? "Bluetooth LE • Direto (GATT A300)"
                            : "\(client.host):\(client.tcpPort)"
                    )
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
                    label: client.activeTransport == .bluetooth ? "Latência BLE" : "Latência TCP",
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

    // MARK: - Bluetooth LE Direct Section

    private var bluetoothSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BLUETOOTH (DIRETO)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.labelTertiary)

                Spacer()

                Button {
                    HapticEngine.shared.selection()
                    if client.bluetooth.isScanning {
                        client.bluetooth.stopScan()
                    } else {
                        client.bluetooth.startScan()
                    }
                } label: {
                    HStack(spacing: 5) {
                        if client.bluetooth.isScanning {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(client.bluetooth.isScanning ? "Buscando…" : "Escanear")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.38, green: 0.68, blue: 1.0))
                }
                .buttonStyle(.plain)
            }

            if client.bluetooth.bluetoothState != .poweredOn && client.bluetooth.discoveredPeripherals.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: bluetoothStatusIcon)
                        .foregroundStyle(bluetoothStatusColor)
                    Text(client.bluetooth.statusDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.labelSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .hyGlassRounded(cornerRadius: 18, interactive: false)
            } else if client.bluetooth.discoveredPeripherals.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(Color(red: 0.38, green: 0.68, blue: 1.0).opacity(0.75))
                    Text(client.bluetooth.isScanning
                         ? "Procurando HY300Pro próximo via Bluetooth LE…"
                         : "Nenhum projetor Bluetooth encontrado. Toque em Escanear.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.labelSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .hyGlassRounded(cornerRadius: 18, interactive: false)
            } else {
                VStack(spacing: 8) {
                    ForEach(client.bluetooth.discoveredPeripherals) { device in
                        let isSelected = client.activeTransport == .bluetooth
                            && client.bluetooth.connectedPeripheralID == device.id
                            && client.connectionState.isConnected

                        Button {
                            HapticEngine.shared.tapMedium()
                            client.connectBluetooth(peripheralID: device.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(
                                        isSelected
                                            ? DesignTokens.statusAwake
                                            : Color(red: 0.38, green: 0.68, blue: 1.0)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DesignTokens.labelPrimary)
                                    Text("Bluetooth LE • \(rssiLabel(device.rssi)) (\(device.rssi) dBm)")
                                        .font(.system(size: 12).monospacedDigit())
                                        .foregroundStyle(DesignTokens.labelSecondary)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DesignTokens.statusAwake)
                                } else {
                                    Text("Conectar")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.38, green: 0.68, blue: 1.0))
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

    private var bluetoothStatusIcon: String {
        switch client.bluetooth.bluetoothState {
        case .poweredOff: return "antenna.radiowaves.left.and.right.slash"
        case .unauthorized: return "lock.shield"
        default: return "dot.radiowaves.left.and.right"
        }
    }

    private var bluetoothStatusColor: Color {
        switch client.bluetooth.bluetoothState {
        case .poweredOff, .unauthorized: return DesignTokens.statusStandby
        default: return DesignTokens.labelTertiary
        }
    }

    private func rssiLabel(_ rssi: Int) -> String {
        if rssi >= -60 { return "Sinal Forte" }
        if rssi >= -75 { return "Sinal Bom" }
        return "Sinal Fraco"
    }

    // MARK: - Discovered Wi-Fi Projectors (Bonjour + UDP 8092)

    private var wifiDiscoveredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("REDE WI-FI (BONJOUR / UDP)")
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
                         ? "Procurando projetores HY300 na rede Wi-Fi…"
                         : "Nenhum projetor descoberto automaticamente no Wi-Fi.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.labelSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .hyGlassRounded(cornerRadius: 18, interactive: false)
            } else {
                VStack(spacing: 8) {
                    ForEach(discovery.discovered) { projector in
                        let isSelected = client.activeTransport == .wifi && projector.host == client.host
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
