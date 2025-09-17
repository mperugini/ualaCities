//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Domain Entity
public struct City: Sendable, Hashable, Identifiable, Codable {
    public let id: Int
    public let name: String
    public let country: String
    public let coord: Coordinate
    public var isFavorite: Bool
    
    public init(id: Int, name: String, country: String, coord: Coordinate, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.country = country
        self.coord = coord
        self.isFavorite = isFavorite
    }
    
    // MARK: - Computed Properties for Search and Display
    public var displayName: String {
        "\(name), \(country)"
    }

    public var searchableText: String {
        "\(name) \(country)"
            .precomposedStringWithCanonicalMapping
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
    
    
    // MARK: - Hashable & Identifiable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: City, rhs: City) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Codable Keys (matching API format)
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case country
        case coord
        case isFavorite
    }
    
    // MARK: - Custom Decoding (isFavorite defaults to false for API data)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.country = try container.decode(String.self, forKey: .country)
        self.coord = try container.decode(Coordinate.self, forKey: .coord)
        
        // isFavorite defaults to false when decoding from API (not present in JSON)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

// MARK: - Search Extensions
extension City {
    /// Verifica si la ciudad coincide con el prefijo dado
    /// - Parameters:
    ///   - prefix: El prefijo a buscar
    ///   - searchInCountry: Si debe buscar también en el país (por defecto true)
    /// - Returns: true si la ciudad coincide con el prefijo
    public func matchesPrefix(_ prefix: String, searchInCountry: Bool = true) -> Bool {
        // Normalize prefix with Unicode consistency for accent-insensitive search
        let normalizedPrefix = prefix
            .precomposedStringWithCanonicalMapping
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        
        if searchInCountry {
            // Search in searchableText (city + country) OR in country only
            // This replicates Core Data logic with priority
            let normalizedCountry = country
                .precomposedStringWithCanonicalMapping
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            
            return searchableText.hasPrefix(normalizedPrefix) || 
                   normalizedCountry.hasPrefix(normalizedPrefix)
        } else {
            // Search only in searchableText (which includes city + country)
            return searchableText.hasPrefix(normalizedPrefix)
        }
    }
}
