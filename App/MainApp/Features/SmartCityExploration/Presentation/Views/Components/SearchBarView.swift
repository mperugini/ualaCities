//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import SwiftUI

public struct SearchBarView: View {
    @ObservedObject private var viewModel: SearchViewModel
    
    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search cities...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled(true)
                
                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.clearSearch()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Preview
#if DEBUG
struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarView(viewModel: SearchViewModelFactory.createMock())
            .previewDisplayName("Search Bar")
    }
}
#endif
