//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import CoreData

@objc(CityEntity)
public class CityEntity: NSManagedObject, @unchecked Sendable {
    
}

// MARK: - Domain Conversion
extension CityEntity {
    func toDomain() -> City {
        City(
            id: Int(self.id),
            name: self.name ?? "",
            country: self.country ?? "",
            coord: Coordinate(
                lon: self.longitude,
                lat: self.latitude
            ),
            isFavorite: self.isFavorite
        )
    }
    
    static func fromDomain(_ city: City, in context: NSManagedObjectContext) -> CityEntity {
        let entity = CityEntity(context: context)

        entity.setPrimitiveValue(Int32(city.id), forKey: "id")
        entity.setPrimitiveValue(city.name, forKey: "name")
        entity.setPrimitiveValue(city.country, forKey: "country")
        entity.setPrimitiveValue(city.coord.lon, forKey: "longitude")
        entity.setPrimitiveValue(city.coord.lat, forKey: "latitude")
        entity.setPrimitiveValue(city.isFavorite, forKey: "isFavorite")
        
        let now = Date()
        entity.setPrimitiveValue(now, forKey: "createdAt")
        entity.setPrimitiveValue(now, forKey: "updatedAt")
        
        // Set computed properties for search optimization
        entity.updateComputedProperties()
        
        return entity
    }
    
    func updateFromDomain(_ city: City) {
        self.setPrimitiveValue(Int32(city.id), forKey: "id")
        self.setPrimitiveValue(city.name, forKey: "name")
        self.setPrimitiveValue(city.country, forKey: "country")
        self.setPrimitiveValue(city.coord.lon, forKey: "longitude")
        self.setPrimitiveValue(city.coord.lat, forKey: "latitude")
        self.setPrimitiveValue(city.isFavorite, forKey: "isFavorite")
        self.setPrimitiveValue(Date(), forKey: "updatedAt")
        
        updateComputedProperties()
    }
    
    // MARK: - Computed Properties Update
    private func updateComputedProperties() {
        var cityName: String = ""
        var countryName: String = ""
        
        if let name = self.primitiveValue(forKey: "name") as? String {
            cityName = name
        } else if let name = self.name {
            cityName = name
        }
        
        if let country = self.primitiveValue(forKey: "country") as? String {
            countryName = country
        } else if let country = self.country {
            countryName = country
        }
        
        if cityName.isEmpty && countryName.isEmpty {
            self.setPrimitiveValue("Unknown City, Unknown Country", forKey: "displayName")
            let normalizedUnknown = "unknown city unknown country"
                .precomposedStringWithCanonicalMapping
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            self.setPrimitiveValue(normalizedUnknown, forKey: "searchableText")
        } else {
            self.setPrimitiveValue("\(cityName), \(countryName)", forKey: "displayName")
            let normalizedText = "\(cityName) \(countryName)"
                .precomposedStringWithCanonicalMapping
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            
            self.setPrimitiveValue(normalizedText, forKey: "searchableText")
        }
    }
}
