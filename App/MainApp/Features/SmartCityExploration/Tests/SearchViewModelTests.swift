//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import XCTest
@testable import SmartCityExploration

// MARK: - Search ViewModel Tests
@MainActor
final class SearchViewModelTests: XCTestCase, @unchecked Sendable {
    
    private var sut: SearchViewModel!
    private var mockSearchUseCase: MockSearchCitiesUseCase!
    
    // MARK: - Test Data
    private let testCities = [
        City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.006, lat: 40.7128)),
        City(id: 2, name: "London", country: "GB", coord: Coordinate(lon: -0.1276, lat: 51.5074)),
        City(id: 3, name: "Tokyo", country: "JP", coord: Coordinate(lon: 139.6917, lat: 35.6895))
    ]
    
    override func setUp() {
        super.setUp()
        
        MainActor.assumeIsolated {
            mockSearchUseCase = MockSearchCitiesUseCase()
            sut = SearchViewModel(searchUseCase: mockSearchUseCase)
            mockSearchUseCase.mockCities = testCities
        }
    }
    
    override func tearDown() {
        MainActor.assumeIsolated {
            sut = nil
            mockSearchUseCase = nil
        }
        super.tearDown()
    }
    
    // MARK: - Search Functionality Tests
    
    func testClearSearch_ResetsSearchState() async {
        // Given
        sut.searchText = "London"
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // When
        sut.clearSearch()
        
        // Then
        XCTAssertTrue(sut.searchText.isEmpty)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertFalse(sut.isSearching)
    }
    
    func testSearchError_TriggersErrorCallback() async {
        // Given
        mockSearchUseCase.shouldFail = true
        mockSearchUseCase.mockError = SearchUseCaseError.queryTooLong(maximum: 100)
        
        var errorOccurred = false
        sut.onErrorOccurred = { _ in
            errorOccurred = true
        }
        
        // When
        sut.searchText = "very long query"
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertTrue(errorOccurred)
        XCTAssertTrue(sut.searchResults.isEmpty)
    }
    
    func testSearchDebouncing_PreventsExcessiveCalls() async {
        // Given
        var searchCallCount = 0
        mockSearchUseCase.onExecute = { _ in
            searchCallCount += 1
        }
        
        // When - Rapid text changes
        sut.searchText = "N"
        sut.searchText = "Ne"
        sut.searchText = "New"
        sut.searchText = "New "
        sut.searchText = "New Y"
        sut.searchText = "New Yo"
        sut.searchText = "New Yor"
        sut.searchText = "New York"
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Then - Should only call once due to debouncing
        XCTAssertEqual(searchCallCount, 1)
    }
    
    func testSearchWithDifferentFilters() async {
        // Given
        let filter1 = SearchFilter(query: "New", searchInCountry: true)
        let filter2 = SearchFilter(query: "New", searchInCountry: false)
        
        // When
        sut.searchText = "New"
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertTrue(sut.isSearching)
        XCTAssertEqual(sut.searchResults.count, 1)
    }
}

// MARK: - Mock Search Use Case
@MainActor
private final class MockSearchCitiesUseCase: SearchCitiesUseCaseProtocol, @unchecked Sendable {
    
    var mockCities: [City] = []
    var mockSearchResult: SearchResult?
    var shouldFail = false
    var mockError: Error = SearchUseCaseError.noResults
    var delay: TimeInterval = 0
    var onExecute: ((SearchFilter) -> Void)?
    
    func execute(with filter: SearchFilter) async -> Result<SearchResult, Error> {
        onExecute?(filter)
        
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
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
}
