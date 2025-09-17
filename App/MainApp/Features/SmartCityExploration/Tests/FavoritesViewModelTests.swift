//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import XCTest
@testable import SmartCityExploration

// MARK: - Favorites ViewModel Tests
@MainActor
final class FavoritesViewModelTests: XCTestCase, @unchecked Sendable {
    
    private var sut: FavoritesViewModel!
    private var mockFavoriteUseCase: MockFavoriteCitiesUseCase!
    
    // MARK: - Test Data
    private let testCities = [
        City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.006, lat: 40.7128)),
        City(id: 2, name: "London", country: "GB", coord: Coordinate(lon: -0.1276, lat: 51.5074)),
        City(id: 3, name: "Tokyo", country: "JP", coord: Coordinate(lon: 139.6917, lat: 35.6895), isFavorite: true)
    ]
    
    override func setUp() {
        super.setUp()
        
        MainActor.assumeIsolated {
            mockFavoriteUseCase = MockFavoriteCitiesUseCase()
            sut = FavoritesViewModel(favoriteUseCase: mockFavoriteUseCase)
            mockFavoriteUseCase.mockFavorites = [testCities[2]] // Tokyo
        }
    }
    
    override func tearDown() {
        MainActor.assumeIsolated {
            sut = nil
            mockFavoriteUseCase = nil
        }
        super.tearDown()
    }
    
    // MARK: - Load Favorites Tests
    
    func testLoadFavorites_Success_UpdatesFavoritesList() async {
        // Given
        var favoritesChanged = false
        sut.onFavoritesChanged = {
            favoritesChanged = true
        }
        
        // When
        await sut.loadFavorites()
        
        // Then
        XCTAssertEqual(sut.favorites.count, 1)
        XCTAssertEqual(sut.favorites.first?.name, "Tokyo")
        XCTAssertTrue(favoritesChanged)
    }
    
    func testLoadFavorites_Failure_TriggersErrorCallback() async {
        // Given
        mockFavoriteUseCase.shouldFail = true
        mockFavoriteUseCase.mockError = FavoritesUseCaseError.operationFailed(NSError(domain: "Test", code: 1))
        
        var errorOccurred = false
        sut.onErrorOccurred = { _ in
            errorOccurred = true
        }
        
        // When
        await sut.loadFavorites()
        
        // Then
        XCTAssertTrue(errorOccurred)
        XCTAssertTrue(sut.favorites.isEmpty)
    }
    
   
    
    // MARK: - Favorites Filter Tests
    
    func testToggleFavoritesFilter_UpdatesShowOnlyFavorites() {
        // Given
        var favoritesChanged = false
        sut.onFavoritesChanged = {
            favoritesChanged = true
        }
        
        // When
        sut.toggleFavoritesFilter()
        
        // Then
        XCTAssertTrue(sut.showOnlyFavorites)
        XCTAssertTrue(favoritesChanged)
    }
    
    func testToggleFavoritesFilter_Twice_ReturnsToOriginalState() {
        // Given
        let originalState = sut.showOnlyFavorites
        
        // When
        sut.toggleFavoritesFilter()
        sut.toggleFavoritesFilter()
        
        // Then
        XCTAssertEqual(sut.showOnlyFavorites, originalState)
    }
    
    // MARK: - Remove Favorites Tests
    
    
    func testRemoveFromFavorites_Success_RemovesCityFromList() async {
        // Given
        let cityToRemove = testCities[2] // Tokyo (already favorite)
        var updatedCity = cityToRemove
        updatedCity.isFavorite = false
        mockFavoriteUseCase.mockUpdatedCity = updatedCity
        
        var favoritesChanged = false
        sut.onFavoritesChanged = {
            favoritesChanged = true
        }
        
        // When
        await sut.removeFromFavorites(cityToRemove)
        
        // Then
        XCTAssertTrue(favoritesChanged)
        XCTAssertEqual(sut.favorites.count, 0)
        XCTAssertFalse(sut.favorites.contains { $0.id == cityToRemove.id })
    }
}

// MARK: - Mock Favorite Use Case
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
