//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import SwiftUI
import MapKit

// MARK: - City Map View (Challenge Requirements Implementation)
public struct CityMapView: View {
    
    let cities: [City]
    let selectedCity: City?
    let onCitySelected: (City) -> Void
    
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // Default to NYC
            span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
        )
    )
    
    @State private var annotations: [CityAnnotation] = []
    
    public var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(annotations) { annotation in
                    Annotation(annotation.city.name, coordinate: annotation.coordinate) {
                        CityMapPin(
                            city: annotation.city,
                            isSelected: selectedCity?.id == annotation.city.id,
                            onTap: {
                                onCitySelected(annotation.city)
                                animateToCity(annotation.city)
                            }
                        )
                    }
                }
            }
            .mapStyle(.standard)
            .onAppear {
                updateAnnotations()
                animateToSelectedCity()
            }
            .onChange(of: cities) { _, _ in
                updateAnnotations()
            }
            .onChange(of: selectedCity) { _, newCity in
                if let city = newCity {
                    animateToCity(city)
                }
            }
            
            // Map Controls
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        // Center on selected city
                        if let selectedCity = selectedCity {
                            Button(action: { animateToCity(selectedCity) }) {
                                Image(systemName: "location")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                        }
                        
                        // Reset zoom button
                        Button(action: resetMapView) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        
                       
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Private Methods
    private func updateAnnotations() {
        annotations = cities.map { city in
            CityAnnotation(city: city)
        }
    }
    
    private func animateToSelectedCity() {
        guard let selectedCity = selectedCity else { return }
        animateToCity(selectedCity)
    }
    
    private func animateToCity(_ city: City) {
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: city.coord.lat,
                    longitude: city.coord.lon
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        }
    }
    
    private func resetMapView() {
        guard !cities.isEmpty else { return }
        
        // Calculate bounding box for all cities
        let coordinates = cities.map { city in
            CLLocationCoordinate2D(latitude: city.coord.lat, longitude: city.coord.lon)
        }
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let latDelta = max(maxLat - minLat, 0.1) * 1.2 // Add 20% padding
        let lonDelta = max(maxLon - minLon, 0.1) * 1.2
        
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            ))
        }
    }
}

// MARK: - City Annotation
public struct CityAnnotation: Identifiable {
    public let id: Int
    public let city: City
    public let coordinate: CLLocationCoordinate2D
    
    public init(city: City) {
        self.id = city.id
        self.city = city
        self.coordinate = CLLocationCoordinate2D(
            latitude: city.coord.lat,
            longitude: city.coord.lon
        )
    }
}

// MARK: - City Map Pin
private struct CityMapPin: View {
    let city: City
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            // Pin
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.red)
                    .frame(width: isSelected ? 24 : 16, height: isSelected ? 24 : 16)
                
                Image(systemName: city.isFavorite ? "heart.fill" : "location.fill")
                    .font(.system(size: isSelected ? 12 : 8))
                    .foregroundColor(.white)
            }
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
            
            // City name (show only when selected)
            if isSelected {
                Text(city.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Standalone Map View (For Portrait Navigation)
public struct CityMapDetailView: View {
    let city: City
    @Environment(\.dismiss) private var dismiss
    
    @State private var cameraPosition: MapCameraPosition
    
    public init(city: City) {
        self.city = city
        self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: city.coord.lat, longitude: city.coord.lon),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )))
    }
    
    public var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                Annotation(city.name, coordinate: CLLocationCoordinate2D(latitude: city.coord.lat, longitude: city.coord.lon)) {
                    CityMapPin(city: city, isSelected: true, onTap: {})
                }
            }
            .navigationTitle(city.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Info") {
                        // Show city detail
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CityMapView_Previews: PreviewProvider {
    static let sampleCities = [
        City(
            id: 1,
            name: "New York",
            country: "US",
            coord: Coordinate(lon: -74.0060, lat: 40.7128),
            isFavorite: true
        ),
        City(
            id: 2,
            name: "London",
            country: "GB",
            coord: Coordinate(lon: -0.1276, lat: 51.5074),
            isFavorite: false
        ),
        City(
            id: 3,
            name: "Tokyo",
            country: "JP",
            coord: Coordinate(lon: 139.6917, lat: 35.6895),
            isFavorite: true
        )
    ]
    
    static var previews: some View {
        CityMapView(
            cities: sampleCities,
            selectedCity: sampleCities.first,
            onCitySelected: { _ in }
        )
        .previewDisplayName("Map View")
        
        CityMapDetailView(city: sampleCities.first!)
            .previewDisplayName("Detail Map View")
    }
}
#endif
