//
//  EmptyStateView.swift
//  SmartCityExploration
//
//  Created by Mariano Perugini on 17/09/2025.
//

import SwiftUI

// MARK: - Empty State Types
public enum EmptyStateType {
    case readyToSearch
    case searching
    case favorites
    case general
}

// MARK: - Empty State View Component
public struct EmptyStateView: View {

    let type: EmptyStateType

    public init(type: EmptyStateType) {
        self.type = type
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Properties
    private var iconName: String {
        switch type {
        case .searching, .readyToSearch:
            return "magnifyingglass"
        case .favorites:
            return "heart"
        case .general:
            return "building.2"
        }
    }

    private var title: String {
        switch type {
        case .readyToSearch:
            return "Perform a search"
        case .searching:
            return "No Cities Found"
        case .favorites:
            return "No Favorite Cities"
        case .general:
            return "No Cities Available"
        }
    }

    private var message: String {
        switch type {
        case .readyToSearch:
            return "Try typing a city name or searching for a specific location."
        case .searching:
            return "Try adjusting your search terms or check the spelling."
        case .favorites:
            return "Add cities to your favorites by tapping the heart icon."
        case .general:
            return "Pull down to refresh or check your internet connection."
        }
    }
}

// MARK: - Preview
#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            EmptyStateView(type: .readyToSearch)
                .previewDisplayName("Ready to Search")
            EmptyStateView(type: .searching)
                .previewDisplayName("Searching")

            EmptyStateView(type: .favorites)
                .previewDisplayName("Favorites")

            EmptyStateView(type: .general)
                .previewDisplayName("General")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
