
import XCTest
import SwiftUI
@testable import SmartCityExploration

final class SmartCitySearchViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    @MainActor func testCityMapViewInitialization() {
        // Given
        let city = City(
            id: 1,
            name: "New York",
            country: "US",
            coord: Coordinate(lon: -74.0060, lat: 40.7128)
        )
        
        // When
        let mapView = CityMapView(
            cities: [city],
            selectedCity: city,
            onCitySelected: { _ in }
        )
        
        // Then
        XCTAssertNotNil(mapView)
        XCTAssertEqual(mapView.cities.first?.name, "New York")
        XCTAssertEqual(mapView.cities.first?.country, "US")
    }
    
    func testCityMapKitConformance() {
        // Given
        let city = City(
            id: 1,
            name: "New York",
            country: "US",
            coord: Coordinate(lon: -74.0060, lat: 40.7128)
        )
        
        let annotation = CityAnnotation(city: city)
        
        // When & Then
        XCTAssertEqual(annotation.coordinate.latitude, 40.7128)
        XCTAssertEqual(annotation.coordinate.longitude, -74.0060)
      
        XCTAssertEqual(annotation.city.name, "New York")
        XCTAssertEqual(annotation.city.country, "US")
    }
    
    func testCityEquatable() {
        // Given
        let city1 = City(
            id: 1,
            name: "New York",
            country: "US",
            coord: Coordinate(lon: -74.0060, lat: 40.7128)
        )
        
        let city2 = City(
            id: 1,
            name: "New York",
            country: "US",
            coord: Coordinate(lon: -74.0060, lat: 40.7128)
        )
        
        let city3 = City(
            id: 2,
            name: "London",
            country: "UK",
            coord: Coordinate(lon: -0.1278, lat: 51.5074)
        )
        
        // When & Then
        XCTAssertEqual(city1, city2)
        XCTAssertNotEqual(city1, city3)
    }
    
    func testCityCoordinateInitialization() {
        // Given
        let coordinate = Coordinate(lon: -74.0060, lat: 40.7128)
        
        // When & Then
        XCTAssertEqual(coordinate.lon, -74.0060)
        XCTAssertEqual(coordinate.lat, 40.7128)
    }
    
    func testCityFromCoreDataEntity() {
 
        let city = City(
            id: 1,
            name: "New York",
            country: "US",
            coord: Coordinate(lon: -74.0060, lat: 40.7128),
            isFavorite: false
        )
        
        // Then
        XCTAssertEqual(city.id, 1)
        XCTAssertEqual(city.name, "New York")
        XCTAssertEqual(city.country, "US")
        XCTAssertEqual(city.coord.lon, -74.0060)
        XCTAssertEqual(city.coord.lat, 40.7128)
        XCTAssertFalse(city.isFavorite)
    }
}
