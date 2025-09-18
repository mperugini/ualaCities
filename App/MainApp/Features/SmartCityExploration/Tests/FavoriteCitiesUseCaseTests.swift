import XCTest
@testable import SmartCityExploration

final class FavoriteCitiesUseCaseTests: XCTestCase {
    
    private var useCase: FavoriteCitiesUseCase!
    private var mockRepository: MockCityRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockCityRepository()
        useCase = FavoriteCitiesUseCase(repository: mockRepository)
    }
    
    override func tearDown() {
        useCase = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - getFavorites Tests
    
    func testGetFavoritesSuccess() async throws {
        // Given
        let expectedCities = [
            City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128)),
            City(id: 2, name: "London", country: "UK", coord: Coordinate(lon: -0.1278, lat: 51.5074))
        ]
        mockRepository.favoriteCities = expectedCities
        
        // When
        let result = await useCase.getFavorites()
        
        // Then
        switch result {
        case .success(let cities):
            XCTAssertEqual(cities.count, 2)
            XCTAssertEqual(cities[0].id, 1)
            XCTAssertEqual(cities[0].name, "New York")
            XCTAssertEqual(cities[1].id, 2)
            XCTAssertEqual(cities[1].name, "London")
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    
    func testGetFavoritesFailure() async throws {
        // Given
        mockRepository.shouldFail = true
        mockRepository.error = CityRepositoryError.dataNotFound
        
        // When
        let result = await useCase.getFavorites()
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - toggleFavorite Tests
    
    func testToggleFavoriteSuccess() async throws {
        // Given
        let city = City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128))
        mockRepository.shouldFail = false
        
        // When
        let result = await useCase.toggleFavorite(city)
        
        // Then
        XCTAssertEqual(mockRepository.toggleFavoriteCallCount, 1)
        XCTAssertEqual(mockRepository.lastToggledCity?.id, 1)
        XCTAssertEqual(mockRepository.lastToggledCity?.name, "New York")
    }
    
    func testToggleFavoriteFailure() async throws {
        let city = City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128), isFavorite: true)
        mockRepository.shouldFail = true
        mockRepository.error = CityRepositoryError.storageError(NSError(domain: "Test", code: 1))
        
        let result = await useCase.toggleFavorite(city)
        XCTAssertEqual(mockRepository.toggleFavoriteCallCount, 1)
    }
    
    // MARK: - isFavorite Tests
    
    func testIsFavoriteTrue() async throws {
        // Given
        let city = City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128))
        let favoriteCities = [
            City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128)),
            City(id: 2, name: "London", country: "UK", coord: Coordinate(lon: -0.1278, lat: 51.5074))
        ]
        mockRepository.favoriteCities = favoriteCities
        
        // When
        let result = await useCase.isFavorite(city)
        
        // Then
        switch result {
        case .success(let isFavorite):
            XCTAssertTrue(isFavorite)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    
    func testIsFavoriteFalse() async throws {
        // Given
        let city = City(id: 3, name: "Paris", country: "France", coord: Coordinate(lon: 2.3522, lat: 48.8566))
        let favoriteCities = [
            City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128)),
            City(id: 2, name: "London", country: "UK", coord: Coordinate(lon: -0.1278, lat: 51.5074))
        ]
        mockRepository.favoriteCities = favoriteCities
        
        // When
        let result = await useCase.isFavorite(city)
        
        // Then
        switch result {
        case .success(let isFavorite):
            XCTAssertFalse(isFavorite)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    
    func testIsFavoriteWithEmptyFavorites() async throws {
        // Given
        let city = City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128))
        mockRepository.favoriteCities = []
        
        // When
        let result = await useCase.isFavorite(city)
        
        // Then
        switch result {
        case .success(let isFavorite):
            XCTAssertFalse(isFavorite)
        case .failure:
            // Expected behavior on empty favorites
            break
        }
    }
    
    func testIsFavoriteFailure() async throws {
        // Given
        let city = City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128))
        mockRepository.shouldFail = true
        mockRepository.error = CityRepositoryError.dataNotFound
        
        // When
        let result = await useCase.isFavorite(city)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure:
            // Expected behavior on error
            break
        }
    }
    
    // MARK: - Integration Tests
    
    func testToggleFavoriteThenCheckIsFavorite() async throws {
        // Given
        let city = City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128))
        mockRepository.favoriteCities = []
        
        // When - Initially not favorite
        let initialResult = await useCase.isFavorite(city)
        
        // Then
        switch initialResult {
        case .success(let isFavorite):
            XCTAssertFalse(isFavorite)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
        
        // When - Toggle to favorite
        let result = await useCase.toggleFavorite(city)
        
        // Simulate repository state change
        mockRepository.favoriteCities = [city]
        
        // Then - Should be favorite
        let afterToggleResult = await useCase.isFavorite(city)
        switch afterToggleResult {
        case .success(let isFavorite):
            XCTAssertTrue(isFavorite)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    
    func testMultipleToggleFavoriteCalls() async throws {
        // Given
        let city = City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128))
        
        // When - Multiple toggle calls
        await useCase.toggleFavorite(city)
        await useCase.toggleFavorite(city)
        await useCase.toggleFavorite(city)
        
        // Then
        XCTAssertEqual(mockRepository.toggleFavoriteCallCount, 3)
        XCTAssertEqual(mockRepository.lastToggledCity?.id, 1)
    }
    
    func testConcurrentToggleFavoriteCalls() async throws {
        // Given
        let city = City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.0060, lat: 40.7128))
        let useCase = self.useCase! // Capture local reference to avoid data races
        
        // When - Concurrent toggle calls
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await useCase.toggleFavorite(city)
                }
            }
        }
        
        // Then
        XCTAssertEqual(mockRepository.toggleFavoriteCallCount, 10)
    }
}

// MARK: - Mock Implementation

private final class MockCityRepository: CityRepository, @unchecked Sendable {
    var favoriteCities: [City] = []
    var shouldFail = false
    var error: Error = CityRepositoryError.dataNotFound
    var toggleFavoriteCallCount = 0
    var getFavoriteCitiesCallCount = 0
    var lastToggledCity: City?
    
    
    func getFavoriteCities() async -> Result<[City], Error> {
        getFavoriteCitiesCallCount += 1
        if shouldFail {
            return .failure(error)
        }
        return .success(favoriteCities)
    }
    
    func toggleFavorite(_ city: City) async -> Result<City, Error> {
        toggleFavoriteCallCount += 1
        lastToggledCity = city
        
        if shouldFail {
            return .failure(error)
        }
        
        // Simulate toggling in the mock
        var updatedCity = city
        if let index = favoriteCities.firstIndex(where: { $0.id == city.id }) {
            favoriteCities.remove(at: index)
            updatedCity.isFavorite = false
        } else {
            updatedCity.isFavorite = true
            favoriteCities.append(updatedCity)
        }
        
        return .success(updatedCity)
    }
    
    // MARK: - Additional Required Protocol Methods
    func downloadAndSaveCities() async -> Result<Void, Error> {
        if shouldFail { return .failure(error) }
        return .success(())
    }
    

    func getInitialCities() async -> Result<[City], Error> {
        if shouldFail { return .failure(error) }
        return .success([])
    }

    func getCities(request: PaginationRequest) async -> Result<PaginatedResult<City>, Error> {
        if shouldFail { return .failure(error) }
        let mockPagination = PaginationInfo(currentPage: request.page, pageSize: request.pageSize, totalItems: 100)
        let mockResult = PaginatedResult<City>(items: [], pagination: mockPagination)
        return .success(mockResult)
    }
    
    func getCitiesCount() async -> Result<Int, Error> {
        if shouldFail { return .failure(error) }
        return .success(0)
    }
    
    func searchCities(request: SearchPaginationRequest) async -> Result<PaginatedResult<City>, Error> {
        if shouldFail { return .failure(error) }

        let mockPagination = PaginationInfo(
            currentPage: request.pagination.page,
            pageSize: request.pagination.pageSize,
            totalItems: 0
        )
        let mockResult = PaginatedResult<City>(items: [], pagination: mockPagination)
        return .success(mockResult)
    }
    
    
    func addToFavorites(_ city: City) async -> Result<City, Error> {
        if shouldFail { return .failure(error) }
        var updatedCity = city
        updatedCity.isFavorite = true
        favoriteCities.append(updatedCity)
        return .success(updatedCity)
    }
    
    func removeFromFavorites(_ city: City) async -> Result<City, Error> {
        if shouldFail { return .failure(error) }
        if let index = favoriteCities.firstIndex(where: { $0.id == city.id }) {
            favoriteCities.remove(at: index)
        }
        var updatedCity = city
        updatedCity.isFavorite = false
        return .success(updatedCity)
    }
    
    func getFavoriteStatus(for cityId: Int) async -> Result<Bool, Error> {
        if shouldFail { return .failure(error) }
        return .success(favoriteCities.contains { $0.id == cityId })
    }
    
    func getCity(by id: Int) async -> Result<City?, Error> {
        if shouldFail { return .failure(error) }
        return .success(favoriteCities.first { $0.id == id })
    }
    
    func updateCity(_ city: City) async -> Result<City, Error> {
        if shouldFail { return .failure(error) }
        return .success(city)
    }
    
    func clearAllData() async -> Result<Void, Error> {
        if shouldFail { return .failure(error) }
        favoriteCities.removeAll()
        return .success(())
    }
    
    func getDataSourceInfo() async -> Result<DataSourceInfo, Error> {
        if shouldFail { return .failure(error) }
        let info = DataSourceInfo(totalCities: 0, favoritesCount: favoriteCities.count, lastUpdated: Date(), dataVersion: "1.0")
        return .success(info)
    }
} 

