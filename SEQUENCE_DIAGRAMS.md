# ualaCities - Sequence Diagrams

Este documento contiene los diagramas de secuencia que muestran los flujos de interacción en el proyecto SmartCityExploration.

## 🚀 App Launch & Initial Data Load

```mermaid
sequenceDiagram
    participant U as User
    participant V as CitySearchView
    participant VM as CitySearchViewModel
    participant LUC as LoadCitiesUseCase
    participant REPO as CityRepository
    participant LDS as CoreDataLocalDataSource
    participant RDS as URLSessionRemoteDataSource
    participant CD as Core Data
    participant API as Cities API

    U->>V: Launch App
    V->>VM: .onAppear / .task
    VM->>VM: loadInitialData()
    
    Note over VM: Set isInitialLoading = true
    VM->>LUC: execute()
    
    LUC->>REPO: getDataSourceInfo()
    REPO->>LDS: getCitiesCount() + getLastUpdateDate()
    LDS->>CD: fetch count + UserDefaults
    CD-->>LDS: count + lastUpdated
    LDS-->>REPO: DataSourceInfo
    REPO-->>LUC: DataSourceInfo
    
    alt Cache is valid (< 24h) and has cities
        Note over LUC: Cache hit - use local data
        LUC->>LUC: loadFavorites()
        LUC->>REPO: getFavoriteCities()
        REPO->>LDS: getFavoriteCities()
        LDS->>CD: fetch favorites
        CD-->>LDS: [City] favorites
        LDS-->>REPO: Result<[City]>
        REPO-->>LUC: Result<[City]>
        LUC-->>VM: Success(DataSourceInfo)
        
    else Cache expired or no data
        Note over LUC: Cache miss - download fresh data
        LUC->>REPO: downloadAndSaveCities()
        REPO->>RDS: downloadCities()
        RDS->>API: HTTP GET cities.json
        API-->>RDS: JSON Response
        RDS->>RDS: decode JSON to [City]
        RDS-->>REPO: Result<[City]>
        
        REPO->>LDS: saveCities([City])
        Note over LDS: Preserve existing favorites
        LDS->>CD: batch insert with favorite preservation
        CD-->>LDS: success
        LDS-->>REPO: success
        
        REPO->>LDS: setLastUpdateDate(Date())
        LDS->>CD: UserDefaults update
        CD-->>LDS: success
        LDS-->>REPO: success
        REPO-->>LUC: Result<Void>
        
        LUC->>REPO: getDataSourceInfo()
        REPO-->>LUC: DataSourceInfo (updated)
        LUC-->>VM: Success(DataSourceInfo)
    end
    
    Note over VM: Set isInitialLoading = false
    VM->>V: Update UI with data
    V->>U: Show cities list
```

## 🔍 Smart Search Flow

```mermaid
sequenceDiagram
    participant U as User
    participant V as CitySearchView
    participant VM as CitySearchViewModel
    participant SUC as SearchCitiesUseCase
    participant REPO as CityRepository
    participant LDS as CoreDataLocalDataSource
    participant CD as Core Data

    U->>V: Type "lon" in search
    V->>VM: searchText = "lon"
    
    Note over VM: Debouncing 300ms
    VM->>VM: $searchText publisher
    VM->>VM: debounce(300ms)
    
    Note over VM: After debounce delay
    VM->>VM: performSearch()
    VM->>VM: Cancel previous search task
    
    Note over VM: Set isSearchLoading = true
    VM->>SUC: execute(SearchFilter)
    Note over SUC: SearchFilter(query: "lon", showOnlyFavorites: false)
    
    SUC->>SUC: Validate filter (min length, etc.)
    SUC->>REPO: searchCities(SearchFilter)
    REPO->>LDS: searchCities(SearchFilter)
    
    Note over LDS: Priority search: City name first
    LDS->>CD: fetchRequestForCityNamePrefixSearch("lon")
    CD-->>LDS: [CityEntity] (London, Long Beach, etc.)
    
    Note over LDS: Then search by country
    LDS->>CD: fetchRequestForCountryPrefixSearch("lon", excludingIds)
    CD-->>LDS: [CityEntity] (cities in Longitude countries)
    
    LDS->>LDS: Combine results (city matches + country matches)
    LDS->>LDS: Apply limit (50 default)
    LDS->>LDS: Convert to [City] domain models
    LDS-->>REPO: Result<[City]>
    REPO-->>SUC: Result<[City]>
    
    SUC->>SUC: Create SearchResult with timing
    SUC-->>VM: Result<SearchResult>
    
    Note over VM: Set isSearchLoading = false
    VM->>VM: Update searchResults = cities
    VM->>V: Update UI with search results
    V->>U: Show filtered cities
```

## ⭐ Favorite Toggle Flow

```mermaid
sequenceDiagram
    participant U as User
    participant V as CitySearchView
    participant VM as CitySearchViewModel
    participant FUC as FavoriteCitiesUseCase
    participant REPO as CityRepository
    participant LDS as CoreDataLocalDataSource
    participant CD as Core Data

    U->>V: Tap favorite button on "London"
    V->>VM: toggleFavorite(london)
    
    VM->>FUC: toggleFavorite(london)
    
    alt City is not favorite (adding to favorites)
        FUC->>FUC: Check favorites limit
        FUC->>REPO: getDataSourceInfo()
        REPO-->>FUC: DataSourceInfo (favoritesCount: 45)
        
        Note over FUC: 45 < 100 limit, proceed
        FUC->>REPO: toggleFavorite(london)
        REPO->>LDS: toggleFavorite(london)
        
        LDS->>LDS: performBackgroundTask
        LDS->>CD: fetchRequestById(london.id)
        CD-->>LDS: CityEntity
        
        LDS->>CD: entity.isFavorite = true
        LDS->>CD: entity.updatedAt = Date()
        LDS->>CD: context.save()
        CD-->>LDS: success
        
        LDS->>LDS: entity.toDomain()
        LDS-->>REPO: Result<City> (london with isFavorite: true)
        REPO-->>FUC: Result<City>
        FUC-->>VM: Result<City>
        
    else City is favorite (removing from favorites)
        Note over FUC: No limit check needed for removal
        FUC->>REPO: toggleFavorite(london)
        REPO->>LDS: toggleFavorite(london)
        
        LDS->>LDS: performBackgroundTask
        LDS->>CD: Update entity.isFavorite = false
        LDS->>CD: context.save()
        CD-->>LDS: success
        LDS-->>REPO: Result<City> (london with isFavorite: false)
        REPO-->>FUC: Result<City>
        FUC-->>VM: Result<City>
    end
    
    VM->>VM: updateCityInLists(updatedCity)
    VM->>VM: loadFavorites() // Refresh favorites list
    VM->>VM: refreshDataSourceInfo() // Update counter
    
    Note over VM: Update all affected lists
    VM->>V: Update UI (toggle visual state)
    V->>U: Show updated favorite state
```

## 🔄 Pull to Refresh Flow

```mermaid
sequenceDiagram
    participant U as User
    participant V as CitySearchView
    participant VM as CitySearchViewModel
    participant LUC as LoadCitiesUseCase
    participant REPO as CityRepository
    participant LDS as CoreDataLocalDataSource
    participant RDS as URLSessionRemoteDataSource
    participant CD as Core Data
    participant API as Cities API

    U->>V: Pull down to refresh
    V->>VM: refreshData()
    
    Note over VM: Set isRefreshing = true
    VM->>LUC: forceRefresh()
    
    Note over LUC: Force refresh bypasses cache TTL
    LUC->>REPO: downloadAndSaveCities()
    REPO->>RDS: downloadCities()
    RDS->>API: HTTP GET cities.json
    API-->>RDS: JSON Response [10000+ cities]
    
    RDS->>RDS: JSON decode to [City]
    RDS-->>REPO: Result<[City]>
    
    Note over REPO: Save with favorite preservation
    REPO->>LDS: saveCities([City])
    
    Note over LDS: Step 1: Save current favorites
    LDS->>CD: fetchRequestForFavorites()
    CD-->>LDS: [CityEntity] current favorites
    LDS->>LDS: Extract favoriteIds Set<Int32>
    
    Note over LDS: Step 2: Clear existing data
    LDS->>CD: NSBatchDeleteRequest(fetchRequest)
    CD-->>LDS: deleted all cities
    
    Note over LDS: Step 3: Batch insert with favorites preserved
    LDS->>LDS: Process cities in batches of 1000
    loop For each batch
        LDS->>CD: Create CityEntity.fromDomain(city)
        alt City was previously favorite
            LDS->>CD: entity.isFavorite = true
            LDS->>CD: entity.updatedAt = Date()
        end
        LDS->>CD: context.save() // Save each batch
        CD-->>LDS: batch saved
    end
    
    LDS-->>REPO: success (all cities saved with favorites preserved)
    
    REPO->>LDS: setLastUpdateDate(Date())
    LDS->>CD: UserDefaults update
    CD-->>LDS: success
    REPO-->>LUC: Result<Void>
    
    LUC->>REPO: getDataSourceInfo()
    REPO-->>LDS: getDataSourceInfo()
    LDS->>CD: getCitiesCount() + getFavoritesCount()
    CD-->>LDS: counts
    LDS-->>REPO: DataSourceInfo (updated counts)
    REPO-->>LUC: DataSourceInfo
    LUC-->>VM: Result<DataSourceInfo>
    
    VM->>VM: loadFavorites() // Reload favorites list
    Note over VM: Set isRefreshing = false
    VM->>V: Update UI with refreshed data
    V->>U: Show latest cities with preserved favorites
```

## 🏗️ Factory Pattern Initialization

```mermaid
sequenceDiagram
    participant APP as AppDelegate
    participant COORD as AppCoordinator
    participant V as CitySearchView
    participant VMF as CitySearchViewModelFactory
    participant RF as CityRepositoryFactory
    participant VM as CitySearchViewModel
    participant UC1 as LoadCitiesUseCase
    participant UC2 as SearchCitiesUseCase
    participant UC3 as FavoriteCitiesUseCase
    participant REPO as CityRepositoryImpl

    APP->>COORD: application didFinishLaunching
    COORD->>COORD: start()
    COORD->>V: createMainViewController()
    
    Note over V: @StateObject initialization
    V->>VMF: CitySearchViewModelFactory.create()
    
    VMF->>RF: CityRepositoryFactory.create()
    RF->>RF: Create CoreDataLocalDataSource()
    RF->>RF: Create URLSessionRemoteDataSource()
    RF->>REPO: CityRepositoryImpl(localDS, remoteDS)
    RF-->>VMF: CityRepository
    
    VMF->>UC1: LoadCitiesUseCase(repository)
    VMF->>UC2: SearchCitiesUseCase(repository)
    VMF->>UC3: FavoriteCitiesUseCase(repository)
    
    VMF->>VM: CitySearchViewModel(useCases...)
    VMF-->>V: CitySearchViewModel
    
    Note over V: View ready with all dependencies
    V-->>COORD: UIHostingController
    COORD->>COORD: Present in UINavigationController
```

## 🧪 Testing Flow with Mocks

```mermaid
sequenceDiagram
    participant TEST as XCTestCase
    participant VM as CitySearchViewModel
    participant MOCK1 as MockLoadCitiesUseCase
    participant MOCK2 as MockSearchCitiesUseCase
    participant MOCK3 as MockFavoriteCitiesUseCase

    Note over TEST: setUp() - MainActor.assumeIsolated
    TEST->>MOCK1: MockLoadCitiesUseCase()
    TEST->>MOCK2: MockSearchCitiesUseCase()
    TEST->>MOCK3: MockFavoriteCitiesUseCase()
    
    TEST->>VM: CitySearchViewModel(mocks...)
    
    Note over TEST: Configure mock responses
    TEST->>MOCK1: mockDataInfo = DataSourceInfo(...)
    TEST->>MOCK2: mockCities = [testCities]
    TEST->>MOCK3: mockFavorites = [favoriteCities]
    
    Note over TEST: Execute test
    TEST->>VM: loadInitialData()
    VM->>MOCK1: execute()
    MOCK1-->>VM: Success(mockDataInfo)
    
    VM->>MOCK3: getFavorites()
    MOCK3-->>VM: Success(mockFavorites)
    
    Note over VM: Update @Published properties
    VM->>VM: dataSourceInfo = mockDataInfo
    VM->>VM: favorites = mockFavorites
    VM->>VM: isLoading = false
    
    TEST->>TEST: Assertions
    TEST->>VM: Assert dataSourceInfo != nil
    TEST->>VM: Assert favorites.count == expected
    TEST->>VM: Assert !isLoading
    TEST->>VM: Assert !showError
```

## 🎯 Search Priority Algorithm Flow

```mermaid
sequenceDiagram
    participant U as User
    participant VM as CitySearchViewModel
    participant LDS as CoreDataLocalDataSource
    participant CD as Core Data

    Note over U: User types "A"
    U->>VM: searchText = "A"
    VM->>LDS: searchCities(filter: "A")
    
    Note over LDS: Step 1: Search by city name first
    LDS->>LDS: normalizeQuery("A") -> "a"
    LDS->>CD: fetchRequestForCityNamePrefixSearch("a", limit: 50)
    Note over CD: WHERE searchableText BEGINSWITH[c] "a"
    CD-->>LDS: [Alabama, Anchorage, Austin, ...] (30 cities)
    
    Note over LDS: Step 2: Calculate remaining limit
    LDS->>LDS: remainingLimit = 50 - 30 = 20
    
    Note over LDS: Step 3: Search by country (excluding found cities)
    LDS->>LDS: foundIds = [Alabama.id, Anchorage.id, ...]
    LDS->>CD: fetchRequestForCountryPrefixSearch("a", excludingIds: foundIds, limit: 20)
    Note over CD: WHERE country BEGINSWITH[c] "a" AND id NOT IN foundIds
    CD-->>LDS: [Sydney,AU], [Melbourne,AU], [ÁLAVA,ES] (20 cities)
    
    Note over LDS: Step 4: Combine results with priority
    LDS->>LDS: result = cityMatches + countryMatches
    LDS->>LDS: Convert [CityEntity] -> [City]
    LDS-->>VM: [Alabama, Anchorage, Austin, ..., Sydney,AU, Melbourne,AU, ÁLAVA,ES]
    
    Note over VM: City name matches appear first, then country matches
    VM->>U: Display prioritized results
```

## 🔗 Unicode Normalization Flow

```mermaid
sequenceDiagram
    participant U as User
    participant VM as CitySearchViewModel
    participant LDS as CoreDataLocalDataSource
    participant NORM as String.folding()

    Note over U: User types "Á" (with accent)
    U->>VM: searchText = "Á"
    VM->>LDS: searchCities(filter: "Á")
    
    Note over LDS: Normalize query for consistent search
    LDS->>NORM: normalizeQuery("Á")
    NORM->>NORM: precomposedStringWithCanonicalMapping
    NORM->>NORM: folding(diacriticInsensitive, caseInsensitive)
    NORM-->>LDS: "a" (normalized)
    
    Note over LDS: Search with normalized query
    LDS->>LDS: Search database with "a"
    Note over LDS: Database searchableText already normalized during insert
    
    Note over LDS: Results include both accented and non-accented matches
    LDS-->>VM: [Alabama, ÁLAVA, Anchorage, ...] (bidirectional match)
    
    Note over VM: Both "A" and "Á" find same results
    VM->>U: Display all matching cities regardless of accent input
```

## 🚨 Error Handling Flow

```mermaid
sequenceDiagram
    participant U as User
    participant VM as CitySearchViewModel
    participant LUC as LoadCitiesUseCase
    participant REPO as CityRepository
    participant RDS as URLSessionRemoteDataSource
    participant API as Cities API

    U->>VM: Pull to refresh (no internet)
    VM->>LUC: forceRefresh()
    LUC->>REPO: downloadAndSaveCities()
    REPO->>RDS: downloadCities()
    RDS->>API: HTTP GET (network unavailable)
    API-->>RDS: Network Error
    
    RDS->>RDS: Map URLError to NetworkError
    RDS-->>REPO: Failure(NetworkError.noConnection)
    REPO-->>LUC: Failure(CityRepositoryError.networkError)
    
    Note over LUC: Fallback to cached data
    LUC->>REPO: getDataSourceInfo()
    REPO-->>LUC: Success(cachedDataInfo)
    
    alt Has cached data
        LUC-->>VM: Success(cachedDataInfo) // Use stale data
        Note over VM: Show cached data with subtle indicator
        VM->>U: Display cached cities (maybe show "offline" indicator)
        
    else No cached data
        LUC-->>VM: Failure(LoadCitiesUseCaseError.downloadFailed)
        VM->>VM: showError = true
        VM->>VM: errorMessage = user-friendly message
        VM->>U: Show error alert with retry option
    end
```

---

## 📋 Sequence Diagrams Summary

### Key Interaction Patterns

1. **Async/Await Flow**: All async operations use Swift concurrency patterns
2. **MainActor Isolation**: UI updates are guaranteed to be on main thread  
3. **Error Handling**: Graceful degradation with fallback to cached data
4. **Performance Optimization**: Debouncing, batch operations, background processing
5. **Data Consistency**: Favorite preservation during refresh operations

### Business Logic Flows

1. ** Search**: Priority-based search (city → country) with Unicode normalization
2. **Cache Strategy**: 24-hour TTL with intelligent refresh logic
3. **Favorite Management**: Limit enforcement and data consistency
4. **State Management**: Reactive UI updates with @Published properties

### Testing Strategy

1. **Mock Injection**: Isolated testing with controllable mock responses
2. **MainActor Testing**: Proper concurrency handling in test environment
3. **State Verification**: Assert on ViewModel published properties
4. **Async Testing**: Proper async/await testing patterns
