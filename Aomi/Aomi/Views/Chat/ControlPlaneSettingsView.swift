import SwiftUI

struct ControlPlaneSettingsView: View {
    var vm: ChatViewModel
    @Environment(AomiAPIClient.self) private var apiClient

    @State private var modelExpanded = true
    @State private var namespaceExpanded = false
    @State private var networkExpanded = false

    private var sortedNetworks: [ChainConfig] {
        ChainConfig.supported.values.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if !vm.availableModels.isEmpty {
                modelSection
            }

            if !vm.availableNamespaces.isEmpty {
                namespaceSection
            }

            networkSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var modelSection: some View {
        Section {
            DisclosureGroup(isExpanded: $modelExpanded) {
                ForEach(vm.availableModels) { model in
                    rowButton(title: model.rig, isSelected: vm.selectedModel == model.rig) {
                        vm.selectedModel = model.rig
                        Task { try? await apiClient.selectModel(rig: model.rig) }
                    }
                }
            } label: {
                Text("Model")
            }
        }
    }

    private var namespaceSection: some View {
        Section {
            DisclosureGroup(isExpanded: $namespaceExpanded) {
                ForEach(vm.availableNamespaces) { ns in
                    rowButton(title: ns.name, isSelected: vm.selectedNamespace == ns.name) {
                        vm.selectedNamespace = ns.name
                    }
                }
            } label: {
                Text("Namespace")
            }
        }
    }

    private var networkSection: some View {
        Section {
            DisclosureGroup(isExpanded: $networkExpanded) {
                ForEach(sortedNetworks, id: \.chainId) { chain in
                    rowButton(title: chain.name, isSelected: vm.selectedNetwork == chain.chainId) {
                        vm.selectedNetwork = chain.chainId
                    }
                }
            } label: {
                Text("Network")
            }
        }
    }

    private func rowButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}
