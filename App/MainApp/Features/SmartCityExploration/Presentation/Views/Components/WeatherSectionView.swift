//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import SwiftUI

// MARK: - Weather Section View Component (MVVM Pattern)
public struct WeatherSectionView: View {
    
    let city: City
    
    // MARK: - View Model (MVVM Pattern)
    @StateObject private var viewModel = WeatherSectionViewModel()
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Weather", icon: "cloud.fill")
            
            if viewModel.shouldShowLoading {
                loadingView
            } else if viewModel.shouldShowContent {
                weatherContentView
            } else if viewModel.shouldShowError {
                errorView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .task {
            await viewModel.loadWeather(for: city)
        }
    }
    
    // MARK: - View Components
    private var loadingView: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
            Text("Loading weather...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var weatherContentView: some View {
        VStack(spacing: 12) {
            if let weather = viewModel.weatherInfo {
                InfoRow(
                    title: "Temperature",
                    value: "\(Int(weather.temperature))°C",
                    icon: "thermometer"
                )
                
                InfoRow(
                    title: "Feels Like",
                    value: "\(Int(weather.feelsLike))°C",
                    icon: "thermometer.medium"
                )
                
                InfoRow(
                    title: "Humidity",
                    value: "\(weather.humidity)%",
                    icon: "humidity"
                )
                
                InfoRow(
                    title: "Condition",
                    value: weather.description.capitalized,
                    icon: "cloud"
                )
            }
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 8) {
            Text("Weather data unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry") {
                Task {
                    await viewModel.retry(for: city)
                }
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Preview
#if DEBUG
struct WeatherSectionView_Previews: PreviewProvider {
    static let sampleCity = City(
        id: 12345,
        name: "New York",
        country: "US",
        coord: Coordinate(lon: -74.0060, lat: 40.7128),
        isFavorite: false
    )
    
    static var previews: some View {
        VStack(spacing: 20) {
            WeatherSectionView(city: sampleCity)
            
            WeatherSectionView(city: City(
                id: 54321,
                name: "London",
                country: "GB", 
                coord: Coordinate(lon: -0.1276, lat: 51.5074),
                isFavorite: true
            ))
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Weather Section Component")
    }
}
#endif