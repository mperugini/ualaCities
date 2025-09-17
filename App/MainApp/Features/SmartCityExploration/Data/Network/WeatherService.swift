//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Weather Models
public struct WeatherResponse: Codable {
    let main: MainWeather
    let weather: [Weather]
    let name: String
}

public struct MainWeather: Codable {
    let temp: Double
    let feels_like: Double
    let humidity: Int
    let pressure: Int
}

public struct Weather: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

public struct WeatherInfo: Sendable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let description: String
    let icon: String
    let cityName: String
    
    init(from response: WeatherResponse) {
        self.temperature = response.main.temp
        self.feelsLike = response.main.feels_like
        self.humidity = response.main.humidity
        self.description = response.weather.first?.description ?? ""
        self.icon = response.weather.first?.icon ?? ""
        self.cityName = response.name
    }
    
    init(temperature: Double, feelsLike: Double, humidity: Int, description: String, icon: String, cityName: String) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.description = description
        self.icon = icon
        self.cityName = cityName
    }
}

// MARK: - Weather Service Protocol
public protocol WeatherServiceProtocol: Sendable {
    func getWeather(for city: City) async -> Result<WeatherInfo, Error>
}

// MARK: - Weather Service Implementation
public actor WeatherService: WeatherServiceProtocol {
    
    // ESTO NUNCA, PERO NUNCA debe hacerse aca, las apikeys van en el servidor
    private let apiKey = "0744d45e3c1fa4d96a2dee8eb4e43a63"
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    
    public init() {}
    
    public func getWeather(for city: City) async -> Result<WeatherInfo, Error> {
        let urlString = "\(baseURL)?lat=\(city.coord.lat)&lon=\(city.coord.lon)&appid=\(apiKey)&units=metric&lang=en"
        
        guard let url = URL(string: urlString) else {
            return .failure(WeatherError.invalidURL)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(WeatherError.invalidResponse)
            }
            
            guard httpResponse.statusCode == 200 else {
                return .failure(WeatherError.serverError(httpResponse.statusCode))
            }
            
            let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
            let weatherInfo = WeatherInfo(from: weatherResponse)
            
            return .success(weatherInfo)
        } catch {
            return .failure(WeatherError.networkError(error))
        }
    }
}

// MARK: - Weather Errors
public enum WeatherError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .serverError(let code):
            return "Error del servidor: \(code)"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        }
    }
} 
