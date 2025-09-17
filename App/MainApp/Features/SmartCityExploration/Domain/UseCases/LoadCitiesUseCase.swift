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