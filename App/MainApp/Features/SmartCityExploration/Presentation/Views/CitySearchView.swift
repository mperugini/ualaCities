//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import SwiftUI
import MapKit

// MARK: - Main City Search View (Challenge Requirements Implementation)
public struct CitySearchView: View {
    
    @StateObject private var viewModel = CitySearchViewModelFactory.create()
    @State private var selectedCity: City?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Layout Configuration
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if isCompact {
                    cityListView
                } else {
                    combinedView
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshData()
            }
            .task {
                await viewModel.loadInitialData()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(item: $selectedCity) { city in
                CityDetailView(city: city)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Portrait Layout (List Only)
    private var cityListView: some View {
        VStack(spacing: 0) {
            searchBar
            
            if viewModel.isInitialLoading {
                initialLoadingView
            } else {
                cityList
            }
        }
    }
    
    // MARK: - Landscape Layout (List + Map)
    private var combinedView: some View {
        HStack(spacing: 0) {
            // Left side: Search and List
            VStack(spacing: 0) {
                searchBar
                
                if viewModel.isInitialLoading {
                    initialLoadingView
                } else {
                    cityList
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Right side: Map
            mapView
                .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
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
            
            // Filter Toggle
            HStack {
                Toggle(isOn: $viewModel.showOnlyFavorites) {
                    Label("Show only favorites", systemImage: "heart.fill")
                        .font(.subheadline)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                if let info = viewModel.dataSourceInfo {
                    Text("\(info.totalCities) cities • \(info.favoritesCount) favorites")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemBackground))
        .onChange(of: viewModel.showOnlyFavorites) { _, _ in
            Task {
                await viewModel.performSearch()
            }
        }
    }
    
    // MARK: - City List
    private var cityList: some View {
        List {
            ForEach(viewModel.displayedCities) { city in
                CityRowView(
                    city: city,
                    onFavoriteToggle: {
                        Task {
                            await viewModel.toggleFavorite(city)
                        }
                    },
                    onCityTap: {
                        if isCompact {
                            // In portrait, navigate to map
                            navigateToMap(city)
                        } else {
                            // In landscape, just select the city
                            selectedCity = city
                        }
                    },
                    onInfoTap: {
                        selectedCity = city
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            
            if viewModel.isSearchLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            }
            
            if viewModel.displayedCities.isEmpty && !viewModel.isSearchLoading {
                emptyStateView
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshData()
        }
    }
    
    // MARK: - Map View
    private var mapView: some View {
        CityMapView(
            cities: viewModel.displayedCities,
            selectedCity: selectedCity,
            onCitySelected: { city in
                selectedCity = city
            }
        )
    }
    
    // MARK: - Loading States
    private var initialLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            
            Text("Loading cities...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if viewModel.isRefreshing {
                Text("Downloading latest data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.isSearching ? "magnifyingglass" : "building.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyStateTitle: String {
        if viewModel.isSearching {
            return "No Cities Found"
        } else if viewModel.showOnlyFavorites {
            return "No Favorite Cities"
        } else {
            return "No Cities Available"
        }
    }
    
    private var emptyStateMessage: String {
        if viewModel.isSearching {
            return "Try adjusting your search terms or check the spelling."
        } else if viewModel.showOnlyFavorites {
            return "Add cities to your favorites by tapping the heart icon."
        } else {
            return "Pull down to refresh or check your internet connection."
        }
    }
    
    // MARK: - Navigation
    private func navigateToMap(_ city: City) {
        // In portrait mode, show the city detail view
        selectedCity = city
    }
}

// MARK: - City Row View
private struct CityRowView: View {
    let city: City
    let onFavoriteToggle: () -> Void
    let onCityTap: () -> Void
    let onInfoTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // City and country name (title)
                Text(city.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Coordinates (subtitle)
                Text(city.coord.displayString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Info button
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                // Favorite toggle
                Button(action: onFavoriteToggle) {
                    Image(systemName: city.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(city.isFavorite ? .red : .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCityTap()
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CitySearchView_Previews: PreviewProvider {
    static var previews: some View {
        CitySearchView()
            .previewDisplayName("Portrait")
        
        CitySearchView()
            .previewInterfaceOrientation(.landscapeLeft)
            .previewDisplayName("Landscape")
    }
}
#endif
