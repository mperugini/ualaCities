//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import SwiftUI
@preconcurrency import Combine

// MARK: - City Search View Model

@MainActor
public final class CitySearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var searchText: String = ""
    @Published public var cities: [City] = []
    @Published public var favorites: [City] = []
    @Published public var isLoading = false
    @Published public var showOnlyFavorites = false
    @Published public var errorMessage: String?
    @Published public var showError = false
    @Published public var dataSourceInfo: DataSourceInfo?
    
    // MARK: - Search State
    @Published public var searchResults: [City] = []
    public var hasSearchResults: Bool { !searchResults.isEmpty }
    public var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var displayedCities: [City] {
        if isSearching {
            return searchResults
        } else if showOnlyFavorites {
            return favorites
        } else {
            return cities
        }
    }
    
    // MARK: - Loading States
    @Published public var isInitialLoading = false
    @Published public var isRefreshing = false
    @Published public var isSearchLoading = false

    // MARK: - Infinite Scroll State 
    @Published public var isLoadingNextPage = false
    @Published public var currentPage = 0
    @Published public var canLoadMore = true
    public let maxPages = 15
    private let pageSize = PaginationConstants.defaultPageSize

    // MARK: - Search Pagination State
    @Published public var currentSearchPage = 0
    @Published public var canLoadMoreSearch = true
    private var lastSearchQuery = ""
    private var lastSuccessfulResults: [City] = []
    
    // MARK: - Dependencies (Dependency Injection)
    private let loadCitiesUseCase: LoadCitiesUseCaseProtocol
    private let paginatedSearchUseCase: PaginatedSearchCitiesUseCaseProtocol
    private let favoriteCitiesUseCase: FavoriteCitiesUseCaseProtocol
    
    // MARK: - Private Properties
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadMoreCheck: Date = .distantPast
    
    // MARK: - Initialization
    public init(
        loadCitiesUseCase: LoadCitiesUseCaseProtocol,
        paginatedSearchUseCase: PaginatedSearchCitiesUseCaseProtocol,
        favoriteCitiesUseCase: FavoriteCitiesUseCaseProtocol
    ) {
        self.loadCitiesUseCase = loadCitiesUseCase
        self.paginatedSearchUseCase = paginatedSearchUseCase
        self.favoriteCitiesUseCase = favoriteCitiesUseCase
        
        setupSearchObservation()
    }
    
    deinit {
        searchTask?.cancel()
    }
    
    // MARK: - Public Methods
    public func loadInitialData() async {
        guard !isInitialLoading else { return }
        
        isInitialLoading = true
        isLoading = true
        
        await performDataLoad()
        
        isInitialLoading = false
        isLoading = false
    }
    
    public func refreshData() async {
        guard !isRefreshing else { return }

        isRefreshing = true

        let result = await loadCitiesUseCase.forceRefresh()

        switch result {
        case .success(let info):
            dataSourceInfo = info

            // Reset pagination state on refresh
            currentPage = 0
            canLoadMore = true
            cities.removeAll()

            // Load first page after refresh
            await loadNextPage()

            await loadFavorites()
            clearError()

        case .failure(let error):
            showError(error.localizedDescription)
        }

        isRefreshing = false
    }
    
    public func toggleFavorite(_ city: City) async {
        let result = await favoriteCitiesUseCase.toggleFavorite(city)
        
        switch result {
        case .success(let updatedCity):
            updateCityInLists(updatedCity)
            await loadFavorites() // Refresh favorites list
            await refreshDataSourceInfo() // Update favorites count in UI
            clearError()
            
        case .failure(let error):
            if let favError = error as? FavoritesUseCaseError {
                showError(favError.userFriendlyMessage)
            } else {
                showError(error.localizedDescription)
            }
        }
    }
    
    public func performSearch() async {
        // Cancel any existing search
        searchTask?.cancel()

        searchTask = Task { @MainActor in
            let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedQuery.isEmpty {
                searchResults = []
                lastSuccessfulResults = []
                return
            }

            // Prevent redundant searches for the same query when we already have results < pageSize
            if trimmedQuery == lastSearchQuery &&
               !searchResults.isEmpty &&
               searchResults.count < pageSize &&
               !canLoadMoreSearch {
                return
            }
            
            // Reset search pagination for new query
            if lastSearchQuery != trimmedQuery {
                currentSearchPage = 0
                canLoadMoreSearch = true
                searchResults.removeAll()
                lastSuccessfulResults.removeAll()
                lastSearchQuery = trimmedQuery
            }

            await performPaginatedSearch(query: trimmedQuery, isInitialSearch: true)
        }
    }

    private func performPaginatedSearch(query: String, isInitialSearch: Bool) async {
        if isInitialSearch {
            isSearchLoading = true
        } else {
            isLoadingNextPage = true
        }

        let request = SearchPaginationRequest(
            query: query,
            pagination: PaginationRequest(page: currentSearchPage, pageSize: pageSize),
            showOnlyFavorites: showOnlyFavorites
        )

        let result = await paginatedSearchUseCase.execute(request: request)

        switch result {
        case .success(let paginatedResult):
            if !Task.isCancelled {
                if isInitialSearch {
                    searchResults = paginatedResult.items
                    // Save successful initial results
                    if !paginatedResult.items.isEmpty {
                        lastSuccessfulResults = paginatedResult.items
                    }
                } else {
                    // Only append if we actually have new items
                    if !paginatedResult.items.isEmpty {
                        searchResults.append(contentsOf: paginatedResult.items)
                        lastSuccessfulResults = searchResults
                    } else {
                        // If we got 0 results on additional page, restore firts results results
                        searchResults = lastSuccessfulResults
                    }
                }

                currentSearchPage += 1
                // Only allow more pages if we got a full page of results AND there are more pages
                canLoadMoreSearch = paginatedResult.hasMorePages &&
                                  currentSearchPage < maxPages &&
                                  paginatedResult.items.count >= pageSize

                clearError()
            }

        case .failure(let error):
                if !Task.isCancelled {
                    searchResults = []
                    if let searchError = error as? PaginatedSearchCitiesUseCaseError {
                        showError(searchError.userFriendlyMessage)
                    } else {
                        showError(error.localizedDescription)
                    }
                }
            }

        isSearchLoading = false
        isLoadingNextPage = false
    }
    
    public func clearSearch() {
        searchText = ""
        searchResults = []
        searchTask?.cancel()
    }
    
    public func toggleFavoritesFilter() {
        showOnlyFavorites.toggle()
        
        // Trigger search if there's a query
        if isSearching {
            Task {
                await performSearch()
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupSearchObservation() {
        // Observe search text changes with debouncing
        $searchText
            .debounce(for: .seconds(SearchConstants.searchDebounceTime), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                Task { @MainActor in
                    await self?.performSearch()
                }
            }
            .store(in: &cancellables)
    }
    
    private func performDataLoad() async {
        let result = await loadCitiesUseCase.execute()

        switch result {
        case .success(let info):
            dataSourceInfo = info

            // Reset pagination state
            currentPage = 0
            canLoadMore = true
            cities.removeAll()

            // Load first page (paginated for better performance)
            await loadNextPage()

            await loadFavorites()
            clearError()

        case .failure(let error):
            if let loadError = error as? LoadCitiesUseCaseError {
                showError(loadError.userFriendlyMessage)
            } else {
                showError(error.localizedDescription)
            }
        }
    }
    
    private func loadFavorites() async {
        let result = await favoriteCitiesUseCase.getFavorites()
        
        switch result {
        case .success(let favoriteCities):
            favorites = favoriteCities
            
        case .failure:
            // Non critical, just log it
            print("Failed to load favorites")
        }
    }
    
    private func updateCityInLists(_ updatedCity: City) {
        // Update in main cities list
        if let index = cities.firstIndex(where: { $0.id == updatedCity.id }) {
            cities[index] = updatedCity
        }
        
        // Update in search results
        if let index = searchResults.firstIndex(where: { $0.id == updatedCity.id }) {
            searchResults[index] = updatedCity
        }
    }
    
    private func refreshDataSourceInfo() async {
        let result = await loadCitiesUseCase.getDataInfo()
        
        switch result {
        case .success(let info):
            dataSourceInfo = info
        case .failure:
            // Keep current info if refresh fail
            break
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func clearError() {
        errorMessage = nil
        showError = false
    }

    // MARK: - Infinite Scroll Methods

    /// Loads the next page of cities (up to maxPages)
    public func loadNextPage() async {
        guard canLoadMore && !isLoadingNextPage && currentPage < maxPages else {
            return
        }

        isLoadingNextPage = true

        // Create pagination request and load the page
        let request = PaginationRequest(page: currentPage, pageSize: pageSize)
        let result = await loadCitiesUseCase.getCities(request: request)

        switch result {
        case .success(let paginatedResult):
            let newCities = paginatedResult.items
            cities.append(contentsOf: newCities)
            currentPage += 1

            // Check if we should stop loading more
            let hasMoreData = paginatedResult.hasMorePages
            let reachedPageLimit = currentPage >= maxPages
            canLoadMore = hasMoreData && !reachedPageLimit


        case .failure(let error):
            showError("Failed to load more cities: \(error.localizedDescription)")
        }

        isLoadingNextPage = false
    }

    /// Checks if we should load more cities when user scrolls near the bottom
    public func checkShouldLoadMore(for city: City) {
        // Debounce to prevent rapid successive calls (e.g., during keyboard dismiss layout changes)
        let now = Date()
        guard now.timeIntervalSince(lastLoadMoreCheck) > 0.5 else {
            return
        }
        lastLoadMoreCheck = now

        if isSearching {
            // Check for search results pagination
            guard let index = searchResults.firstIndex(where: { $0.id == city.id }) else {
                return
            }

            let threshold = max(0, searchResults.count - 10) // Load when 10 items from bottom, but never negative

            // More conservative conditions: only load more if we have at least pageSize results AND user is actually near the bottom
            let isNearBottom = index >= threshold && index >= (searchResults.count - 5) // Must be in last 5 items
            let hasFullPage = searchResults.count >= pageSize
            let shouldLoad = isNearBottom && hasFullPage && canLoadMoreSearch && !isLoadingNextPage

            if shouldLoad {
                Task {
                    await loadNextSearchPage()
                }
            }
        } else {
            // Check for regular cities pagination
            guard let index = cities.firstIndex(where: { $0.id == city.id }) else { return }

            let threshold = max(0, cities.count - 10) // Load when 10 items from bottom, but never negative
            if index >= threshold && canLoadMore && !isLoadingNextPage && cities.count >= 10 {
                Task {
                    await loadNextPage()
                }
            }
        }
    }

    /// Loads the next page of search results
    private func loadNextSearchPage() async {

        // Extra safety: don't load more if the current search results are less than a full page
        let hasFullPage = searchResults.count >= pageSize
        let canReallyLoadMore = canLoadMoreSearch && hasFullPage

        guard canReallyLoadMore && !isLoadingNextPage && !lastSearchQuery.isEmpty else {
            return
        }

        await performPaginatedSearch(query: lastSearchQuery, isInitialSearch: false)
    }

    /// Manually trigger loading more cities (for pull-to-load-more or button)
    public func manualLoadMore() async {
        if isSearching {
            await loadNextSearchPage()
        } else {
            await loadNextPage()
        }
    }
}


// MARK: - Factory for View Model Creation
public final class CitySearchViewModelFactory {
    
    @MainActor
    public static func create() -> CitySearchViewModel {
        let repository = CityRepositoryFactory.create()

        let loadCitiesUseCase = LoadCitiesUseCase(repository: repository)
        let paginatedSearchUseCase = PaginatedSearchCitiesUseCaseFactory.create(repository: repository)
        let favoriteCitiesUseCase = FavoriteCitiesUseCase(repository: repository)

        return CitySearchViewModel(
            loadCitiesUseCase: loadCitiesUseCase,
            paginatedSearchUseCase: paginatedSearchUseCase,
            favoriteCitiesUseCase: favoriteCitiesUseCase
        )
    }
    
    #if DEBUG
    @MainActor
    public static func createMock() -> CitySearchViewModel {
        let repository = CityRepositoryFactory.createMock()

        let loadCitiesUseCase = LoadCitiesUseCase(repository: repository)
        let paginatedSearchUseCase = PaginatedSearchCitiesUseCaseFactory.create(repository: repository)
        let favoriteCitiesUseCase = FavoriteCitiesUseCase(repository: repository)

        return CitySearchViewModel(
            loadCitiesUseCase: loadCitiesUseCase,
            paginatedSearchUseCase: paginatedSearchUseCase,
            favoriteCitiesUseCase: favoriteCitiesUseCase
        )
    }
    #endif
}
