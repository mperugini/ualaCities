//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Repository Implementation
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
    
    
    public func getCitiesCount() async -> Result<Int, Error> {
        do {
            let count = try await localDataSource.getCitiesCount()
            return .success(count)
        } catch {
            return .failure(CityRepositoryError.storageError(error))
        }
    }

    // MARK: - Data Loading
    public func getCities(request: PaginationRequest) async -> Result<PaginatedResult<City>, Error> {
        do {
            // Get total count first
            let totalCount = try await localDataSource.getCitiesCount()

            // Get cities
            let cities = try await localDataSource.getCities(offset: request.offset, limit: request.pageSize)

            // Build pagination info
            let paginationInfo = PaginationInfo(
                currentPage: request.page,
                pageSize: request.pageSize,
                totalItems: totalCount
            )

            let result = PaginatedResult(
                items: cities,
                pagination: paginationInfo
            )

            return .success(result)

        } catch {
            return .failure(CityRepositoryError.storageError(error))
        }
    }
    

    public func searchCities(request: SearchPaginationRequest) async -> Result<PaginatedResult<City>, Error> {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Create search filter from request
        let filter = SearchFilter(
            query: request.query,
            showOnlyFavorites: request.showOnlyFavorites,
            limit: nil // No limit here, we'll handle pagination separately
        )

        // Validate search filter
        guard filter.isValidQuery else {
            return .failure(CityRepositoryError.invalidData)
        }

        do {
            // Get total search results count
            let totalSearchResults = try await localDataSource.getSearchResultsCount(with: filter)

            let cities = try await localDataSource.searchCities(
                with: filter,
                offset: request.pagination.offset,
                limit: request.pagination.pageSize
            )

            let paginationInfo = PaginationInfo(
                currentPage: request.pagination.page,
                pageSize: request.pagination.pageSize,
                totalItems: totalSearchResults
            )

            let result = PaginatedResult(
                items: cities,
                pagination: paginationInfo
            )

            let searchTime = CFAbsoluteTimeGetCurrent() - startTime

            return .success(result)

        } catch {
            return .failure(CityRepositoryError.searchFailed(error))
        }
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
    public func getCities(offset: Int, limit: Int) async throws -> [City] {
        lock.lock()
        defer { lock.unlock() }

        if _shouldFail {
            throw _mockError
        }

        let startIndex = offset
        let endIndex = min(startIndex + limit, _cities.count)

        guard startIndex < _cities.count else {
            return []
        }

        return Array(_cities[startIndex..<endIndex])
    }

    public func searchCities(with filter: SearchFilter, offset: Int, limit: Int) async throws -> [City] {
        lock.lock()
        defer { lock.unlock() }

        if _shouldFail {
            throw _mockError
        }

        var filteredCities = _cities

        // Apply favorites filter
        if filter.showOnlyFavorites {
            filteredCities = filteredCities.filter { $0.isFavorite }
        }

        // Apply search query filter
        if !filter.query.isEmpty {
            filteredCities = filteredCities.filter { city in
                city.matchesPrefix(filter.query)
            }
        }

        let startIndex = offset
        let endIndex = min(startIndex + limit, filteredCities.count)

        guard startIndex < filteredCities.count else {
            return []
        }

        return Array(filteredCities[startIndex..<endIndex])
    }

    public func getSearchResultsCount(with filter: SearchFilter) async throws -> Int {
        lock.lock()
        defer { lock.unlock() }

        if _shouldFail {
            throw _mockError
        }

        var filteredCities = _cities

        // Apply favorites filter
        if filter.showOnlyFavorites {
            filteredCities = filteredCities.filter { $0.isFavorite }
        }

        // Apply search query filter
        if !filter.query.isEmpty {
            filteredCities = filteredCities.filter { city in
                city.matchesPrefix(filter.query)
            }
        }

        return filteredCities.count
    }
    
    
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
    


    public func searchCitiesLegacy(with filter: SearchFilter) async -> Result<[City], Error> {
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
