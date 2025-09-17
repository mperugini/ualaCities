//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import SwiftUI

@MainActor
public final class FavoritesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var favorites: [City] = []
    @Published public var showOnlyFavorites: Bool = false
    
    // MARK: - Dependencies
    private let favoriteUseCase: FavoriteCitiesUseCaseProtocol
    
    // MARK: - Callbacks
    public var onFavoritesChanged: (() -> Void)?
    public var onErrorOccurred: ((Error) -> Void)?
    
    // MARK: - Initialization
    public init(favoriteUseCase: FavoriteCitiesUseCaseProtocol) {
        self.favoriteUseCase = favoriteUseCase
    }
    
    // MARK: - Public Methods
    public func loadFavorites() async {
        let result = await favoriteUseCase.getFavorites()
        
        switch result {
        case .success(let favoriteCities):
            favorites = favoriteCities
            onFavoritesChanged?()
            
        case .failure(let error):
            onErrorOccurred?(error)
        }
    }
    
    public func toggleFavorite(_ city: City) async {
        let result = await favoriteUseCase.toggleFavorite(city)
        
        switch result {
        case .success(let updatedCity):
            updateCityInFavorites(updatedCity)
            onFavoritesChanged?()
            
        case .failure(let error):
            onErrorOccurred?(error)
        }
    }
    
    public func toggleFavoritesFilter() {
        showOnlyFavorites.toggle()
        onFavoritesChanged?()
    }
    
    public func addToFavorites(_ city: City) async {
        let result = await favoriteUseCase.addToFavorites(city)
        
        switch result {
        case .success(let updatedCity):
            updateCityInFavorites(updatedCity)
            onFavoritesChanged?()
            
        case .failure(let error):
            onErrorOccurred?(error)
        }
    }
    
    public func removeFromFavorites(_ city: City) async {
        let result = await favoriteUseCase.removeFromFavorites(city)
        
        switch result {
        case .success(let updatedCity):
            updateCityInFavorites(updatedCity)
            onFavoritesChanged?()
            
        case .failure(let error):
            onErrorOccurred?(error)
        }
    }
    
    // MARK: - Private Methods
    private func updateCityInFavorites(_ updatedCity: City) {
        if let index = favorites.firstIndex(where: { $0.id == updatedCity.id }) {
            if updatedCity.isFavorite {
                favorites[index] = updatedCity
            } else {
                favorites.remove(at: index)
            }
        } else if updatedCity.isFavorite {
            favorites.append(updatedCity)
        }
    }
}

// MARK: - Factory for Favorites ViewModel
public final class FavoritesViewModelFactory {
    
    @MainActor
    public static func create(favoriteUseCase: FavoriteCitiesUseCaseProtocol) -> FavoritesViewModel {
        return FavoritesViewModel(favoriteUseCase: favoriteUseCase)
    }
    
    #if DEBUG
    @MainActor
    public static func createMock() -> FavoritesViewModel {
        let mockUseCase = MockFavoriteCitiesUseCase()
        return FavoritesViewModel(favoriteUseCase: mockUseCase)
    }
    #endif
}

// MARK: - Mock Favorite Use Case for Testing
#if DEBUG
@MainActor
private final class MockFavoriteCitiesUseCase: FavoriteCitiesUseCaseProtocol, @unchecked Sendable {
    
    var mockFavorites: [City] = []
    var mockUpdatedCity: City?
    var shouldFail = false
    var shouldFailToggle = false
    var mockError: Error = FavoritesUseCaseError.operationFailed(NSError(domain: "Test", code: 1))
    
    func getFavorites() async -> Result<[City], Error> {
        if shouldFail {
            return .failure(mockError)
        }
        return .success(mockFavorites)
    }
    
    func toggleFavorite(_ city: City) async -> Result<City, Error> {
        if shouldFailToggle {
            return .failure(mockError)
        }
        return .success(mockUpdatedCity ?? city)
    }
    
    func addToFavorites(_ city: City) async -> Result<City, Error> {
        if shouldFail {
            return .failure(mockError)
        }
        return .success(mockUpdatedCity ?? city)
    }
    
    func removeFromFavorites(_ city: City) async -> Result<City, Error> {
        if shouldFail {
            return .failure(mockError)
        }
        return .success(mockUpdatedCity ?? city)
    }
    
    func isFavorite(_ city: City) async -> Result<Bool, Error> {
        .success(city.isFavorite)
    }
    
    func getFavoritesCount() async -> Result<Int, Error> {
        .success(mockFavorites.count)
    }
    
    func searchFavorites(with query: String) async -> Result<[City], Error> {
        let filtered = mockFavorites.filter { $0.matchesPrefix(query, searchInCountry: true) }
        return .success(filtered)
    }
}
#endif
