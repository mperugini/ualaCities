//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Use Case Protocol (Interface Segregation Principle)
public protocol FavoriteCitiesUseCaseProtocol: Sendable {
    func getFavorites() async -> Result<[City], Error>
    func toggleFavorite(_ city: City) async -> Result<City, Error>
    func addToFavorites(_ city: City) async -> Result<City, Error>
    func removeFromFavorites(_ city: City) async -> Result<City, Error>
    func isFavorite(_ city: City) async -> Result<Bool, Error>
    func getFavoritesCount() async -> Result<Int, Error>
    func searchFavorites(with query: String) async -> Result<[City], Error>
}

// MARK: - Favorite Cities Use Case Implementation
public final class FavoriteCitiesUseCase: FavoriteCitiesUseCaseProtocol {
    
    private let repository: CityRepository
    
    // Business rule: Maximum number of favorites allowed
    private let maxFavoritesLimit: Int
    
    // MARK: - Initialization (Dependency Injection)
    public init(repository: CityRepository, maxFavoritesLimit: Int = 100) {
        self.repository = repository
        self.maxFavoritesLimit = maxFavoritesLimit
    }
    
    // MARK: - Business Logic Implementation
    public func getFavorites() async -> Result<[City], Error> {
        return await repository.getFavoriteCities()
    }
    
    public func toggleFavorite(_ city: City) async -> Result<City, Error> {
        // Business rule: Check if we can add more favorites
        if !city.isFavorite {
            let countResult = await getFavoritesCount()
            
            switch countResult {
            case .success(let count):
                if count >= maxFavoritesLimit {
                    return .failure(FavoritesUseCaseError.favoriteLimitExceeded(limit: maxFavoritesLimit))
                }
            case .failure(let error):
                return .failure(FavoritesUseCaseError.operationFailed(error))
            }
        }
        
        let result = await repository.toggleFavorite(city)
        
        switch result {
        case .success(let updatedCity):
            // Log business event for analytics
            let action = updatedCity.isFavorite ? "added" : "removed"
            print("City '\(updatedCity.displayName)' \(action) to/from favorites")
            return .success(updatedCity)
            
        case .failure(let error):
            return .failure(FavoritesUseCaseError.operationFailed(error))
        }
    }
    
    public func addToFavorites(_ city: City) async -> Result<City, Error> {
        // Business rule: Check if already a favorite
        if city.isFavorite {
            return .failure(FavoritesUseCaseError.alreadyFavorite(city.displayName))
        }
        
        // Business rule: Check favorites limit
        let countResult = await getFavoritesCount()
        
        switch countResult {
        case .success(let count):
            if count >= maxFavoritesLimit {
                return .failure(FavoritesUseCaseError.favoriteLimitExceeded(limit: maxFavoritesLimit))
            }
        case .failure(let error):
            return .failure(FavoritesUseCaseError.operationFailed(error))
        }
        
        let result = await repository.addToFavorites(city)
        
        switch result {
        case .success(let updatedCity):
            print("City '\(updatedCity.displayName)' added to favorites")
            return .success(updatedCity)
            
        case .failure(let error):
            return .failure(FavoritesUseCaseError.operationFailed(error))
        }
    }
    
    public func removeFromFavorites(_ city: City) async -> Result<City, Error> {
        // Business rule: Check if actually a favorite
        if !city.isFavorite {
            return .failure(FavoritesUseCaseError.notFavorite(city.displayName))
        }
        
        let result = await repository.removeFromFavorites(city)
        
        switch result {
        case .success(let updatedCity):
            print("City '\(updatedCity.displayName)' removed from favorites")
            return .success(updatedCity)
            
        case .failure(let error):
            return .failure(FavoritesUseCaseError.operationFailed(error))
        }
    }
    
    public func isFavorite(_ city: City) async -> Result<Bool, Error> {
        let result = await repository.getFavoriteStatus(for: city.id)
        
        switch result {
        case .success(let isFavorite):
            return .success(isFavorite)
        case .failure(let error):
            return .failure(FavoritesUseCaseError.operationFailed(error))
        }
    }
    
    public func getFavoritesCount() async -> Result<Int, Error> {
        let infoResult = await repository.getDataSourceInfo()
        
        switch infoResult {
        case .success(let info):
            return .success(info.favoritesCount)
        case .failure(let error):
            return .failure(FavoritesUseCaseError.operationFailed(error))
        }
    }
    
    public func searchFavorites(with query: String) async -> Result<[City], Error> {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let searchRequest = SearchPaginationRequest(
            query: trimmedQuery,
            pagination: PaginationRequest(page: 0, pageSize: SearchConstants.defaultResultLimit),
            showOnlyFavorites: true
        )

        let searchResult = await repository.searchCities(request: searchRequest)

        switch searchResult {
        case .success(let paginatedResult):
            return .success(paginatedResult.items)
        case .failure(let error):
            return .failure(FavoritesUseCaseError.searchFailed(error))
        }
    }
}

// MARK: - Use Case Errors
public enum FavoritesUseCaseError: Error, LocalizedError, Equatable {
    case favoriteLimitExceeded(limit: Int)
    case alreadyFavorite(String)
    case notFavorite(String)
    case operationFailed(Error)
    case searchFailed(Error)
    case cityNotFound(Int)
    
    public var errorDescription: String? {
        switch self {
        case .favoriteLimitExceeded(let limit):
            return "Cannot exceed \(limit) favorite cities"
        case .alreadyFavorite(let cityName):
            return "'\(cityName)' is already in favorites"
        case .notFavorite(let cityName):
            return "'\(cityName)' is not in favorites"
        case .operationFailed(let error):
            return "Favorites operation failed: \(error.localizedDescription)"
        case .searchFailed(let error):
            return "Favorites search failed: \(error.localizedDescription)"
        case .cityNotFound(let id):
            return "City with ID \(id) not found"
        }
    }
    
    // MARK: - User-Friendly Messages
    public var userFriendlyMessage: String {
        switch self {
        case .favoriteLimitExceeded(let limit):
            return "You can only have up to \(limit) favorite cities. Remove some to add more."
        case .alreadyFavorite(let cityName):
            return "'\(cityName)' is already in your favorites"
        case .notFavorite(let cityName):
            return "'\(cityName)' is not in your favorites"
        case .operationFailed:
            return "Unable to update favorites. Please try again."
        case .searchFailed:
            return "Search in favorites failed. Please try again."
        case .cityNotFound:
            return "City not found. Please refresh and try again."
        }
    }
    
    // MARK: - Equatable Implementation
    public static func == (lhs: FavoritesUseCaseError, rhs: FavoritesUseCaseError) -> Bool {
        switch (lhs, rhs) {
        case (.favoriteLimitExceeded(let lhsLimit), .favoriteLimitExceeded(let rhsLimit)):
            return lhsLimit == rhsLimit
        case (.alreadyFavorite(let lhsName), .alreadyFavorite(let rhsName)):
            return lhsName == rhsName
        case (.notFavorite(let lhsName), .notFavorite(let rhsName)):
            return lhsName == rhsName
        case (.cityNotFound(let lhsId), .cityNotFound(let rhsId)):
            return lhsId == rhsId
        case (.operationFailed(let lhsError), .operationFailed(let rhsError)),
             (.searchFailed(let lhsError), .searchFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
