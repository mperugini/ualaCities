//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import SwiftUI
import MapKit

// MARK: - City Detail View (Challenge Requirements Implementation)
public struct CityDetailView: View {
    
    let city: City
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Computed Properties for Map
    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: city.coord.lat,
                longitude: city.coord.lon
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
    
    private var cityAnnotations: [CityAnnotation] {
        [CityAnnotation(city: city)]
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24, pinnedViews: []) {
                    // Header with city info
                    cityHeader
                    // Location details
                    locationSection
                    // Weather information (additional data source)
                    WeatherSectionView(city: city)
                    // Map preview
                    mapPreview
                    // Additional information
                    additionalInfoSection
                }
                .padding()
            }
            .navigationTitle("City Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - City Header
    private var cityHeader: some View {
        VStack(spacing: 16) {
            // Country flag placeholder (would use actual flag in production)
            Text(flagEmoji(for: city.country))
                .font(.system(size: 60))
            
            VStack(spacing: 8) {
                Text(city.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(city.country)
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                if city.isFavorite {
                    Label("Favorite", systemImage: "heart.fill")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Location Section
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Location", icon: "location.fill")
            
            VStack(spacing: 12) {
                InfoRow(
                    title: "Coordinates",
                    value: city.coord.displayString,
                    icon: "location.circle"
                )
                
                InfoRow(
                    title: "Latitude",
                    value: String(format: "%.6f°", city.coord.lat),
                    icon: "arrow.up.down"
                )
                
                InfoRow(
                    title: "Longitude",
                    value: String(format: "%.6f°", city.coord.lon),
                    icon: "arrow.left.right"
                )
                
                InfoRow(
                    title: "City ID",
                    value: "\(city.id)",
                    icon: "number"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    
    // MARK: - Map Preview
    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Map Location", icon: "map.fill")
            
            Map(position: .constant(.region(mapRegion))) {
                Annotation(city.name, coordinate: CLLocationCoordinate2D(
                    latitude: city.coord.lat, 
                    longitude: city.coord.lon
                )) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
            .disabled(true) // Make it non-interactive in detail view
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Additional Info Section
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Additional Information", icon: "info.circle.fill")
            
            VStack(spacing: 12) {
                InfoRow(
                    title: "Display Name",
                    value: city.displayName,
                    icon: "textformat"
                )
                
                InfoRow(
                    title: "Country Code",
                    value: city.country,
                    icon: "flag"
                )
                
                InfoRow(
                    title: "Favorite Status",
                    value: city.isFavorite ? "Yes" : "No",
                    icon: city.isFavorite ? "heart.fill" : "heart"
                )
                
                // Time zone info (calculated from longitude)
                InfoRow(
                    title: "Approx. Time Zone",
                    value: timeZoneInfo,
                    icon: "clock"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Computed Properties
    private var timeZoneInfo: String {
        let offsetHours = city.coord.lon / 15.0
        let roundedOffset = Int(offsetHours.rounded())
        return "UTC\(roundedOffset >= 0 ? "+" : "")\(roundedOffset)"
    }
    
    // MARK: - Helper Methods
    private func flagEmoji(for countryCode: String) -> String {
        // Simple mapping for common countries (in production, use proper flag library)
        let countryFlags: [String: String] = [
            "US": "🇺🇸", "GB": "🇬🇧", "CA": "🇨🇦", "AU": "🇦🇺", "FR": "🇫🇷",
            "DE": "🇩🇪", "IT": "🇮🇹", "ES": "🇪🇸", "JP": "🇯🇵", "CN": "🇨🇳",
            "IN": "🇮🇳", "BR": "🇧🇷", "MX": "🇲🇽", "AR": "🇦🇷", "RU": "🇷🇺"
        ]
        
        return countryFlags[countryCode] ?? "🏙️"
    }
    
}




// MARK: - Preview
#if DEBUG
struct CityDetailView_Previews: PreviewProvider {
    static let sampleCity = City(
        id: 12345,
        name: "New York",
        country: "US",
        coord: Coordinate(lon: -74.0060, lat: 40.7128),
        isFavorite: true
    )
    
    static var previews: some View {
        CityDetailView(city: sampleCity)
        
        CityDetailView(city: City(
            id: 67890,
            name: "Tokyo",
            country: "JP",
            coord: Coordinate(lon: 139.6917, lat: 35.6895),
            isFavorite: false
        ))
        .previewDisplayName("Tokyo (Not Favorite)")
    }
}
#endif
