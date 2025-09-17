//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
public final class SearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var searchText: String = ""
    @Published public var searchResults: [City] = []
    @Published public var isSearching: Bool = false
    @Published public var isSearchLoading: Bool = false
    
    // MARK: - Dependencies
    private let searchUseCase: SearchCitiesUseCaseProtocol
    
    // MARK: - Private Properties
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Callbacks
    public var onSearchResultsChanged: (([City]) -> Void)?
    public var onErrorOccurred: ((Error) -> Void)?
    
    // MARK: - Initialization
    public init(searchUseCase: SearchCitiesUseCaseProtocol) {
        self.searchUseCase = searchUseCase
        setupSearchObservation()
    }
    
    // MARK: - Public Methods
    public func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }
        
        // Cancel previous search
        searchTask?.cancel()
        
        isSearching = true
        isSearchLoading = true
        
        searchTask = Task { @MainActor in
            do {
                let filter = SearchFilter(query: searchText)
                let result = await searchUseCase.execute(with: filter)
                
                switch result {
                case .success(let searchResult):
                    searchResults = searchResult.cities
                    onSearchResultsChanged?(searchResults)
                    
                case .failure(let error):
                    onErrorOccurred?(error)
                }
                
            } 
            
            isSearchLoading = false
        }
    }
    
    public func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
        isSearchLoading = false
        onSearchResultsChanged?([])
    }
    
    // MARK: - Private Methods
    private func setupSearchObservation() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.performSearch()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Factory for Search ViewModel
public final class SearchViewModelFactory {
    
    @MainActor
    public static func create(searchUseCase: SearchCitiesUseCaseProtocol) -> SearchViewModel {
        return SearchViewModel(searchUseCase: searchUseCase)
    }
    
    #if DEBUG
    @MainActor
    public static func createMock() -> SearchViewModel {
        let mockUseCase = MockSearchCitiesUseCase()
        return SearchViewModel(searchUseCase: mockUseCase)
    }
    #endif
}

// MARK: - Mock Search Use Case for Testing
#if DEBUG
@MainActor
private final class MockSearchCitiesUseCase: SearchCitiesUseCaseProtocol, @unchecked Sendable {
    
    var mockSearchResults: [City] = []
    var shouldFail = false
    var mockError: Error = SearchError.searchEngineNotInitialized
    var delay: TimeInterval = 0
    
    func execute(with filter: SearchFilter) async -> Result<SearchResult, Error> {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldFail {
            return .failure(mockError)
        }
        
        let searchResult = SearchResult(
            cities: mockSearchResults,
            totalCount: mockSearchResults.count,
            query: filter.query,
            searchTime: 0.1
        )
        
        return .success(searchResult)
    }
}
#endif
