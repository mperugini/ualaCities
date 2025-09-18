//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation


public protocol SearchCitiesUseCaseProtocol: Sendable {
    func execute(with filter: SearchFilter) async -> Result<SearchResult, Error>
}

// MARK: - Search Cities Use Case Implementation
public final class SearchCitiesUseCase: SearchCitiesUseCaseProtocol {
    
    private let repository: CityRepository
    
    // MARK: - Initialization 
    public init(repository: CityRepository) {
        self.repository = repository
    }

    // MARK: - Use Case Implementation
    public func execute(with filter: SearchFilter) async -> Result<SearchResult, Error> {
        // Validate search filter
        guard filter.isValidQuery else {
            return .failure(SearchUseCaseError.invalidQuery(reason: "Empty or invalid query"))
        }

        if filter.query.count < 2 {
            return .failure(SearchUseCaseError.queryTooShort(minimum: 2))
        }

        if filter.query.count > 50 {
            return .failure(SearchUseCaseError.queryTooLong(maximum: 50))
        }
        
        let searchRequest = SearchPaginationRequest(
            query: filter.query,
            pagination: PaginationRequest(page: 0, pageSize: filter.limit ?? SearchConstants.defaultResultLimit),
            showOnlyFavorites: filter.showOnlyFavorites
        )

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await repository.searchCities(request: searchRequest)
        let searchTime = CFAbsoluteTimeGetCurrent() - startTime

        switch result {
        case .success(let paginatedResult):
            if paginatedResult.items.isEmpty {
                return .failure(SearchUseCaseError.noResults)
            }

            let searchResult = SearchResult(
                cities: paginatedResult.items,
                totalCount: paginatedResult.items.count,
                query: filter.query,
                searchTime: searchTime
            )
            return .success(searchResult)

        case .failure(let error):
            return .failure(SearchUseCaseError.searchFailed(error))
        }
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
