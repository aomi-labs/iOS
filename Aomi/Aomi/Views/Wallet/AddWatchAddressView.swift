import SwiftUI

struct AddWatchAddressView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var label = ""
    @State private var chain = "EVM"
    let onAdd: (String, String, String?) -> Void

    private let chains = ["EVM", "Solana", "Cosmos"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Wallet Address", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))

                TextField("Label (optional)", text: $label)

                Picker("Chain", selection: $chain) {
                    ForEach(chains, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("Add Watch Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        HapticEngine.success()
                        onAdd(address, chain, label.isEmpty ? nil : label)
                        dismiss()
                    }
                    .disabled(address.isEmpty)
                }
            }
        }
    }
}
