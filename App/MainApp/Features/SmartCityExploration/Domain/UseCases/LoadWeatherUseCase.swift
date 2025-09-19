//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Load Weather Use Case Protocol (Single Responsibility Principle)
public protocol LoadWeatherUseCaseProtocol: Sendable {
    func execute(for city: City) async -> Result<WeatherInfo, Error>
}

// MARK: - Load Weather Use Case Implementation
public final class LoadWeatherUseCase: LoadWeatherUseCaseProtocol {
    
    private let weatherRepository: WeatherRepository
    
    // MARK: - Initialization (Dependency Injection)
    public init(weatherRepository: WeatherRepository = WeatherRepositoryImpl()) {
        self.weatherRepository = weatherRepository
    }
    
    // MARK: - Business Logic Implementation
    public func execute(for city: City) async -> Result<WeatherInfo, Error> {
        let result = await weatherRepository.getWeather(for: city)

        switch result {
        case .success(let weather):
            return .success(weather)
        case .failure(let error):
            return .failure(LoadWeatherUseCaseError.weatherLoadFailed(cityName: city.name, underlying: error))
        }
    }
}

// MARK: - Load Weather Use Case Errors
public enum LoadWeatherUseCaseError: Error, LocalizedError, Equatable {
    case weatherLoadFailed(cityName: String, underlying: Error)
    case weatherServiceUnavailable
    case invalidCityData
    
    public var errorDescription: String? {
        switch self {
        case .weatherLoadFailed(let cityName, let error):
            return "Failed to load weather for \(cityName): \(error.localizedDescription)"
        case .weatherServiceUnavailable:
            return "Weather service is currently unavailable"
        case .invalidCityData:
            return "Invalid city data provided"
        }
    }
    
    // MARK: - User-Friendly Messages
    public var userFriendlyMessage: String {
        switch self {
        case .weatherLoadFailed:
            return "Unable to load weather data. Please try again later."
        case .weatherServiceUnavailable:
            return "Weather service is temporarily unavailable."
        case .invalidCityData:
            return "Cannot load weather for this city."
        }
    }
    
    // MARK: - Recovery Suggestions
    public var recoverySuggestion: String {
        switch self {
        case .weatherLoadFailed:
            return "Check your internet connection and try again."
        case .weatherServiceUnavailable:
            return "Please try again in a few moments."
        case .invalidCityData:
            return "Try selecting a different city."
        }
    }
    
    // MARK: - Equatable Implementation
    public static func == (lhs: LoadWeatherUseCaseError, rhs: LoadWeatherUseCaseError) -> Bool {
        switch (lhs, rhs) {
        case (.weatherServiceUnavailable, .weatherServiceUnavailable),
             (.invalidCityData, .invalidCityData):
            return true
        case (.weatherLoadFailed(let lhsCity, let lhsError), .weatherLoadFailed(let rhsCity, let rhsError)):
            return lhsCity == rhsCity && lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
