//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Repository Implementation (Clean Architecture + SOLID Principles)
public final class CityRepositoryImpl: CityRepository {
    
    private let localDataSource: LocalDataSource
    private let remoteDataSource: RemoteDataSource
    
    // MARK: - Initialization (Dependency Injection)
    public init(
        localDataSource: LocalDataSource = CoreDataLocalDataSource(),
        remoteDataSource: RemoteDataSource = URLSessionRemoteDataSource()
    ) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
    
    // MARK: - Data Loading
    public func downloadAndSaveCities() async -> Result<Void, Error> {
        print("Starting city data download and save process...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let downloadResult = await remoteDataSource.downloadCities()
        
        switch downloadResult {
        case .success(let cities):
            do {
                try await localDataSource.saveCities(cities)
                try await localDataSource.setLastUpdateDate(Date())
                
                let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                print("Successfully processed \(cities.count) cities in \(String(format: "%.2f", totalTime))s")
                
                return .success(())
                
            } catch {
                print("Failed to save cities locally: \(error.localizedDescription)")
                return .failure(CityRepositoryError.storageError(error))
            }
            
        case .failure(let error):
            print("Failed to download cities: \(error.localizedDescription)")
            return .failure(CityRepositoryError.networkError(error))
        }
    }
    
    public func getAllCities() async -> Result<[City], Error> {
        return await localDataSource.getAllCities()
    }
    
    public func getCitiesCount() async -> Result<Int, Error> {
        do {
            let count = try await localDataSource.getCitiesCount()
            return .success(count)
        } catch {
            return .failure(CityRepositoryError.storageError(error))
        }
    }
    
    // MARK: - Search Operations (Optimized for Performance)
    public func searchCities(with filter: SearchFilter) async -> Result<SearchResult, Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Validate search filter
        guard filter.isValidQuery else {
            return .failure(CityRepositoryError.invalidData)
        }
        
        let result = await localDataSource.searchCities(with: filter)
        
        switch result {
        case .success(let cities):
            let searchTime = CFAbsoluteTimeGetCurrent() - startTime
            let searchResult = SearchResult(
                cities: cities,
                totalCount: cities.count,
                query: filter.query,
                searchTime: searchTime
            )
            return .success(searchResult)
            
        case .failure(let error):
            return .failure(CityRepositoryError.searchFailed(error))
        }
    }
    
    public func searchCitiesWithPrefix(_ prefix: String, limit: Int) async -> Result<[City], Error> {
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Input validation
        guard trimmedPrefix.count >= SearchConstants.minimumQueryLength || trimmedPrefix.isEmpty else {
            return .failure(CityRepositoryError.invalidData)
        }
        
        guard trimmedPrefix.count <= SearchConstants.maximumQueryLength else {
            return .failure(CityRepositoryError.invalidData)
        }
        
        return await localDataSource.searchCitiesWithPrefix(trimmedPrefix, limit: limit)
    }
    
    // MARK: - Favorites Management
    public func getFavoriteCities() async -> Result<[City], Error> {
        return await localDataSource.getFavoriteCities()
    }
    
    public func toggleFavorite(_ city: City) async -> Result<City, Error> {
        do {
            let updatedCity = try await localDataSource.toggleFavorite(city)
            return .success(updatedCity)
        } catch {
            return .failure(CityRepositoryError.storageError(error))
        }
    }
    
    public func addToFavorites(_ city: City) async -> Result<City, Error> {
        do {
            let updatedCity = try await localDataSource.setFavoriteStatus(city, isFavorite: true)
            return .success(updatedCity)
        } catch {
            return .failure(CityRepositoryError.storageError(error))
        }
    }
    
    public func removeFromFavorites(_ city: City) async -> Result<City, Error> {
        do {
            let updatedCity = try await localDataSource.setFavoriteStatus(city, isFavorite: false)
            return .success(updatedCity)
        } catch {
            return .failure(CityRepositoryError.storageError(error))
        }
    }
    
    public func getFavoriteStatus(for cityId: Int) async -> Result<Bool, Error> {
        return await localDataSource.getFavoriteStatus(for: cityId)
    }
    
    // MARK: - Individual City Operations
    public func getCity(by id: Int) async -> Result<City?, Error> {
        return await localDataSource.getCity(by: id)
    }
    
    public func updateCity(_ city: City) async -> Result<City, Error> {
        do {
            try await localDataSource.updateCity(city)
            return .success(city)
        } catch {
            return .failure(CityRepositoryError.storageError(error))
        }
    }
    
    // MARK: - Data Management
    public func clearAllData() async -> Result<Void, Error> {
        do {
            try await localDataSource.clearAllCities()
            return .success(())
        } catch {
            return .failure(CityRepositoryError.storageError(error))
        }
    }
    
    public func getDataSourceInfo() async -> Result<DataSourceInfo, Error> {
        do {
            let totalCities = try await localDataSource.getCitiesCount()
            let favoritesCount = try await localDataSource.getFavoritesCount()
            let lastUpdated = await localDataSource.getLastUpdateDate()
            let dataVersion = "0.0.1" // Could be dynamic based on API versioning
            
            print("Repository data check: \(totalCities) cities, \(favoritesCount) favorites, lastUpdated: \(lastUpdated?.description ?? "nil")")
            
            let info = DataSourceInfo(
                totalCities: totalCities,
                favoritesCount: favoritesCount,
                lastUpdated: lastUpdated,
                dataVersion: dataVersion
            )
            
            return .success(info)
            
        } catch {
            print("Error getting data source info: \(error)")
            return .failure(CityRepositoryError.storageError(error))
        }
    }
}

// MARK: - Repository Factory (Factory Pattern)
public final class CityRepositoryFactory {
    
    public static func create() -> CityRepository {
        let localDataSource = CoreDataLocalDataSource()
        let remoteDataSource = URLSessionRemoteDataSource()
        
        return CityRepositoryImpl(
            localDataSource: localDataSource,
            remoteDataSource: remoteDataSource
        )
    }
    
    #if DEBUG
    public static func createMock() -> CityRepository {
        let mockLocalDataSource = MockLocalDataSource()
        let mockRemoteDataSource = MockRemoteDataSource()
        
        return CityRepositoryImpl(
            localDataSource: mockLocalDataSource,
            remoteDataSource: mockRemoteDataSource
        )
    }
    #endif
}

// MARK: - Mock Implementation for Testing
#if DEBUG
public final class MockLocalDataSource: LocalDataSource, @unchecked Sendable {
    
    private let lock = NSLock()
    private var _cities: [City] = []
    private var _shouldFail = false
    private var _mockError: Error = CityRepositoryError.dataNotFound
    
    public var cities: [City] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _cities
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _cities = newValue
        }
    }
    
    public var shouldFail: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _shouldFail
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _shouldFail = newValue
        }
    }
    
    public var mockError: Error {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mockError
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _mockError = newValue
        }
    }
    
    public init() {}
    
    // MARK: - Batch Operations
    public func saveCities(_ cities: [City]) async throws {
        if shouldFail { throw mockError }
        self.cities = cities
    }
    
    public func clearAllCities() async throws {
        if shouldFail { throw mockError }
        cities.removeAll()
    }
    
    public func getCitiesCount() async throws -> Int {
        if shouldFail { throw mockError }
        return cities.count
    }
    
    // MARK: - Search Operations
    public func getAllCities() async -> Result<[City], Error> {
        if shouldFail { return .failure(mockError) }
        return .success(cities.sorted { $0.displayName < $1.displayName })
    }
    
    public func searchCitiesWithPrefix(_ prefix: String, limit: Int) async -> Result<[City], Error> {
        if shouldFail { return .failure(mockError) }
        
        let filtered = cities.filter { city in
            city.matchesPrefix(prefix, searchInCountry: true)
        }
        .sorted { $0.displayName < $1.displayName }
        .prefix(limit)
        
        return .success(Array(filtered))
    }
    
    public func searchCities(with filter: SearchFilter) async -> Result<[City], Error> {
        if shouldFail { return .failure(mockError) }
        
        var filtered = cities
        
        if !filter.query.isEmpty {
            filtered = filtered.filter { $0.matchesPrefix(filter.query, searchInCountry: filter.searchInCountry) }
        }
        
        if filter.showOnlyFavorites {
            filtered = filtered.filter { $0.isFavorite }
        }
        
        filtered.sort { $0.displayName < $1.displayName }
        
        if let limit = filter.limit {
            filtered = Array(filtered.prefix(limit))
        }
        
        return .success(filtered)
    }
    
    // MARK: - Individual City Operations
    public func getCity(by id: Int) async -> Result<City?, Error> {
        if shouldFail { return .failure(mockError) }
        return .success(cities.first { $0.id == id })
    }
    
    public func updateCity(_ city: City) async throws {
        if shouldFail { throw mockError }
        
        if let index = cities.firstIndex(where: { $0.id == city.id }) {
            cities[index] = city
        } else {
            cities.append(city)
        }
    }
    
    // MARK: - Favorites Management
    public func getFavoriteCities() async -> Result<[City], Error> {
        if shouldFail { return .failure(mockError) }
        let favorites = cities.filter { $0.isFavorite }.sorted { $0.displayName < $1.displayName }
        return .success(favorites)
    }
    
    public func toggleFavorite(_ city: City) async throws -> City {
        if shouldFail { throw mockError }
        return try await setFavoriteStatus(city, isFavorite: !city.isFavorite)
    }
    
    public func setFavoriteStatus(_ city: City, isFavorite: Bool) async throws -> City {
        if shouldFail { throw mockError }
        
        var updatedCity = city
        updatedCity.isFavorite = isFavorite
        
        if let index = cities.firstIndex(where: { $0.id == city.id }) {
            cities[index] = updatedCity
        }
        
        return updatedCity
    }
    
    public func getFavoriteStatus(for cityId: Int) async -> Result<Bool, Error> {
        if shouldFail { return .failure(mockError) }
        let isFavorite = cities.first { $0.id == cityId }?.isFavorite ?? false
        return .success(isFavorite)
    }
    
    public func getFavoritesCount() async throws -> Int {
        if shouldFail { throw mockError }
        return cities.filter { $0.isFavorite }.count
    }
    
    // MARK: - Data Info
    public func getLastUpdateDate() async -> Date? {
        return Date()
    }
    
    public func setLastUpdateDate(_ date: Date) async throws {
        if shouldFail { throw mockError }
    }
}
#endif
