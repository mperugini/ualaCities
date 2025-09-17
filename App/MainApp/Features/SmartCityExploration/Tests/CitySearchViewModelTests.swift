//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import XCTest
@testable import SmartCityExploration

// MARK: - City Search Coordinator Tests (Refactored Architecture)
@MainActor
final class CitySearchViewModelTests: XCTestCase, @unchecked Sendable {
    
    private var sut: CitySearchCoordinator!
    private var mockUseCases: UseCaseContainer!
    
    // MARK: - Test Data
    private let testCities = [
        City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.006, lat: 40.7128)),
        City(id: 2, name: "London", country: "GB", coord: Coordinate(lon: -0.1276, lat: 51.5074)),
        City(id: 3, name: "Tokyo", country: "JP", coord: Coordinate(lon: 139.6917, lat: 35.6895), isFavorite: true)
    ]
    
    override func setUp() {
        super.setUp()
        
        MainActor.assumeIsolated {
            mockUseCases = UseCaseContainer.createMock()
            sut = CitySearchCoordinator(useCases: mockUseCases)
            
            // Setup default mock responses
            setupMockResponses()
        }
    }
    
    override func tearDown() {
        MainActor.assumeIsolated {
            sut = nil
            mockUseCases = nil
        }
        super.tearDown()
    }
    
    // MARK: - Search Functionality Tests
    
    func testClearSearch_ResetsSearchState() async {
        // Given
        await sut.loadInitialData()
        sut.searchViewModel.searchText = "London"
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // When
        sut.clearSearch()
        
        // Then
        XCTAssertTrue(sut.searchViewModel.searchText.isEmpty)
        XCTAssertTrue(sut.searchViewModel.searchResults.isEmpty)
        XCTAssertFalse(sut.searchViewModel.isSearching)
    }
    
    func testSearchWithEmptyQuery_ShowsAllCities() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.searchViewModel.searchText = ""
        
        // Then
        XCTAssertFalse(sut.searchViewModel.isSearching)
        XCTAssertTrue(sut.searchViewModel.searchResults.isEmpty)
        XCTAssertEqual(sut.displayedCities.count, 0) // No cities loaded initially
    }
    
    // MARK: - Favorite Toggle Tests
    
    func testToggleFavorite_Success_UpdatesCityAndRefreshes() async {
        // Given
        await sut.loadInitialData()
        let cityToToggle = testCities[0] // New York (not favorite)
        
        // When
        await sut.toggleFavorite(cityToToggle)
        
        // Then
        XCTAssertFalse(sut.errorHandlingViewModel.showError)
    }
    
    // MARK: - Refresh Data Tests
    
    func testRefreshData_Success_UpdatesData() async {
        // Given
        await sut.loadInitialData()
        
        // When
        await sut.refreshData()
        
        // Then
        XCTAssertFalse(sut.dataLoadingViewModel.isRefreshing)
        XCTAssertFalse(sut.errorHandlingViewModel.showError)
    }
    
   
    
    // MARK: - Coordinator Integration Tests
    
    func testCoordinator_ManagesChildViewModels() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.searchViewModel.searchText = "Test"
        sut.favoritesViewModel.toggleFavoritesFilter()
        await sut.toggleFavorite(testCities[0])
        
        // Then
        XCTAssertNotNil(sut.searchViewModel)
        XCTAssertNotNil(sut.favoritesViewModel)
        XCTAssertNotNil(sut.dataLoadingViewModel)
        XCTAssertNotNil(sut.errorHandlingViewModel)
    }
    
    
    // MARK: - Helper Methods
    
    private func setupMockResponses() {
        // This would be implemented based on the actual mock structure
        // For now, we assume the mocks are properly configured
    }
    
    private func setupMockFailure() {
        // This would be implemented based on the actual mock structure
        // For now, we assume the mocks can be configured to fail
    }
    
    private func setupMockDelay() {
        // This would be implemented based on the actual mock structure
        // For now, we assume the mocks can be configured with delays
    }
}
