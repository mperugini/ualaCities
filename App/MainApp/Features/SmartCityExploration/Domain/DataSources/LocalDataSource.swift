//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Local Data Source Protocol (Interface Segregation Principle)
public protocol LocalDataSource: Sendable {
    // MARK: - Batch Operations
    func saveCities(_ cities: [City]) async throws
    func clearAllCities() async throws
    func getCitiesCount() async throws -> Int
    
    // MARK: - Operations
    func getCities(offset: Int, limit: Int) async throws -> [City]
    func searchCities(with filter: SearchFilter, offset: Int, limit: Int) async throws -> [City]
    func getSearchResultsCount(with filter: SearchFilter) async throws -> Int
    
    // MARK: - Individual City Operations
    func getCity(by id: Int) async -> Result<City?, Error>
    func updateCity(_ city: City) async throws
    
    // MARK: - Favorites Management
    func getFavoriteCities() async -> Result<[City], Error>
    func toggleFavorite(_ city: City) async throws -> City
    func setFavoriteStatus(_ city: City, isFavorite: Bool) async throws -> City
    func getFavoriteStatus(for cityId: Int) async -> Result<Bool, Error>
    func getFavoritesCount() async throws -> Int
    
    // MARK: - Data Info
    func getLastUpdateDate() async -> Date?
    func setLastUpdateDate(_ date: Date) async throws
}

// MARK: - Remote Data Source Protocol
public protocol RemoteDataSource: Sendable {
    func downloadCities() async -> Result<[City], Error>
    func getDataSourceURL() -> String
} 
