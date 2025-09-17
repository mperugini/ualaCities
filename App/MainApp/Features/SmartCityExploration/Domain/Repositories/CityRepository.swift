//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Repository Protocol (Dependency Inversion Principle)
public protocol CityRepository: Sendable {
    // MARK: - Data Loading
    func downloadAndSaveCities() async -> Result<Void, Error>
    func getAllCities() async -> Result<[City], Error>
    func getCitiesCount() async -> Result<Int, Error>
    
    // MARK: - Search Operations 
    func searchCities(with filter: SearchFilter) async -> Result<SearchResult, Error>
    
    // MARK: - Favorites Management
    func getFavoriteCities() async -> Result<[City], Error>
    func toggleFavorite(_ city: City) async -> Result<City, Error>
    func addToFavorites(_ city: City) async -> Result<City, Error>
    func removeFromFavorites(_ city: City) async -> Result<City, Error>
    func getFavoriteStatus(for cityId: Int) async -> Result<Bool, Error>
    
    // MARK: - Individual City Operations
    func getCity(by id: Int) async -> Result<City?, Error>
    func updateCity(_ city: City) async -> Result<City, Error>
    
    // MARK: - Data Management
    func clearAllData() async -> Result<Void, Error>
    func getDataSourceInfo() async -> Result<DataSourceInfo, Error>
}


// MARK: - Repository Errors
public enum CityRepositoryError: Error, LocalizedError {
    case dataNotFound
    case networkError(Error)
    case storageError(Error)
    case invalidData
    case cityNotFound(id: Int)
    case searchFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .dataNotFound:
            return "City data not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid city data format"
        case .cityNotFound(let id):
            return "City with ID \(id) not found"
        case .searchFailed(let error):
            return "Search failed: \(error.localizedDescription)"
        }
    }
} 
