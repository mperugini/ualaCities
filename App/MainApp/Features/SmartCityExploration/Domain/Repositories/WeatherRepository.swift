//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Weather Repository Protocol (Domain Layer - Clean Architecture)
public protocol WeatherRepository: Sendable {
    func getWeather(for city: City) async -> Result<WeatherInfo, Error>
}