//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import SwiftUI

@MainActor
public final class CitySearchCoordinator: ObservableObject {
    
    // MARK: - Child ViewModels (Composition)
    @Published public var searchViewModel: SearchViewModel
    @Published public var favoritesViewModel: FavoritesViewModel
    @Published public var dataLoadingViewModel: DataLoadingViewModel
    @Published public var errorHandlingViewModel: ErrorHandlingViewModel
    
    // MARK: - Published State (Derived)
    @Published public var displayedCities: [City] = []
    @Published public var isSearching: Bool = false
    
    // MARK: - Dependencies
    private let useCases: UseCaseContainer
    
    // MARK: - Initialization
    public init(useCases: UseCaseContainer = UseCaseContainer()) {
        self.useCases = useCases
        
        self.searchViewModel = SearchViewModel(searchUseCase: useCases.searchUseCase)
        self.favoritesViewModel = FavoritesViewModel(favoriteUseCase: useCases.favoriteUseCase)
        self.dataLoadingViewModel = DataLoadingViewModel(loadUseCase: useCases.loadUseCase)
        self.errorHandlingViewModel = ErrorHandlingViewModel()
        
        setupCoordination()
    }
    
    // MARK: - Coordination Logic
    private func setupCoordination() {

        searchViewModel.onSearchResultsChanged = { [weak self] results in
            self?.updateDisplayedCities()
        }
        
        searchViewModel.onErrorOccurred = { [weak self] error in
            self?.handleError(error)
        }
        
        favoritesViewModel.onFavoritesChanged = { [weak self] in
            self?.updateDisplayedCities()
        }
        
        favoritesViewModel.onErrorOccurred = { [weak self] error in
            self?.handleError(error)
        }
        
        dataLoadingViewModel.onDataLoaded = { [weak self] in
            Task { @MainActor in
                await self?.loadFavorites()
            }
        }
        
        dataLoadingViewModel.onErrorOccurred = { [weak self] error in
            self?.handleError(error)
        }
        
        errorHandlingViewModel.onErrorOccurred = { [weak self] error in
            self?.handleError(error)
        }
    }
    
    // MARK: - Public Methods
    public func loadInitialData() async {
        await dataLoadingViewModel.loadInitialData()
    }
    
    public func refreshData() async {
        await dataLoadingViewModel.refreshData()
    }
    
    public func toggleFavorite(_ city: City) async {
        await favoritesViewModel.toggleFavorite(city)
    }
    
    public func toggleFavoritesFilter() {
        favoritesViewModel.toggleFavoritesFilter()
    }
    
    public func clearSearch() {
        searchViewModel.clearSearch()
    }
    
    // MARK: - Private Methods
    private func updateDisplayedCities() {
        if searchViewModel.isSearching {
            displayedCities = searchViewModel.searchResults
        } else if favoritesViewModel.showOnlyFavorites {
            displayedCities = favoritesViewModel.favorites
        } else {
            displayedCities = dataLoadingViewModel.cities
        }
        
        isSearching = searchViewModel.isSearching
    }
    
    private func loadFavorites() async {
        await favoritesViewModel.loadFavorites()
    }
    
    private func handleError(_ error: Error) {
        errorHandlingViewModel.showError(error)
    }
}

// MARK: - Factory City Search Coordinator
public final class CitySearchCoordinatorFactory {
    
    @MainActor
    public static func create() -> CitySearchCoordinator {
        let useCases = UseCaseContainerFactory.create()
        return CitySearchCoordinator(useCases: useCases)
    }
    
    #if DEBUG
    @MainActor
    public static func createMock() -> CitySearchCoordinator {
        let useCases = UseCaseContainerFactory.createMock()
        return CitySearchCoordinator(useCases: useCases)
    }
    #endif
}
