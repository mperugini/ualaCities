//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Weather Data Source Protocol (Simplified)
public protocol WeatherDataSource: Sendable {
    func getWeather(for city: City) async -> Result<WeatherInfo, Error>
}