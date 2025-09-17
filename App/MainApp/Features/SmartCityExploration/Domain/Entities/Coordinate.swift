//
//  Coordinate.swift
//  SmartCityExploration
//
//  Created by Mariano Perugini on 15/09/2025.
//
import Foundation

// MARK: - Coordinate Entity
public struct Coordinate: Sendable, Hashable, Codable {
    public let lon: Double
    public let lat: Double
    
    public init(lon: Double, lat: Double) {
        self.lon = lon
        self.lat = lat
    }
    
    // MARK: - Display Properties
    public var displayString: String {
        String(format: "%.6f, %.6f", lat, lon)
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(lat)
        hasher.combine(lon)
    }
}
