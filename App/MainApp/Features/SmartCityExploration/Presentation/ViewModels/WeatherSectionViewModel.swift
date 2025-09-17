//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import Combine

// MARK: - Weather Section View Model
@MainActor
public final class WeatherSectionViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI State)
    @Published public var weatherInfo: WeatherInfo?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var hasError = false
    
    // MARK: - Dependencies (Dependency Injection)
    private let loadWeatherUseCase: LoadWeatherUseCaseProtocol
    
    // MARK: - Initialization
    public init(loadWeatherUseCase: LoadWeatherUseCaseProtocol = LoadWeatherUseCase()) {
        self.loadWeatherUseCase = loadWeatherUseCase
    }
    
    // MARK: - Business Logic Methods
    public func loadWeather(for city: City) async {
        isLoading = true
        hasError = false
        errorMessage = nil
        
        let result = await loadWeatherUseCase.execute(for: city)
        
        switch result {
        case .success(let weather):
            weatherInfo = weather
            
        case .failure(let error):
            hasError = true
            
            // Use user-friendly error messages if available
            if let weatherError = error as? LoadWeatherUseCaseError {
                errorMessage = weatherError.userFriendlyMessage
            } else {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    // MARK: - UI Helper Methods
    public func retry(for city: City) async {
        await loadWeather(for: city)
    }
    
    public func clearError() {
        hasError = false
        errorMessage = nil
    }
    
    // MARK: - Computed Properties for UI
    public var hasWeatherData: Bool {
        weatherInfo != nil
    }
    
    public var shouldShowError: Bool {
        hasError && !isLoading
    }
    
    public var shouldShowContent: Bool {
        hasWeatherData && !isLoading && !hasError
    }
    
    public var shouldShowLoading: Bool {
        isLoading
    }
}