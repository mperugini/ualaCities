//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Use Case Protocol (Single Responsibility Principle)
public protocol LoadCitiesUseCaseProtocol: Sendable {
    func execute() async -> Result<DataSourceInfo, Error>
    func forceRefresh() async -> Result<DataSourceInfo, Error>
    func getCityById(_ id: Int) async -> Result<City?, Error>
    func getDataInfo() async -> Result<DataSourceInfo, Error>
    func getInitialCities() async -> Result<[City], Error>
    func getCities(request: PaginationRequest) async -> Result<PaginatedResult<City>, Error>
}

// MARK: - Load Cities Use Case Implementation
public final class LoadCitiesUseCase: LoadCitiesUseCaseProtocol {
    
    private let repository: CityRepository
    
    // Business rule: Cache expiration time (24 hours)
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    // MARK: - Initialization (Dependency Injection)
    public init(repository: CityRepository) {
        self.repository = repository
    }
    
    // MARK: - Business Logic Implementation
    public func execute() async -> Result<DataSourceInfo, Error> {
        print("Starting city data loading process...")
        
        // Check if we have cached data first
        let infoResult = await repository.getDataSourceInfo()
        
        switch infoResult {
        case .success(let info):
            print("Cache info: totalCities=\(info.totalCities), lastUpdated=\(info.lastUpdated?.description ?? "nil")")
            
            // Business rule: Check if cache is still valid
            if let lastUpdated = info.lastUpdated {
                let timeSinceUpdate = Date().timeIntervalSince(lastUpdated)
                let hoursOld = timeSinceUpdate / 3600
                print("Data is \(String(format: "%.1f", hoursOld)) hours old (limit: \(cacheExpirationInterval/3600) hours)")
                
                if timeSinceUpdate < cacheExpirationInterval && info.totalCities > 0 {
                    print("Using cached data (\(info.totalCities) cities) - cache is still fresh")
                    return .success(info)
                } else if timeSinceUpdate >= cacheExpirationInterval {
                    print("Cache expired (\(String(format: "%.1f", hoursOld))h old), downloading fresh data...")
                    return await downloadAndReturnInfo()
                } else {
                    print("Cache is fresh but no cities found, downloading...")
                    return await downloadAndReturnInfo()
                }
            } else {
                print("No lastUpdated date found, downloading fresh data...")
                return await downloadAndReturnInfo()
            }
            
        case .failure(let error):
            // No cached data available, download fresh
            print("No cached data found (error: \(error)), downloading...")
            return await downloadAndReturnInfo()
        }
    }
    
    public func forceRefresh() async -> Result<DataSourceInfo, Error> {
        print("Force refreshing city data...")
        return await downloadAndReturnInfo()
    }
    
    public func getCityById(_ id: Int) async -> Result<City?, Error> {
        let result = await repository.getCity(by: id)
        
        switch result {
        case .success(let city):
            return .success(city)
        case .failure(let error):
            return .failure(LoadCitiesUseCaseError.cityNotFound(id: id, underlying: error))
        }
    }
    
    public func getDataInfo() async -> Result<DataSourceInfo, Error> {
        print("Getting data info for diagnostics...")
        let result = await repository.getDataSourceInfo()

        switch result {
        case .success(let info):
            print("Data info retrieved: \(info.totalCities) cities, lastUpdated: \(info.lastUpdated?.description ?? "nil")")
            return .success(info)
        case .failure(let error):
            print("Failed to get data info: \(error)")
            return .failure(LoadCitiesUseCaseError.dataInfoUnavailable(underlying: error))
        }
    }


    /// Loads initial cities using pagination (memory efficient)
    /// Returns the first page of cities instead of loading all cities in memory
    public func getInitialCities() async -> Result<[City], Error> {
        print("📄 Loading initial cities using pagination...")

        let request = PaginationRequest(page: 0, pageSize: PaginationConstants.defaultPageSize)
        let result = await repository.getCities(request: request)

        switch result {
        case .success(let paginatedResult):
            print("📄 Successfully loaded initial page: \(paginatedResult.items.count) cities")
            return .success(paginatedResult.items)
        case .failure(let error):
            print("📄 Failed to load initial cities: \(error)")
            return .failure(LoadCitiesUseCaseError.dataInfoUnavailable(underlying: error))
        }
    }

    public func getCities(request: PaginationRequest) async -> Result<PaginatedResult<City>, Error> {
        print("📄 Loading cities page \(request.page) (size: \(request.pageSize))")

        let result = await repository.getCities(request: request)

        switch result {
        case .success(let paginatedResult):
            print("📄 Successfully loaded page \(request.page): \(paginatedResult.items.count) cities")
            return .success(paginatedResult)
        case .failure(let error):
            print("📄 Failed to load page \(request.page): \(error)")
            return .failure(LoadCitiesUseCaseError.dataInfoUnavailable(underlying: error))
        }
    }
    
    // MARK: - Private Methods
    private func downloadAndReturnInfo() async -> Result<DataSourceInfo, Error> {
        let downloadResult = await repository.downloadAndSaveCities()
        
        switch downloadResult {
        case .success:
            // Return updated info after successful download
            let infoResult = await repository.getDataSourceInfo()
            
            switch infoResult {
            case .success(let info):
                print("Successfully loaded \(info.totalCities) cities")
                return .success(info)
                
            case .failure(let error):
                return .failure(LoadCitiesUseCaseError.dataInfoUnavailable(underlying: error))
            }
            
        case .failure(let error):
            // Try to return cached data as fallback
            let fallbackResult = await repository.getDataSourceInfo()
            
            switch fallbackResult {
            case .success(let info) where info.totalCities > 0:
                print("Download failed, using cached data (\(info.totalCities) cities)")
                return .success(info)
                
            case .success, .failure:
                return .failure(LoadCitiesUseCaseError.downloadFailed(underlying: error))
            }
        }
    }
}

// MARK: - Use Case Errors
public enum LoadCitiesUseCaseError: Error, LocalizedError, Equatable {
    case downloadFailed(underlying: Error)
    case dataInfoUnavailable(underlying: Error)
    case cityNotFound(id: Int, underlying: Error)
    case cacheExpired
    case noDataAvailable
    
    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let error):
            return "Failed to download cities: \(error.localizedDescription)"
        case .dataInfoUnavailable(let error):
            return "Data information unavailable: \(error.localizedDescription)"
        case .cityNotFound(let id, let error):
            return "City with ID \(id) not found: \(error.localizedDescription)"
        case .cacheExpired:
            return "Cached data has expired"
        case .noDataAvailable:
            return "No city data available"
        }
    }
    
    // MARK: - User-Friendly Messages
    public var userFriendlyMessage: String {
        switch self {
        case .downloadFailed:
            return "Unable to download city data. Check your internet connection and try again."
        case .dataInfoUnavailable:
            return "City data is temporarily unavailable. Please try again later."
        case .cityNotFound:
            return "The requested city could not be found."
        case .cacheExpired:
            return "City data needs to be refreshed. Please wait while we update."
        case .noDataAvailable:
            return "No city data is currently available. Please try refreshing."
        }
    }
    
    // MARK: - Recovery Suggestions
    public var recoverySuggestion: String {
        switch self {
        case .downloadFailed:
            return "Check your internet connection and try again. You can also use offline data if available."
        case .dataInfoUnavailable:
            return "Please try again in a few moments."
        case .cityNotFound:
            return "Try searching for the city or refresh the city list."
        case .cacheExpired:
            return "The app will automatically refresh the data."
        case .noDataAvailable:
            return "Pull down to refresh or check your internet connection."
        }
    }
    
    // MARK: - Equatable Implementation
    public static func == (lhs: LoadCitiesUseCaseError, rhs: LoadCitiesUseCaseError) -> Bool {
        switch (lhs, rhs) {
        case (.cacheExpired, .cacheExpired),
             (.noDataAvailable, .noDataAvailable):
            return true
        case (.cityNotFound(let lhsId, _), .cityNotFound(let rhsId, _)):
            return lhsId == rhsId
        case (.downloadFailed(let lhsError), .downloadFailed(let rhsError)),
             (.dataInfoUnavailable(let lhsError), .dataInfoUnavailable(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Paginated Load Cities Use Case Protocol
public protocol PaginatedLoadCitiesUseCaseProtocol: Sendable {
    func execute(request: PaginationRequest) async -> Result<PaginatedResult<City>, Error>
    func loadNextPage(currentPage: Int, pageSize: Int) async -> Result<PaginatedResult<City>, Error>
}

// MARK: - Paginated Load Cities Use Case Implementation
public final class PaginatedLoadCitiesUseCase: PaginatedLoadCitiesUseCaseProtocol {

    private let repository: CityRepository

    public init(repository: CityRepository) {
        self.repository = repository
    }

    public func execute(request: PaginationRequest) async -> Result<PaginatedResult<City>, Error> {
        print("📄 Loading cities page \(request.page) (size: \(request.pageSize), offset: \(request.offset))")

        let result = await repository.getCities(request: request)

        switch result {
        case .success(let paginatedResult):
            print("📄 Successfully loaded page \(request.page): \(paginatedResult.items.count) cities")
            return .success(paginatedResult)

        case .failure(let error):
            print("📄 Failed to load page \(request.page): \(error)")
            return .failure(PaginatedLoadCitiesUseCaseError.dataLoadingFailed(underlying: error))
        }
    }

    public func loadNextPage(currentPage: Int, pageSize: Int) async -> Result<PaginatedResult<City>, Error> {
        let nextPageRequest = PaginationRequest(page: currentPage + 1, pageSize: pageSize)
        return await execute(request: nextPageRequest)
    }
}

// MARK: - Paginated Load Cities Use Case Errors
public enum PaginatedLoadCitiesUseCaseError: Error, LocalizedError {
    case dataLoadingFailed(underlying: Error)
    case invalidPaginationRequest
    case noMorePages

    public var errorDescription: String? {
        switch self {
        case .dataLoadingFailed(let error):
            return "Failed to load paginated data: \(error.localizedDescription)"
        case .invalidPaginationRequest:
            return "Invalid pagination request parameters"
        case .noMorePages:
            return "No more pages available"
        }
    }

    public var userFriendlyMessage: String {
        switch self {
        case .dataLoadingFailed:
            return "Unable to load cities. Please check your connection."
        case .invalidPaginationRequest:
            return "Invalid page request. Please try again."
        case .noMorePages:
            return "No more cities to load."
        }
    }
}

// MARK: - Factory
public final class PaginatedLoadCitiesUseCaseFactory {

    public static func create(repository: CityRepository) -> PaginatedLoadCitiesUseCaseProtocol {
        return PaginatedLoadCitiesUseCase(repository: repository)
    }
}

// MARK: - Paginated Search Cities Use Case Protocol
public protocol PaginatedSearchCitiesUseCaseProtocol: Sendable {
    func execute(request: SearchPaginationRequest) async -> Result<PaginatedResult<City>, Error>
    func loadNextSearchPage(query: String, currentPage: Int, pageSize: Int, showOnlyFavorites: Bool) async -> Result<PaginatedResult<City>, Error>
}

// MARK: - Paginated Search Cities Use Case Implementation
public final class PaginatedSearchCitiesUseCase: PaginatedSearchCitiesUseCaseProtocol {

    private let repository: CityRepository

    public init(repository: CityRepository) {
        self.repository = repository
    }

    public func execute(request: SearchPaginationRequest) async -> Result<PaginatedResult<City>, Error> {
        print("🔍📄 Searching '\(request.query)' page \(request.pagination.page) (size: \(request.pagination.pageSize))")

        // Validate query
        guard !request.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(PaginatedSearchCitiesUseCaseError.emptyQuery)
        }

        let result = await repository.searchCities(request: request)

        switch result {
        case .success(let paginatedResult):
            print("🔍📄 Search successful: \(paginatedResult.items.count) cities on page \(request.pagination.page)")
            return .success(paginatedResult)

        case .failure(let error):
            print("🔍📄 Search failed for '\(request.query)' page \(request.pagination.page): \(error)")
            return .failure(PaginatedSearchCitiesUseCaseError.searchFailed(underlying: error))
        }
    }

    public func loadNextSearchPage(
        query: String,
        currentPage: Int,
        pageSize: Int,
        showOnlyFavorites: Bool
    ) async -> Result<PaginatedResult<City>, Error> {
        let nextPageRequest = SearchPaginationRequest(
            query: query,
            pagination: PaginationRequest(page: currentPage + 1, pageSize: pageSize),
            showOnlyFavorites: showOnlyFavorites
        )
        return await execute(request: nextPageRequest)
    }
}

// MARK: - Paginated Search Cities Use Case Errors
public enum PaginatedSearchCitiesUseCaseError: Error, LocalizedError {
    case emptyQuery
    case searchFailed(underlying: Error)
    case invalidSearchRequest
    case noMoreResults

    public var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Search query cannot be empty"
        case .searchFailed(let error):
            return "Search failed: \(error.localizedDescription)"
        case .invalidSearchRequest:
            return "Invalid search request parameters"
        case .noMoreResults:
            return "No more search results available"
        }
    }

    public var userFriendlyMessage: String {
        switch self {
        case .emptyQuery:
            return "Please enter a search term."
        case .searchFailed:
            return "Search failed. Please try again."
        case .invalidSearchRequest:
            return "Invalid search request. Please try again."
        case .noMoreResults:
            return "No more results to load."
        }
    }
}

// MARK: - Factory
public final class PaginatedSearchCitiesUseCaseFactory {

    public static func create(repository: CityRepository) -> PaginatedSearchCitiesUseCaseProtocol {
        return PaginatedSearchCitiesUseCase(repository: repository)
    }
}
