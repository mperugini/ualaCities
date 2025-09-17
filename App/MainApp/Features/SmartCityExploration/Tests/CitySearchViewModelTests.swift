//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import XCTest
@testable import SmartCityExploration

// MARK: - City Search View Model Tests
@MainActor
final class CitySearchViewModelTests: XCTestCase, @unchecked Sendable {
    
    private var sut: CitySearchViewModel!
    private var mockLoadUseCase: MockLoadCitiesUseCase!
    private var mockSearchUseCase: MockSearchCitiesUseCase!
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
            mockLoadUseCase = MockLoadCitiesUseCase()
            mockSearchUseCase = MockSearchCitiesUseCase()
            mockFavoriteUseCase = MockFavoriteCitiesUseCase()
            
            sut = CitySearchViewModel(
                loadCitiesUseCase: mockLoadUseCase,
                searchCitiesUseCase: mockSearchUseCase,
                favoriteCitiesUseCase: mockFavoriteUseCase
            )
            
            // Setup default mock responses
            mockLoadUseCase.mockDataInfo = DataSourceInfo(
                totalCities: testCities.count,
                favoritesCount: 1,
                lastUpdated: Date(),
                dataVersion: "1.0"
            )
            mockSearchUseCase.mockCities = testCities
            mockFavoriteUseCase.mockFavorites = [testCities[2]] // Tokyo
        }
    }
    
    override func tearDown() {
        MainActor.assumeIsolated {
            sut = nil
            mockLoadUseCase = nil
            mockSearchUseCase = nil
            mockFavoriteUseCase = nil
        }
        super.tearDown()
    }
    
    // MARK: - Initial Loading Tests
    
    func testLoadInitialData_Success_UpdatesDataSourceInfo() async {
        // When
        await sut.loadInitialData()
        
        // Then
        XCTAssertFalse(sut.isInitialLoading)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.dataSourceInfo)
        XCTAssertEqual(sut.dataSourceInfo?.totalCities, testCities.count)
        XCTAssertEqual(sut.favorites.count, 1)
        XCTAssertFalse(sut.showError)
    }
    
    func testLoadInitialData_Failure_ShowsError() async {
        // Given
        mockLoadUseCase.shouldFail = true
        mockLoadUseCase.mockError = LoadCitiesUseCaseError.downloadFailed(
            underlying: NSError(domain: "Test", code: 1)
        )
        
        // When
        await sut.loadInitialData()
        
        // Then
        XCTAssertFalse(sut.isInitialLoading)
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(sut.showError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testLoadInitialData_PreventsMultipleSimultaneousCalls() async {
        // Given
        mockLoadUseCase.delay = 0.1
        
        // When
        let task1 = Task { await sut.loadInitialData() }
        let task2 = Task { await sut.loadInitialData() }
        
        _ = await task1.value
        _ = await task2.value
        
        // Then
        XCTAssertEqual(mockLoadUseCase.executeCallCount, 1)
    }
    
    // MARK: - Search Functionality Tests
    
    func testSearchText_UpdatesSearchResults() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.searchText = "New"
        try? await Task.sleep(nanoseconds: 400_000_000) // Wait for debounce
        
        // Then
        XCTAssertTrue(sut.isSearching)
        XCTAssertEqual(sut.searchResults.count, 1)
        XCTAssertEqual(sut.searchResults.first?.name, "New York")
        XCTAssertEqual(sut.displayedCities.count, 1)
    }
    
    func testClearSearch_ResetsSearchState() async {
        // Given
        await sut.loadInitialData()
        sut.searchText = "London"
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // When
        sut.clearSearch()
        
        // Then
        XCTAssertTrue(sut.searchText.isEmpty)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertFalse(sut.isSearching)
    }
    
    func testSearchWithEmptyQuery_ShowsAllCities() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.searchText = ""
        
        // Then
        XCTAssertFalse(sut.isSearching)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertEqual(sut.displayedCities.count, 0) // No cities loaded initially
    }
    
    // MARK: - Favorites Filter Tests
    
    func testToggleFavoritesFilter_UpdatesDisplayedCities() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.toggleFavoritesFilter()
        
        // Then
        XCTAssertTrue(sut.showOnlyFavorites)
        XCTAssertEqual(sut.displayedCities.count, 1)
        XCTAssertEqual(sut.displayedCities.first?.name, "Tokyo")
    }
    
    func testFavoritesFilterWithSearch_CombinesFilters() async {
        // Given
        await sut.loadInitialData()
        mockSearchUseCase.mockSearchResult = SearchResult(
            cities: [testCities[2]], // Tokyo (favorite)
            totalCount: 1,
            query: "Tokyo",
            searchTime: 0.001
        )
        
        // When
        sut.showOnlyFavorites = true
        sut.searchText = "Tokyo"
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertTrue(sut.showOnlyFavorites)
        XCTAssertTrue(sut.isSearching)
        XCTAssertEqual(sut.displayedCities.count, 1)
        XCTAssertEqual(sut.displayedCities.first?.name, "Tokyo")
        XCTAssertTrue(sut.displayedCities.first?.isFavorite == true)
    }
    
    // MARK: - Favorite Toggle Tests
    
    func testToggleFavorite_Success_UpdatesCityAndRefreshes() async {
        // Given
        await sut.loadInitialData()
        let cityToToggle = testCities[0] // New York (not favorite)
        var updatedCity = cityToToggle
        updatedCity.isFavorite = true
        mockFavoriteUseCase.mockUpdatedCity = updatedCity
        
        // When
        await sut.toggleFavorite(cityToToggle)
        
        // Then
        XCTAssertFalse(sut.showError)
        XCTAssertEqual(mockFavoriteUseCase.toggleFavoriteCallCount, 1)
        XCTAssertEqual(mockFavoriteUseCase.getFavoritesCallCount, 2) // Initial load + refresh
    }
    
    func testToggleFavorite_Failure_ShowsError() async {
        // Given
        await sut.loadInitialData()
        mockFavoriteUseCase.shouldFailToggle = true
        mockFavoriteUseCase.mockError = FavoritesUseCaseError.favoriteLimitExceeded(limit: 100)
        
        // When
        await sut.toggleFavorite(testCities[0])
        
        // Then
        XCTAssertTrue(sut.showError)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("100") == true)
    }
    
    // MARK: - Refresh Data Tests
    
    func testRefreshData_Success_UpdatesData() async {
        // Given
        await sut.loadInitialData()
        let newDataInfo = DataSourceInfo(
            totalCities: 5000,
            favoritesCount: 10,
            lastUpdated: Date(),
            dataVersion: "2.0"
        )
        mockLoadUseCase.mockRefreshDataInfo = newDataInfo
        
        // When
        await sut.refreshData()
        
        // Then
        XCTAssertFalse(sut.isRefreshing)
        XCTAssertEqual(sut.dataSourceInfo?.totalCities, 5000)
        XCTAssertEqual(sut.dataSourceInfo?.dataVersion, "2.0")
        XCTAssertFalse(sut.showError)
    }
    
    func testRefreshData_PreventsMultipleCalls() async {
        // Given
        await sut.loadInitialData()
        mockLoadUseCase.refreshDelay = 0.1
        
        // When
        let task1 = Task { await sut.refreshData() }
        let task2 = Task { await sut.refreshData() }
        
        _ = await task1.value
        _ = await task2.value
        
        // Then
        XCTAssertEqual(mockLoadUseCase.forceRefreshCallCount, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testSearchError_ShowsUserFriendlyMessage() async {
        // Given
        await sut.loadInitialData()
        mockSearchUseCase.shouldFail = true
        mockSearchUseCase.mockError = SearchUseCaseError.queryTooLong(maximum: 100)
        
        // When
        sut.searchText = "very long query"
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertTrue(sut.showError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testErrorClearing_WorksCorrectly() async {
        // Given
        mockLoadUseCase.shouldFail = true
        await sut.loadInitialData()
        XCTAssertTrue(sut.showError)
        
        // When
        mockLoadUseCase.shouldFail = false
        await sut.loadInitialData()
        
        // Then
        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.errorMessage)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStates_UpdateCorrectly() async {
        // Given
        mockLoadUseCase.delay = 0.1
        
        // When
        let loadingTask = Task {
            await sut.loadInitialData()
        }
        
        // Then - Check loading state
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        XCTAssertTrue(sut.isInitialLoading)
        XCTAssertTrue(sut.isLoading)
        
        await loadingTask.value
        
        XCTAssertFalse(sut.isInitialLoading)
        XCTAssertFalse(sut.isLoading)
    }
}

// MARK: - Mock Use Cases
@MainActor
private final class MockLoadCitiesUseCase: LoadCitiesUseCaseProtocol, @unchecked Sendable {
    
    var mockDataInfo: DataSourceInfo!
    var mockRefreshDataInfo: DataSourceInfo!
    var shouldFail = false
    var mockError: Error = LoadCitiesUseCaseError.noDataAvailable
    var delay: TimeInterval = 0
    var refreshDelay: TimeInterval = 0
    
    var executeCallCount = 0
    var forceRefreshCallCount = 0
    
    func execute() async -> Result<DataSourceInfo, Error> {
        executeCallCount += 1
        
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldFail {
            return .failure(mockError)
        }
        
        return .success(mockDataInfo)
    }
    
    func forceRefresh() async -> Result<DataSourceInfo, Error> {
        forceRefreshCallCount += 1
        
        if refreshDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(refreshDelay * 1_000_000_000))
        }
        
        if shouldFail {
            return .failure(mockError)
        }
        
        return .success(mockRefreshDataInfo ?? mockDataInfo)
    }
    
    func getCityById(_ id: Int) async -> Result<City?, Error> {
        .success(nil)
    }
    
    func getDataInfo() async -> Result<DataSourceInfo, Error> {
        .success(mockDataInfo)
    }
}

@MainActor
private final class MockSearchCitiesUseCase: SearchCitiesUseCaseProtocol, @unchecked Sendable {
    
    var mockCities: [City] = []
    var mockSearchResult: SearchResult?
    var shouldFail = false
    var mockError: Error = SearchUseCaseError.noResults
    
    func execute(with filter: SearchFilter) async -> Result<SearchResult, Error> {
        if shouldFail {
            return .failure(mockError)
        }
        
        if let customResult = mockSearchResult {
            return .success(customResult)
        }
        
        let filtered = mockCities.filter { city in
            filter.query.isEmpty || city.matchesPrefix(filter.query, searchInCountry: filter.searchInCountry)
        }
        
        let result = SearchResult(
            cities: filtered,
            totalCount: filtered.count,
            query: filter.query,
            searchTime: 0.001
        )
        
        return .success(result)
    }
    
    func executeQuickSearch(_ query: String, limit: Int) async -> Result<[City], Error> {
        if shouldFail {
            return .failure(mockError)
        }
        
        let filtered = mockCities.filter { $0.matchesPrefix(query, searchInCountry: true) }
        return .success(Array(filtered.prefix(limit)))
    }
}

@MainActor
private final class MockFavoriteCitiesUseCase: FavoriteCitiesUseCaseProtocol, @unchecked Sendable {
    
    var mockFavorites: [City] = []
    var mockUpdatedCity: City?
    var shouldFailToggle = false
    var mockError: Error = FavoritesUseCaseError.operationFailed(NSError(domain: "Test", code: 1))
    
    var getFavoritesCallCount = 0
    var toggleFavoriteCallCount = 0
    
    func getFavorites() async -> Result<[City], Error> {
        getFavoritesCallCount += 1
        return .success(mockFavorites)
    }
    
    func toggleFavorite(_ city: City) async -> Result<City, Error> {
        toggleFavoriteCallCount += 1
        
        if shouldFailToggle {
            return .failure(mockError)
        }
        
        return .success(mockUpdatedCity ?? city)
    }
    
    func addToFavorites(_ city: City) async -> Result<City, Error> {
        .success(mockUpdatedCity ?? city)
    }
    
    func removeFromFavorites(_ city: City) async -> Result<City, Error> {
        .success(mockUpdatedCity ?? city)
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


