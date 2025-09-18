//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import CoreData

extension CityEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CityEntity> {
        return NSFetchRequest<CityEntity>(entityName: "CityEntity")
    }
    
    @NSManaged public var id: Int32
    @NSManaged public var name: String?
    @NSManaged public var country: String?
    @NSManaged public var longitude: Double
    @NSManaged public var latitude: Double
    @NSManaged public var isFavorite: Bool
    @NSManaged public var searchableText: String?
    @NSManaged public var displayName: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

// MARK: - Identifiable
extension CityEntity: Identifiable {
    
}

// MARK: - Fetch Request Builders
extension CityEntity {
    
    // MARK: - Helper for consistent query normalization
    private static func normalizeQuery(_ query: String) -> String {
        return query
            .precomposedStringWithCanonicalMapping
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
    
    // MARK: - Optimized Search Queries with Priority Sorting
    static func fetchRequestForPrefixSearch(query: String, limit: Int = 1000) -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()
        
        // Normalize query using consistent Unicode normalization
        let normalizedQuery = normalizeQuery(query)
        
        // Search in both city name (searchableText) and country
        let cityPredicate = NSPredicate(format: "searchableText BEGINSWITH[c] %@", normalizedQuery)
        let countryPredicate = NSPredicate(format: "country BEGINSWITH[c] %@", normalizedQuery)
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [cityPredicate, countryPredicate])
        request.predicate = predicate
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        
        request.fetchLimit = limit
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    // MARK: - Separate fetch requests for priority sorting
    static func fetchRequestForCityNamePrefixSearch(query: String, limit: Int = 1000) -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()
        
        let normalizedQuery = normalizeQuery(query)
        request.predicate = NSPredicate(format: "searchableText BEGINSWITH[c] %@", normalizedQuery)
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        
        request.fetchLimit = limit
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    static func fetchRequestForCountryPrefixSearch(query: String, excludingIds: [Int32], limit: Int = 1000) -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()
        
        let normalizedQuery = normalizeQuery(query)
        let countryPredicate = NSPredicate(format: "country BEGINSWITH[c] %@", normalizedQuery)
        
        // Exclude cities already found by city name search to avoid duplicates
        if !excludingIds.isEmpty {
            let excludePredicate = NSPredicate(format: "NOT (id IN %@)", excludingIds)
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [countryPredicate, excludePredicate])
        } else {
            request.predicate = countryPredicate
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        
        request.fetchLimit = limit
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    static func fetchRequestForFavorites() -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    static func fetchRequestForFavoritesWithPrefix(query: String, limit: Int = 1000) -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()
        
        // Normalize query using Unicode normalization (special chars)
        let normalizedQuery = normalizeQuery(query)
        let cityPredicate = NSPredicate(format: "searchableText BEGINSWITH[c] %@", normalizedQuery)
        let countryPredicate = NSPredicate(format: "country BEGINSWITH[c] %@", normalizedQuery)
        let searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [cityPredicate, countryPredicate])
        
        let predicates = [
            NSPredicate(format: "isFavorite == YES"),
            searchPredicate
        ]
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        
        request.fetchLimit = limit
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    // MARK: - Separate favorites fetch requests for priority sorting
    static func fetchRequestForFavoritesCityNamePrefix(query: String, limit: Int = 1000) -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()
        
        let normalizedQuery = normalizeQuery(query)
        
        let predicates = [
            NSPredicate(format: "isFavorite == YES"),
            NSPredicate(format: "searchableText BEGINSWITH[c] %@", normalizedQuery)
        ]
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        
        request.fetchLimit = limit
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    static func fetchRequestForFavoritesCountryPrefix(query: String, excludingIds: [Int32], limit: Int = 1000) -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()
        
        let normalizedQuery = normalizeQuery(query)
        let countryPredicate = NSPredicate(format: "country BEGINSWITH[c] %@", normalizedQuery)
        let favoritesPredicate = NSPredicate(format: "isFavorite == YES")
        
        var predicates = [favoritesPredicate, countryPredicate]
        
        // Exclude cities already found by city name search to avoid duplicates
        if !excludingIds.isEmpty {
            let excludePredicate = NSPredicate(format: "NOT (id IN %@)", excludingIds)
            predicates.append(excludePredicate)
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        
        request.fetchLimit = limit
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    static func fetchRequestById(_ id: Int32) -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", id)
        request.fetchLimit = 1
        
        return request
    }

    // MARK: - Generic Filter Support for Pagination
    static func fetchRequestWithFilter(_ filter: SearchFilter) -> NSFetchRequest<CityEntity> {
        let request = fetchRequest()

        var predicates: [NSPredicate] = []

        // Add favorites filter if needed
        if filter.showOnlyFavorites {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        // Add search query filter if provided
        if !filter.query.isEmpty {
            let normalizedQuery = normalizeQuery(filter.query)

            // Search in both searchableText (city + country) and country specifically
            let searchPredicates = [
                NSPredicate(format: "searchableText BEGINSWITH[c] %@", normalizedQuery),
                NSPredicate(format: "country BEGINSWITH[c] %@", normalizedQuery)
            ]

            let searchCompoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: searchPredicates)
            predicates.append(searchCompoundPredicate)
        }

        // Combine all predicates
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // Set sort descriptors
        request.sortDescriptors = [
            NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]

        request.returnsObjectsAsFaults = false

        return request
    }
}
