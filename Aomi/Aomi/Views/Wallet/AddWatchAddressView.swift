import SwiftUI

struct AddWatchAddressView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var label = ""
    @State private var chain = "EVM"
    @State private var resolvedAddress: String?
    @State private var isResolving = false
    @State private var resolveError: String?
    let onAdd: (String, String, String?) -> Void

    private let chains = ["EVM", "Solana", "Cosmos"]

    private var isENS: Bool {
        chain == "EVM" && ENSResolver.looksLikeENS(input)
    }

    private var effectiveAddress: String {
        resolvedAddress ?? input
    }

    private var canAdd: Bool {
        if isENS {
            return resolvedAddress != nil && !isResolving
        }
        return !input.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Address or ENS name", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))

                    if isResolving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Resolving ENS name...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let resolved = resolvedAddress {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resolved Address")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(resolved)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }

                    if let error = resolveError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextField("Label (optional)", text: $label)

                    Picker("Chain", selection: $chain) {
                        ForEach(chains, id: \.self) { Text($0) }
                    }
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
                        let effectiveLabel = label.isEmpty ? (isENS ? input : nil) : label
                        HapticEngine.success()
                        onAdd(effectiveAddress, chain, effectiveLabel)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
            .task(id: "\(input)|\(chain)") {
                resolvedAddress = nil
                resolveError = nil

                guard isENS else { return }

                // Debounce
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                isResolving = true
                defer { isResolving = false }

                do {
                    resolvedAddress = try await ENSResolver.shared.resolve(input)
                } catch {
                    guard !Task.isCancelled else { return }
                    resolveError = error.localizedDescription
                }
            }
        }
    }
}
