//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Weather Data Source Implementation (Simplified)
public final class WeatherDataSourceImpl: WeatherDataSource {
    
    private let weatherService: WeatherServiceProtocol
    
    // MARK: - Initialization (Dependency Injection)
    public init(weatherService: WeatherServiceProtocol = WeatherService()) {
        self.weatherService = weatherService
    }
    
    // MARK: - WeatherDataSource Implementation
    public func getWeather(for city: City) async -> Result<WeatherInfo, Error> {
        print("WeatherDataSource: Fetching weather for \(city.name)")
        
        let result = await weatherService.getWeather(for: city)
        
        switch result {
        case .success(let weatherInfo):
            print("WeatherDataSource: Successfully fetched weather for \(city.name)")
            return .success(weatherInfo)
            
        case .failure(let error):
            print("WeatherDataSource: Failed to fetch weather for \(city.name): \(error)")
            return .failure(error) // Pass through the original error
        }
    }
}
