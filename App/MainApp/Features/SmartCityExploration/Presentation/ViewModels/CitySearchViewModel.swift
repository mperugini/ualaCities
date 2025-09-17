//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import SwiftUI
@preconcurrency import Combine

// MARK: - City Search View Model (MVVM Pattern + Swift 6 Concurrency)
@MainActor
public final class CitySearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var searchText: String = ""
    @Published public var cities: [City] = []
    @Published public var favorites: [City] = []
    @Published public var isLoading = false
    @Published public var showOnlyFavorites = false
    @Published public var errorMessage: String?
    @Published public var showError = false
    @Published public var dataSourceInfo: DataSourceInfo?
    
    // MARK: - Search State
    @Published public var searchResults: [City] = []
    public var hasSearchResults: Bool { !searchResults.isEmpty }
    public var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var displayedCities: [City] {
        if isSearching {
            return searchResults
        } else if showOnlyFavorites {
            return favorites
        } else {
            return cities
        }
    }
    
    // MARK: - Loading States
    @Published public var isInitialLoading = false
    @Published public var isRefreshing = false
    @Published public var isSearchLoading = false
    
    // MARK: - Dependencies (Dependency Injection)
    private let loadCitiesUseCase: LoadCitiesUseCaseProtocol
    private let searchCitiesUseCase: SearchCitiesUseCaseProtocol
    private let favoriteCitiesUseCase: FavoriteCitiesUseCaseProtocol
    
    // MARK: - Private Properties
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(
        loadCitiesUseCase: LoadCitiesUseCaseProtocol,
        searchCitiesUseCase: SearchCitiesUseCaseProtocol,
        favoriteCitiesUseCase: FavoriteCitiesUseCaseProtocol
    ) {
        self.loadCitiesUseCase = loadCitiesUseCase
        self.searchCitiesUseCase = searchCitiesUseCase
        self.favoriteCitiesUseCase = favoriteCitiesUseCase
        
        setupSearchObservation()
    }
    
    deinit {
        searchTask?.cancel()
    }
    
    // MARK: - Public Methods
    public func loadInitialData() async {
        guard !isInitialLoading else { return }
        
        isInitialLoading = true
        isLoading = true
        
        await performDataLoad()
        
        isInitialLoading = false
        isLoading = false
    }
    
    public func refreshData() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        let result = await loadCitiesUseCase.forceRefresh()
        
        switch result {
        case .success(let info):
            dataSourceInfo = info
            await loadFavorites()
            clearError()
            
        case .failure(let error):
            showError(error.localizedDescription)
        }
        
        isRefreshing = false
    }
    
    public func toggleFavorite(_ city: City) async {
        let result = await favoriteCitiesUseCase.toggleFavorite(city)
        
        switch result {
        case .success(let updatedCity):
            updateCityInLists(updatedCity)
            await loadFavorites() // Refresh favorites list
            await refreshDataSourceInfo() // Update favorites count in UI
            clearError()
            
        case .failure(let error):
            if let favError = error as? FavoritesUseCaseError {
                showError(favError.userFriendlyMessage)
            } else {
                showError(error.localizedDescription)
            }
        }
    }
    
    public func performSearch() async {
        // Cancel any existing search
        searchTask?.cancel()
        
        searchTask = Task { @MainActor in
            let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedQuery.isEmpty {
                searchResults = []
                return
            }
            
            isSearchLoading = true
            
            let filter = SearchFilter(
                query: trimmedQuery,
                showOnlyFavorites: showOnlyFavorites,
                limit: SearchConstants.defaultResultLimit
            )
            
            let result = await searchCitiesUseCase.execute(with: filter)
            
            switch result {
            case .success(let searchResult):
                if !Task.isCancelled {
                    searchResults = searchResult.cities
                    clearError()
                }
                
            case .failure(let error):
                if !Task.isCancelled {
                    searchResults = []
                    if let searchError = error as? SearchUseCaseError {
                        showError(searchError.userFriendlyMessage)
                    } else {
                        showError(error.localizedDescription)
                    }
                }
            }
            
            isSearchLoading = false
        }
    }
    
    public func clearSearch() {
        searchText = ""
        searchResults = []
        searchTask?.cancel()
    }
    
    public func toggleFavoritesFilter() {
        showOnlyFavorites.toggle()
        
        // Trigger search if there's a query
        if isSearching {
            Task {
                await performSearch()
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupSearchObservation() {
        // Observe search text changes with proper debouncing
        $searchText
            .debounce(for: .seconds(SearchConstants.searchDebounceTime), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                Task { @MainActor in
                    await self?.performSearch()
                }
            }
            .store(in: &cancellables)
    }
    
    private func performDataLoad() async {
        let result = await loadCitiesUseCase.execute()
        
        switch result {
        case .success(let info):
            dataSourceInfo = info
            await loadFavorites()
            clearError()
            
        case .failure(let error):
            if let loadError = error as? LoadCitiesUseCaseError {
                showError(loadError.userFriendlyMessage)
            } else {
                showError(error.localizedDescription)
            }
        }
    }
    
    private func loadFavorites() async {
        let result = await favoriteCitiesUseCase.getFavorites()
        
        switch result {
        case .success(let favoriteCities):
            favorites = favoriteCities
            
        case .failure:
            // Non critical, just log it
            print("Failed to load favorites")
        }
    }
    
    private func updateCityInLists(_ updatedCity: City) {
        // Update in main cities list
        if let index = cities.firstIndex(where: { $0.id == updatedCity.id }) {
            cities[index] = updatedCity
        }
        
        // Update in search results
        if let index = searchResults.firstIndex(where: { $0.id == updatedCity.id }) {
            searchResults[index] = updatedCity
        }
    }
    
    private func refreshDataSourceInfo() async {
        let result = await loadCitiesUseCase.getDataInfo()
        
        switch result {
        case .success(let info):
            dataSourceInfo = info
        case .failure:
            // Keep current info if refresh fail
            break
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func clearError() {
        errorMessage = nil
        showError = false
    }
}


// MARK: - Factory for View Model Creation
public final class CitySearchViewModelFactory {
    
    @MainActor
    public static func create() -> CitySearchViewModel {
        let repository = CityRepositoryFactory.create()
        
        let loadCitiesUseCase = LoadCitiesUseCase(repository: repository)
        let searchCitiesUseCase = SearchCitiesUseCase(repository: repository)
        let favoriteCitiesUseCase = FavoriteCitiesUseCase(repository: repository)
        
        return CitySearchViewModel(
            loadCitiesUseCase: loadCitiesUseCase,
            searchCitiesUseCase: searchCitiesUseCase,
            favoriteCitiesUseCase: favoriteCitiesUseCase
        )
    }
    
    #if DEBUG
    @MainActor
    public static func createMock() -> CitySearchViewModel {
        let repository = CityRepositoryFactory.createMock()
        
        let loadCitiesUseCase = LoadCitiesUseCase(repository: repository)
        let searchCitiesUseCase = SearchCitiesUseCase(repository: repository)
        let favoriteCitiesUseCase = FavoriteCitiesUseCase(repository: repository)
        
        return CitySearchViewModel(
            loadCitiesUseCase: loadCitiesUseCase,
            searchCitiesUseCase: searchCitiesUseCase,
            favoriteCitiesUseCase: favoriteCitiesUseCase
        )
    }
    #endif
}
