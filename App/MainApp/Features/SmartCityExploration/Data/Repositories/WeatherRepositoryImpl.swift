//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Weather Repository Implementation (Simplified)
public final class WeatherRepositoryImpl: WeatherRepository {
    
    private let dataSource: WeatherDataSource
    
    // MARK: - Initialization (Dependency Injection)
    public init(dataSource: WeatherDataSource = WeatherDataSourceImpl()) {
        self.dataSource = dataSource
    }
    
    // MARK: - WeatherRepository Implementation
    public func getWeather(for city: City) async -> Result<WeatherInfo, Error> {
        print("WeatherRepository: Getting weather for \(city.name)")
        
        let result = await dataSource.getWeather(for: city)
        
        switch result {
        case .success(let weather):
            print("WeatherRepository: Successfully got weather for \(city.name)")
            return .success(weather)
        case .failure(let error):
            print("WeatherRepository: Failed to get weather for \(city.name): \(error)")
            return .failure(error)
        }
    }
}
