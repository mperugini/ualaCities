//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import CoreData

// MARK: - Core Data Local Data Source Implementation
public final class CoreDataLocalDataSource: LocalDataSource {
    
    private let coreDataStack: CoreDataStackProtocol
    
    // MARK: - Initialization (Dependency Injection)
    public init(coreDataStack: CoreDataStackProtocol = CoreDataStack.shared) {
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - Batch Operations
    public func saveCities(_ cities: [City]) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await coreDataStack.performBackgroundTask { context in
            // Save current favorites before clearing data
            let favoritesRequest = CityEntity.fetchRequestForFavorites()
            let currentFavorites = try context.fetch(favoritesRequest)
            let favoriteIds = Set(currentFavorites.map { $0.id })
            
            print("Preserving \(favoriteIds.count) favorites during refresh")
            
            // Clear existing data
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: CityEntity.fetchRequest())
            try context.execute(deleteRequest)
            
            //  Batch insert new cities with preserved favorites
            var processedCities = cities
            let batchSize = 1000
            
            while !processedCities.isEmpty {
                let batchCities = Array(processedCities.prefix(batchSize))
                processedCities.removeFirst(min(batchSize, processedCities.count))
                
                for city in batchCities {
                    let entity = CityEntity.fromDomain(city, in: context)
                    
                    //  Restore favorite status if this city was previously a favorite
                    if favoriteIds.contains(entity.id) {
                        entity.isFavorite = true
                        entity.updatedAt = Date()
                    }
                }
                
                // Save batch (prevent memory issues)
                if context.hasChanges {
                    try context.save()
                }
            }
            
            let restoredCount = cities.filter { favoriteIds.contains(Int32($0.id)) }.count
            print("Restored \(restoredCount) favorites after refresh")
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Saved \(cities.count) cities in \(String(format: "%.2f", timeElapsed))s")
    }
    
    public func clearAllCities() async throws {
        try await coreDataStack.performBackgroundTask { context in
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: CityEntity.fetchRequest())
            try context.execute(deleteRequest)
        }
        
        try await coreDataStack.saveBackgroundContext()
    }
    
    public func getCitiesCount() async throws -> Int {
        return try await coreDataStack.performBackgroundTask { context in
            let request = CityEntity.fetchRequest()
            return try context.count(for: request)
        }
    }
    
    // MARK: - Search Operations (Optimized for Performance)
    public func getAllCities() async -> Result<[City], Error> {
        do {
            let cities = try await coreDataStack.performBackgroundTask { context in
                let request = CityEntity.fetchRequest()
                request.sortDescriptors = [
                    NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
                ]
                request.returnsObjectsAsFaults = false
                
                let entities = try context.fetch(request)
                return entities.map { $0.toDomain() }
            }
            
            return .success(cities)
        } catch {
            return .failure(CoreDataError.fetchFailed(underlying: error))
        }
    }
    
    public func searchCitiesWithPrefix(_ prefix: String, limit: Int) async -> Result<[City], Error> {
        guard !prefix.isEmpty else {
            return await getAllCities()
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let cities = try await coreDataStack.performBackgroundTask { context in
                // First: fetch cities that match by name (searchableText)
                let cityNameRequest = CityEntity.fetchRequestForCityNamePrefixSearch(query: prefix, limit: limit)
                let cityNameEntities = try context.fetch(cityNameRequest)
                let cityNameResults = cityNameEntities.map { $0.toDomain() }
                
                // Get IDs of cities already found to avoid duplicates
                let foundIds = cityNameEntities.map { $0.id }
                
                // Second: fetch cities that match by country (excluding already found ones)
                let remainingLimit = max(0, limit - cityNameResults.count)
                if remainingLimit > 0 {
                    let countryRequest = CityEntity.fetchRequestForCountryPrefixSearch(
                        query: prefix, 
                        excludingIds: foundIds, 
                        limit: remainingLimit
                    )
                    let countryEntities = try context.fetch(countryRequest)
                    let countryResults = countryEntities.map { $0.toDomain() }
                    
                    // Combine results: city name matches first, then country matches
                    return cityNameResults + countryResults
                } else {
                    return cityNameResults
                }
            }
            
            let searchTime = CFAbsoluteTimeGetCurrent() - startTime
            print("Found \(cities.count) cities for '\(prefix)' in \(String(format: "%.4f", searchTime))s (city matches first)")
            
            return .success(cities)
        } catch {
            return .failure(CoreDataError.fetchFailed(underlying: error))
        }
    }
    
    public func searchCities(with filter: SearchFilter) async -> Result<[City], Error> {
       // let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let cities = try await coreDataStack.performBackgroundTask { context in
                let limit = filter.limit ?? SearchConstants.defaultResultLimit
                
                if filter.showOnlyFavorites {
                    if filter.query.isEmpty {
                        let request = CityEntity.fetchRequestForFavorites()
                        let entities = try context.fetch(request)
                        return entities.map { $0.toDomain() }
                    } else {
                        // Priority search for favorites: city name matches first, then country matches
                        let cityNameRequest = CityEntity.fetchRequestForFavoritesCityNamePrefix(
                            query: filter.query,
                            limit: limit
                        )
                        let cityNameEntities = try context.fetch(cityNameRequest)
                        let cityNameResults = cityNameEntities.map { $0.toDomain() }
                        
                        // Get IDs of cities already found to avoid duplicates
                        let foundIds = cityNameEntities.map { $0.id }
                        
                        // fetch favorites that match by country (excluding already found ones)
                        let remainingLimit = max(0, limit - cityNameResults.count)
                        if remainingLimit > 0 {
                            let countryRequest = CityEntity.fetchRequestForFavoritesCountryPrefix(
                                query: filter.query,
                                excludingIds: foundIds,
                                limit: remainingLimit
                            )
                            let countryEntities = try context.fetch(countryRequest)
                            let countryResults = countryEntities.map { $0.toDomain() }
                            
                            // Combine results: city name matches first, then country matches
                            return cityNameResults + countryResults
                        } else {
                            return cityNameResults
                        }
                    }
                } else {
                    if filter.query.isEmpty {
                        let request = CityEntity.fetchRequest()
                        request.sortDescriptors = [
                            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
                        ]
                        request.returnsObjectsAsFaults = false
                        
                        let entities = try context.fetch(request)
                        return entities.map { $0.toDomain() }
                    } else {
                        // city name first, then country matches
                        let cityNameRequest = CityEntity.fetchRequestForCityNamePrefixSearch(
                            query: filter.query,
                            limit: limit
                        )
                        let cityNameEntities = try context.fetch(cityNameRequest)
                        let cityNameResults = cityNameEntities.map { $0.toDomain() }
                        
                        // Get IDs of cities already found to avoid duplicates
                        let foundIds = cityNameEntities.map { $0.id }
                        
                        // fetch cities that match by country (excluding already found)
                        let remainingLimit = max(0, limit - cityNameResults.count)
                        if remainingLimit > 0 {
                            let countryRequest = CityEntity.fetchRequestForCountryPrefixSearch(
                                query: filter.query,
                                excludingIds: foundIds,
                                limit: remainingLimit
                            )
                            let countryEntities = try context.fetch(countryRequest)
                            let countryResults = countryEntities.map { $0.toDomain() }
                            
                            // Combine results: city name matches first, then country matches
                            return cityNameResults + countryResults
                        } else {
                            return cityNameResults
                        }
                    }
                }
            }
            
           // let searchTime = CFAbsoluteTimeGetCurrent() - startTime
            return .success(cities)
        } catch {
            return .failure(CoreDataError.fetchFailed(underlying: error))
        }
    }
    
    // MARK: - Individual City Operations
    public func getCity(by id: Int) async -> Result<City?, Error> {
        do {
            let city = try await coreDataStack.performBackgroundTask { context in
                let request = CityEntity.fetchRequestById(Int32(id))
                let entities = try context.fetch(request)
                return entities.first?.toDomain()
            }
            
            return .success(city)
        } catch {
            return .failure(CoreDataError.fetchFailed(underlying: error))
        }
    }
    
    public func updateCity(_ city: City) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let request = CityEntity.fetchRequestById(Int32(city.id))
            let entities = try context.fetch(request)
            
            if let entity = entities.first {
                entity.updateFromDomain(city)
                entity.updatedAt = Date()
            } else {
                // City doesn't exist, create new one
                _ = CityEntity.fromDomain(city, in: context)
            }
        }
        
        try await coreDataStack.saveBackgroundContext()
    }
    
    // MARK: - Favorites Management
    public func getFavoriteCities() async -> Result<[City], Error> {
        do {
            let cities = try await coreDataStack.performBackgroundTask { context in
                let request = CityEntity.fetchRequestForFavorites()
                let entities = try context.fetch(request)
                return entities.map { $0.toDomain() }
            }
            
            return .success(cities)
        } catch {
            return .failure(CoreDataError.fetchFailed(underlying: error))
        }
    }
    
    public func toggleFavorite(_ city: City) async throws -> City {
        return try await setFavoriteStatus(city, isFavorite: !city.isFavorite)
    }
    
    public func setFavoriteStatus(_ city: City, isFavorite: Bool) async throws -> City {
        let updatedCity = try await coreDataStack.performBackgroundTask { context in
            let request = CityEntity.fetchRequestById(Int32(city.id))
            let entities = try context.fetch(request)
            
            guard let entity = entities.first else {
                throw CoreDataError.invalidEntity
            }
            
            entity.isFavorite = isFavorite
            entity.updatedAt = Date()
            
            // Save the context within the background task
            if context.hasChanges {
                try context.save()
            }
            
            return entity.toDomain()
        }
        
        return updatedCity
    }
    
    public func getFavoriteStatus(for cityId: Int) async -> Result<Bool, Error> {
        do {
            let isFavorite = try await coreDataStack.performBackgroundTask { context in
                let request = CityEntity.fetchRequestById(Int32(cityId))
                request.propertiesToFetch = ["isFavorite"]
                
                let entities = try context.fetch(request)
                return entities.first?.isFavorite ?? false
            }
            
            return .success(isFavorite)
        } catch {
            return .failure(CoreDataError.fetchFailed(underlying: error))
        }
    }
    
    public func getFavoritesCount() async throws -> Int {
        return try await coreDataStack.performBackgroundTask { context in
            let request = CityEntity.fetchRequestForFavorites()
            return try context.count(for: request)
        }
    }
    
    // MARK: - Data Info
    public func getLastUpdateDate() async -> Date? {
        // Store in UserDefaults for simplicity
        let date = UserDefaults.standard.object(forKey: "lastCityDataUpdate") as? Date
        print("UserDefaults lastCityDataUpdate: \(date?.description ?? "nil")")
        return date
    }
    
    public func setLastUpdateDate(_ date: Date) async throws {
        print("Setting lastCityDataUpdate to: \(date)")
        UserDefaults.standard.set(date, forKey: "lastCityDataUpdate")
    }
}

// MARK: - Performance Optimization Extensions
extension CoreDataLocalDataSource {
    
    // MARK: - Batch Update for Favorites (Performance optimization)
    public func batchUpdateFavorites(_ cityIds: [Int], isFavorite: Bool) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let request = NSBatchUpdateRequest(entityName: "CityEntity")
            let int32Ids = cityIds.map { Int32($0) }
            request.predicate = NSPredicate(format: "id IN %@", int32Ids)
            request.propertiesToUpdate = [
                "isFavorite": NSNumber(value: isFavorite),
                "updatedAt": Date()
            ]
            request.resultType = .updatedObjectsCountResultType
            
            try context.execute(request)
        }
        
        try await coreDataStack.saveBackgroundContext()
    }
}
