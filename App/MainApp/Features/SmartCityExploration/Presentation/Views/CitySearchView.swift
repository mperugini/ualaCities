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
    @State private var cityToShowDetail: City?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Layout Configuration
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    private var emptyStateType: EmptyStateType {
        if viewModel.isSearching {
            return .searching
        } else if viewModel.showOnlyFavorites {
            return .favorites
        } else if let totalCities = viewModel.dataSourceInfo?.totalCities, totalCities > 0 {
            return .readyToSearch
        } else {
            return .general
        }
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
            .navigationBarTitleDisplayMode(.automatic)
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
            .sheet(item: $cityToShowDetail) { city in
                CityDetailView(city: city)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: selectedCity) { _, newCity in
                if let city = newCity, isCompact {
                    cityToShowDetail = city
                }
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
                        cityToShowDetail = city
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
                EmptyStateView(type: emptyStateType)
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
