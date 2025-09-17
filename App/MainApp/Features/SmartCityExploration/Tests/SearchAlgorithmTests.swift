//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import XCTest
@testable import SmartCityExploration

// MARK: - Search Algorithm Tests (Challenge Requirement)
final class SearchAlgorithmTests: XCTestCase {
    
    private var sut: SearchCitiesUseCase!
    private var mockRepository: MockCityRepository!
    
    // MARK: - Test Data
    private let testCities = [
        City(id: 1, name: "Alabama", country: "US", coord: Coordinate(lon: -86.79113, lat: 32.377716)),
        City(id: 2, name: "Albuquerque", country: "US", coord: Coordinate(lon: -106.609991, lat: 35.110703)),
        City(id: 3, name: "Anaheim", country: "US", coord: Coordinate(lon: -117.946297, lat: 33.835293)),
        City(id: 4, name: "Arizona", country: "US", coord: Coordinate(lon: -111.093735, lat: 34.9455)),
        City(id: 5, name: "Sydney", country: "AU", coord: Coordinate(lon: 151.207321, lat: -33.867851)),
        City(id: 6, name: "São Paulo", country: "BR", coord: Coordinate(lon: -46.633308, lat: -23.55052)),
        City(id: 7, name: "ÁLAVA", country: "ES", coord: Coordinate(lon: -2.674306, lat: 42.846004)) // Test case sensitivity
    ]
    
    override func setUp() {
        super.setUp()
        mockRepository = MockCityRepository()
        sut = SearchCitiesUseCase(repository: mockRepository)
        
        // Setup mock data
        mockRepository.cities = testCities
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Prefix Search Tests (As per challenge clarifications)
    
    func testSearchWithPrefix_A_ReturnsAllACitiesAndCountries() async {
        // Given
        let filter = SearchFilter(query: "A")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 6)
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Alabama" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Albuquerque" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Anaheim" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Arizona" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "ÁLAVA" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Sydney" })
            XCTAssertFalse(searchResult.cities.contains { $0.name == "São Paulo" })
        }
    }
    
    func testSearchWithPrefix_s_ReturnsSydneyAndSaoPaulo() async {
        // Given
        let filter = SearchFilter(query: "s", searchInCountry: true)
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 2) // Sydney and São Paulo
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Sydney" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "São Paulo" })
        }
    }
    
    
    func testSearchWithPrefix_Alb_ReturnsAlbuquerqueOnly() async {
        // Given
        let filter = SearchFilter(query: "Alb")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 1)
            XCTAssertEqual(searchResult.cities.first?.name, "Albuquerque")
        }
    }
    
    // MARK: - Case Insensitivity Tests
    
    func testSearchIsCaseInsensitive_LowerCase() async {
        // Given
        let filter = SearchFilter(query: "alabama")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 1)
            XCTAssertEqual(searchResult.cities.first?.name, "Alabama")
        }
    }
    
    func testSearchIsCaseInsensitive_UpperCase() async {
        // Given
        let filter = SearchFilter(query: "SYDNEY")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 1)
            XCTAssertEqual(searchResult.cities.first?.name, "Sydney")
        }
    }
    
    func testSearchIsCaseInsensitive_MixedCase() async {
        // Given
        let filter = SearchFilter(query: "AlBuQuErQuE")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 1)
            XCTAssertEqual(searchResult.cities.first?.name, "Albuquerque")
        }
    }
    
    // MARK: - Edge Cases and Invalid Inputs
    
    func testSearchWithEmptyQuery_ReturnsEmptyResult() async {
        // Given
        let filter = SearchFilter(query: "")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 0)
            XCTAssertEqual(searchResult.query, "")
        }
    }
    
    func testSearchWithWhitespaceQuery_ReturnsEmptyResult() async {
        // Given
        let filter = SearchFilter(query: "   ")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 0)
        }
    }
    
    func testSearchWithNonExistentPrefix_ReturnsEmptyResult() async {
        // Given
        let filter = SearchFilter(query: "xyz")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 0)
        }
    }
    
    func testSearchWithDiacriticInsensitive_A_FindsALAVA() async {
        // Given - Buscar "A" sin acento debe encontrar "ÁLAVA" con acento
        let filter = SearchFilter(query: "A")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            // Debe incluir ÁLAVA aunque se busque "A" sin acento
            XCTAssertTrue(searchResult.cities.contains { $0.name == "ÁLAVA" })
            XCTAssertEqual(searchResult.cities.count, 6) // Alabama, Albuquerque, Anaheim, Arizona, ÁLAVA + Sydney (país AU)
        }
    }
    
    func testSearchWithDiacriticInsensitive_ALAVA_FindsALAVA() async {
        // Given - Buscar "ALAVA" sin acento debe encontrar "ÁLAVA" con acento
        let filter = SearchFilter(query: "ALAVA")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 1)
            XCTAssertEqual(searchResult.cities.first?.name, "ÁLAVA")
        }
    }
    
    func testCityMatchesPrefixLogic() {
        // Test directo del método matchesPrefix para debugging
        let sydney = City(id: 5, name: "Sydney", country: "AU", coord: Coordinate(lon: 151.207321, lat: -33.867851))
        let alava = City(id: 7, name: "ÁLAVA", country: "ES", coord: Coordinate(lon: -2.674306, lat: 42.846004))
        
        // Verificar que Sydney coincide con "A" por país
        XCTAssertTrue(sydney.matchesPrefix("A", searchInCountry: true), "Sydney should match 'A' because AU starts with A")
        XCTAssertFalse(sydney.matchesPrefix("A", searchInCountry: false), "Sydney should NOT match 'A' when searching only city names")
        
        // Verificar que ÁLAVA coincide con "A" por nombre
        XCTAssertTrue(alava.matchesPrefix("A", searchInCountry: true), "ÁLAVA should match 'A' by city name")
        XCTAssertTrue(alava.matchesPrefix("A", searchInCountry: false), "ÁLAVA should match 'A' even when searching only city names")
    }
    
    // MARK: - Bidirectional Accent Search Tests
    
    func testBidirectionalAccentSearch_A_FindsBothAlabamaAndALAVA() async {
        // Given - Buscar "A" sin acento debe encontrar ciudades con y sin acento
        let filter = SearchFilter(query: "A")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            // Debe encontrar ciudades que empiecen con A sin acento
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Alabama" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Albuquerque" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Anaheim" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Arizona" })
            
            // Y también debe encontrar ciudades que empiecen con Á con acento
            XCTAssertTrue(searchResult.cities.contains { $0.name == "ÁLAVA" })
            
            // Y ciudades de países que empiecen con A
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Sydney" })
            
            XCTAssertEqual(searchResult.cities.count, 6)
        }
    }
    
    func testBidirectionalAccentSearch_AccentedA_FindsBothAlabamaAndALAVA() async {
        // Given - Buscar "Á" con acento debe encontrar ciudades con y sin acento
        let filter = SearchFilter(query: "Á")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            // Debe encontrar ciudades que empiecen con A sin acento
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Alabama" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Albuquerque" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Anaheim" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Arizona" })
            
            // Y también debe encontrar ciudades que empiecen con Á con acento
            XCTAssertTrue(searchResult.cities.contains { $0.name == "ÁLAVA" })
            
            // Y ciudades de países que empiecen con A
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Sydney" })
            
            XCTAssertEqual(searchResult.cities.count, 6)
        }
    }
    
    func testBidirectionalAccentSearch_AL_Variations() async {
        // Test con diferentes variaciones de "AL"
        let testCases = ["AL", "ÁL", "al", "ál"]
        
        for query in testCases {
            // Given
            let filter = SearchFilter(query: query)
            
            // When
            let result = await sut.execute(with: filter)
            
            // Then
            XCTAssertResultSuccess(result) { searchResult in
                // Ambos deben aparecer para cualquier variación de AL
                XCTAssertTrue(searchResult.cities.contains { $0.name == "Alabama" }, "Alabama should match '\(query)'")
                XCTAssertTrue(searchResult.cities.contains { $0.name == "Albuquerque" }, "Albuquerque should match '\(query)'")
                XCTAssertTrue(searchResult.cities.contains { $0.name == "ÁLAVA" }, "ÁLAVA should match '\(query)'")
                
                XCTAssertEqual(searchResult.cities.count, 3, "Should find exactly 3 cities for '\(query)'")
            }
        }
    }
    
    func testStringFoldingBidirectional() {
        // Test directo de String.folding para confirmar comportamiento bidireccional
        let alabama = "Alabama"
        let alava = "ÁLAVA"
        
        // Normalizar todos los strings
        let alabamaNormalized = alabama.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let alavaNormalized = alava.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        
        // Normalizar diferentes variaciones de prefijos
        let prefixA = "A".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let prefixAccentedA = "Á".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let prefixLowerA = "a".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        
        // Verificar que todos los prefijos normalizados son iguales
        XCTAssertEqual(prefixA, prefixAccentedA, "A and Á should normalize to the same value")
        XCTAssertEqual(prefixA, prefixLowerA, "A and a should normalize to the same value")
        
        // Verificar que ambas ciudades coinciden con cualquier variación de "A"
        XCTAssertTrue(alabamaNormalized.hasPrefix(prefixA), "Alabama should match normalized A")
        XCTAssertTrue(alabamaNormalized.hasPrefix(prefixAccentedA), "Alabama should match normalized Á")
        XCTAssertTrue(alavaNormalized.hasPrefix(prefixA), "ÁLAVA should match normalized A")
        XCTAssertTrue(alavaNormalized.hasPrefix(prefixAccentedA), "ÁLAVA should match normalized Á")
        
        print("Normalized values:")
        print("  Alabama: '\(alabamaNormalized)'")
        print("  ÁLAVA: '\(alavaNormalized)'")
        print("  A: '\(prefixA)'")
        print("  Á: '\(prefixAccentedA)'")
    }
    
    
    
    // MARK: - Favorites Filter Tests
    
    func testSearchWithFavoritesFilter_ReturnsOnlyFavorites() async {
        // Given
        var favoriteCities = testCities
        favoriteCities[0].isFavorite = true // Alabama
        favoriteCities[4].isFavorite = true // Sydney
        mockRepository.cities = favoriteCities
        
        let filter = SearchFilter(query: "", showOnlyFavorites: true)
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 2)
            XCTAssertTrue(searchResult.cities.allSatisfy { $0.isFavorite })
        }
    }
    
    func testSearchWithPrefix_AU_ReturnsSydneyByCountry() async {
        // Given
        let filter = SearchFilter(query: "AU", searchInCountry: true)
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 1) // Solo Sydney (por país AU)
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Sydney" && $0.country == "AU" })
        }
    }
    
    func testSearchWithPrefix_US_ReturnsAllUSCities() async {
        // Given
        let filter = SearchFilter(query: "US", searchInCountry: true)
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 4) // Alabama, Albuquerque, Anaheim, Arizona
            XCTAssertTrue(searchResult.cities.allSatisfy { $0.country == "US" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Alabama" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Albuquerque" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Anaheim" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Arizona" })
        }
    }
    
    func testSearchWithPrefix_BR_ReturnsSaoPauloByCountry() async {
        // Given
        let filter = SearchFilter(query: "BR", searchInCountry: true)
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 1) // Solo São Paulo (por país BR)
            XCTAssertTrue(searchResult.cities.contains { $0.name == "São Paulo" && $0.country == "BR" })
        }
    }
    
    func testSearchWithPrefix_A_CityOnlyMode_ExcludesCountryMatches() async {
        // Given - Buscar solo en nombres de ciudad, no en país
        let filter = SearchFilter(query: "A", searchInCountry: false)
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            // Solo ciudades que empiecen con "A", no países que empiecen con "A"
            XCTAssertEqual(searchResult.cities.count, 5) // Alabama, Albuquerque, Anaheim, Arizona, ÁLAVA
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Alabama" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Albuquerque" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Anaheim" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Arizona" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "ÁLAVA" })
            // Sydney no debería aparecer aunque su país sea AU
            XCTAssertFalse(searchResult.cities.contains { $0.name == "Sydney" })
        }
    }
    
    func testSearchWithPrefix_S_CityOnlyMode_OnlyCityNames() async {
        // Given - Buscar solo en nombres de ciudad
        let filter = SearchFilter(query: "S", searchInCountry: false)
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultSuccess(result) { searchResult in
            XCTAssertEqual(searchResult.cities.count, 2) // Sydney, São Paulo
            XCTAssertTrue(searchResult.cities.contains { $0.name == "Sydney" })
            XCTAssertTrue(searchResult.cities.contains { $0.name == "São Paulo" })
        }
    }
    
    // MARK: - Performance Tests
    
    func testSearchPerformance_WithLargeDataset() async {
        // Given
        let largeCityList = generateLargeCityList(count: 10000)
        mockRepository.cities = largeCityList
        let filter = SearchFilter(query: "Test")
        
        // When & Then
        await measureAsyncTime { 
            let result = await sut.execute(with: filter)
            XCTAssertResultSuccess(result)
        }
    }
    
    func testQuickSearchPerformance() async {
        // Given
        let largeCityList = generateLargeCityList(count: 10000)
        mockRepository.cities = largeCityList
        
        // When & Then
        await measureAsyncTime {
            let result = await sut.executeQuickSearch("Test", limit: 100)
            XCTAssertResultSuccess(result)
        }
    }
    
    // MARK: - Repository Error Handling
    
    func testSearchHandlesRepositoryError() async {
        // Given
        mockRepository.shouldFail = true
        mockRepository.mockError = CityRepositoryError.searchFailed(NSError(domain: "Test", code: 1))
        let filter = SearchFilter(query: "test")
        
        // When
        let result = await sut.execute(with: filter)
        
        // Then
        XCTAssertResultFailure(result)
    }
    
    // MARK: - Helper Methods
    
    private func generateLargeCityList(count: Int) -> [City] {
        return (0..<count).map { index in
            City(
                id: index,
                name: "TestCity\(index)",
                country: "TS",
                coord: Coordinate(lon: Double(index), lat: Double(index))
            )
        }
    }
}

// MARK: - Mock Repository for Testing
private final class MockCityRepository: CityRepository, @unchecked Sendable {
    
    var cities: [City] = []
    var shouldFail = false
    var mockError: Error = CityRepositoryError.dataNotFound
    
    func searchCities(with filter: SearchFilter) async -> Result<SearchResult, Error> {
        if shouldFail {
            return .failure(mockError)
        }
        
        var filtered = cities
        
        if !filter.query.isEmpty {
            let query = filter.query.lowercased()
            filtered = filtered.filter { city in
                city.matchesPrefix(query, searchInCountry: filter.searchInCountry)
            }
        }
        
        if filter.showOnlyFavorites {
            filtered = filtered.filter { $0.isFavorite }
        }
        
        // Sort alphabetically
        filtered.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        
        if let limit = filter.limit {
            filtered = Array(filtered.prefix(limit))
        }
        
        let searchResult = SearchResult(
            cities: filtered,
            totalCount: filtered.count,
            query: filter.query,
            searchTime: 0.001
        )
        
        return .success(searchResult)
    }
    
    
    // MARK: - Other Required Methods (Minimal Implementation)
    func downloadAndSaveCities() async -> Result<Void, Error> { .success(()) }
    func getAllCities() async -> Result<[City], Error> { .success(cities) }
    func getCitiesCount() async -> Result<Int, Error> { .success(cities.count) }
    func getFavoriteCities() async -> Result<[City], Error> { .success(cities.filter { $0.isFavorite }) }
    func toggleFavorite(_ city: City) async -> Result<City, Error> { .success(city) }
    func addToFavorites(_ city: City) async -> Result<City, Error> { .success(city) }
    func removeFromFavorites(_ city: City) async -> Result<City, Error> { .success(city) }
    func getFavoriteStatus(for cityId: Int) async -> Result<Bool, Error> { .success(false) }
    func getCity(by id: Int) async -> Result<City?, Error> { .success(cities.first { $0.id == id }) }
    func updateCity(_ city: City) async -> Result<City, Error> { .success(city) }
    func clearAllData() async -> Result<Void, Error> { .success(()) }
    func getDataSourceInfo() async -> Result<DataSourceInfo, Error> {
        let info = DataSourceInfo(totalCities: cities.count, favoritesCount: cities.filter { $0.isFavorite }.count, lastUpdated: Date(), dataVersion: "1.0")
        return .success(info)
    }
}

// MARK: - Test Utilities
extension XCTestCase {
    
    func XCTAssertResultSuccess<T, E: Error>(
        _ result: Result<T, E>,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ validation: (T) -> Void = { _ in }
    ) {
        switch result {
        case .success(let value):
            validation(value)
        case .failure(let error):
            XCTFail("Expected success but got failure: \(error). \(message)", file: file, line: line)
        }
    }
    
    func XCTAssertResultFailure<T, E: Error>(
        _ result: Result<T, E>,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ validation: (E) -> Void = { _ in }
    ) {
        switch result {
        case .success(let value):
            XCTFail("Expected failure but got success: \(value). \(message)", file: file, line: line)
        case .failure(let error):
            validation(error)
        }
    }
    
    func measureAsyncTime(operation: () async throws -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            try await operation()
        } catch {
            XCTFail("Async operation failed: \(error)")
        }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Async operation completed in \(String(format: "%.4f", timeElapsed))s")
        
        // Assert performance (less than 1 second for large operations)
        XCTAssertLessThan(timeElapsed, 1.0, "Operation took too long: \(timeElapsed)s")
    }
}

