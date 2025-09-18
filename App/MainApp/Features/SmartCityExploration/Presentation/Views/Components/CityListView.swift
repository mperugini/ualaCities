//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import SwiftUI

public struct CityListView: View {
    let cities: [City]
    let onCityTap: (City) -> Void
    let onFavoriteToggle: (City) -> Void
    let onInfoTap: (City) -> Void
    let onScrollToBottom: ((City) -> Void)?

    public init(
        cities: [City],
        onCityTap: @escaping (City) -> Void,
        onFavoriteToggle: @escaping (City) -> Void,
        onInfoTap: @escaping (City) -> Void,
        onScrollToBottom: ((City) -> Void)? = nil
    ) {
        self.cities = cities
        self.onCityTap = onCityTap
        self.onFavoriteToggle = onFavoriteToggle
        self.onInfoTap = onInfoTap
        self.onScrollToBottom = onScrollToBottom
    }
    
    public var body: some View {
        List {
            ForEach(cities) { city in
                CityRowView(
                    city: city,
                    onFavoriteToggle: { onFavoriteToggle(city) },
                    onCityTap: { onCityTap(city) },
                    onInfoTap: { onInfoTap(city) }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .onAppear {
                    // Trigger infinite scroll detection
                    onScrollToBottom?(city)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - City Row View
public struct CityRowView: View {
    let city: City
    let onFavoriteToggle: () -> Void
    let onCityTap: () -> Void
    let onInfoTap: () -> Void
    
    public init(
        city: City,
        onFavoriteToggle: @escaping () -> Void,
        onCityTap: @escaping () -> Void,
        onInfoTap: @escaping () -> Void
    ) {
        self.city = city
        self.onFavoriteToggle = onFavoriteToggle
        self.onCityTap = onCityTap
        self.onInfoTap = onInfoTap
    }
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(city.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(city.coord.displayString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button(action: onFavoriteToggle) {
                    Image(systemName: city.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(city.isFavorite ? .red : .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCityTap()
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CityListView_Previews: PreviewProvider {
    static var previews: some View {
        let testCities = [
            City(id: 1, name: "New York", country: "US", coord: Coordinate(lon: -74.006, lat: 40.7128)),
            City(id: 2, name: "London", country: "GB", coord: Coordinate(lon: -0.1276, lat: 51.5074))
        ]
        
        CityListView(
            cities: testCities,
            onCityTap: { _ in },
            onFavoriteToggle: { _ in },
            onInfoTap: { _ in }
        )
        .previewDisplayName("City List")
    }
}
#endif
