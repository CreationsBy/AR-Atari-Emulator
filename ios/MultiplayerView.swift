import SwiftUI

struct MultiplayerView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var enteredCode = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Two iPhones · one Wi-Fi network", systemImage: "wifi")
                    Text("Player 1 runs the cartridge. Player 2 joins without a ROM and sees the same world through their own camera.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if model.isHosting {
                    Section("Your private room") {
                        Text(RoomCode.display(model.network.code))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .textSelection(.enabled).frame(maxWidth: .infinity).padding(.vertical, 12)
                        Text("Give this code to Player 2. They should open Local multiplayer on their phone and enter it.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Label(model.network.status, systemImage: model.network.connected ? "person.2.fill" : "person.badge.plus")
                        if !model.spatialStatus.isEmpty { Text(model.spatialStatus).font(.footnote) }
                        Button("Share table again") { model.requestSharedMap(); dismiss() }.disabled(!model.network.connected)
                        Button("Close room", role: .destructive) { model.leaveMultiplayer() }
                    }
                } else if model.isGuest {
                    Section("Player 2") {
                        Label(model.network.status, systemImage: model.network.connected ? "person.2.fill" : "wifi")
                        if !model.spatialStatus.isEmpty { Text(model.spatialStatus).font(.footnote) }
                        if model.network.connected {
                            Button("Align to the host's table again") { model.requestSharedMap(); dismiss() }
                            Button("Return to game") { dismiss() }
                        }
                        Button(model.network.connected ? "Leave room" : "Cancel / try another code", role: .destructive) { model.leaveMultiplayer() }
                    }
                } else {
                    Section("Player 1 · host") {
                        Button { model.hostMultiplayer() } label: { Label("Host current cartridge", systemImage: "plus.circle.fill") }
                            .disabled(model.activeGame == nil || model.loading || model.settings.view != "Free AR")
                        Text(model.activeGame == nil ? "Load a cartridge first, then open Local multiplayer from the game menu." : "Use Free AR, place the diorama and scan around the table. The host controls the shared size and position.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Player 2 · join") {
                        TextField("Room code, e.g. ABCD-EFGH", text: $enteredCode)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .font(.system(.title3, design: .monospaced))
                            .onChange(of: enteredCode) { enteredCode = String(RoomCode.normalize($0).prefix(8)) }
                        Button { model.joinMultiplayer(enteredCode) } label: { Label("Join as Player 2", systemImage: "person.crop.circle.badge.plus") }
                            .disabled(!RoomCode.valid(RoomCode.normalize(enteredCode)))
                        Text("No cartridge is needed on this phone. After joining, point your camera at the same table the host scanned.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if model.network.status != "Not connected" { Text(model.network.status).font(.footnote).foregroundStyle(.orange) }
                    }
                }
                Section("Connection help") {
                    Text("Allow Local Network and Camera access on both phones. Stay in the app while playing. Guest or public Wi-Fi can isolate devices; use a network that lets the phones communicate.")
                    Text("Select the cartridge's two-player game variation with the host's SELECT / RESET controls. Multiplayer does not add a second player to games that only support one.")
                }.font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Local multiplayer").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
