//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Use Case Protocol (Single Responsibility Principle)
public protocol SearchCitiesUseCaseProtocol: Sendable {
    func execute(with filter: SearchFilter) async -> Result<SearchResult, Error>
}

// MARK: - Search Cities Use Case Implementation
public final class SearchCitiesUseCase: SearchCitiesUseCaseProtocol {
    
    private let repository: CityRepository
    
    // MARK: - Initialization (Dependency Injection)
    public init(repository: CityRepository) {
        self.repository = repository
    }
    
    // MARK: - Business Logic Implementation
    public func execute(with filter: SearchFilter) async -> Result<SearchResult, Error> {
        // Business rule validation
        guard filter.isValidQuery else {
            return .failure(SearchUseCaseError.invalidQuery(
                reason: "Query must be between \(SearchConstants.minimumQueryLength) and \(SearchConstants.maximumQueryLength) characters"
            ))
        }
        
        // Handle empty query case
        if filter.isEmpty {
            if filter.showOnlyFavorites {
                // Show only favorites when filter is empty but favorites flag is set
                let favoritesResult = await repository.getFavoriteCities()
                
                switch favoritesResult {
                case .success(let cities):
                    let searchResult = SearchResult(
                        cities: cities,
                        totalCount: cities.count,
                        query: "",
                        searchTime: 0
                    )
                    return .success(searchResult)
                    
                case .failure(let error):
                    return .failure(SearchUseCaseError.searchFailed(error))
                }
            } else {
                // Return empty result for empty query without favorites
                let emptyResult = SearchResult(cities: [], totalCount: 0, query: "", searchTime: 0)
                return .success(emptyResult)
            }
        }
        
        // Perform the search
        return await repository.searchCities(with: filter)
    }
}

// MARK: - Use Case Errors
public enum SearchUseCaseError: Error, LocalizedError, Equatable {
    case invalidQuery(reason: String)
    case queryTooShort(minimum: Int)
    case queryTooLong(maximum: Int)
    case searchFailed(Error)
    case noResults
    
    public var errorDescription: String? {
        switch self {
        case .invalidQuery(let reason):
            return "Invalid search query: \(reason)"
        case .queryTooShort(let minimum):
            return "Search query must be at least \(minimum) characters"
        case .queryTooLong(let maximum):
            return "Search query cannot exceed \(maximum) characters"
        case .searchFailed(let error):
            return "Search failed: \(error.localizedDescription)"
        case .noResults:
            return "No cities found matching your search"
        }
    }
    
    // MARK: - User-Friendly Messages
    public var userFriendlyMessage: String {
        switch self {
        case .invalidQuery:
            return "Please enter a valid search term"
        case .queryTooShort(let minimum):
            return "Enter at least \(minimum) character\(minimum > 1 ? "s" : "") to search"
        case .queryTooLong:
            return "Search term is too long. Please shorten it"
        case .searchFailed:
            return "Search is temporarily unavailable. Please try again"
        case .noResults:
            return "No cities found. Try a different search term"
        }
    }
    
    // MARK: - Equatable Implementation
    public static func == (lhs: SearchUseCaseError, rhs: SearchUseCaseError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidQuery(let lhsReason), .invalidQuery(let rhsReason)):
            return lhsReason == rhsReason
        case (.queryTooShort(let lhsMin), .queryTooShort(let rhsMin)):
            return lhsMin == rhsMin
        case (.queryTooLong(let lhsMax), .queryTooLong(let rhsMax)):
            return lhsMax == rhsMax
        case (.noResults, .noResults):
            return true
        case (.searchFailed(let lhsError), .searchFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
