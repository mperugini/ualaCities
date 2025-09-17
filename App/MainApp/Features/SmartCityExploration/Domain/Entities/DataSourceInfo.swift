//
//  DataSourceInfo.swift
//  SmartCityExploration
//
//  Created by Mariano Perugini on 15/09/2025.
//

import Foundation

// MARK: - Data Source Information Entity
public struct DataSourceInfo: Sendable {
    public let totalCities: Int
    public let favoritesCount: Int
    public let lastUpdated: Date?
    public let dataVersion: String
    
    public init(totalCities: Int, favoritesCount: Int, lastUpdated: Date?, dataVersion: String) {
        self.totalCities = totalCities
        self.favoritesCount = favoritesCount
        self.lastUpdated = lastUpdated
        self.dataVersion = dataVersion
    }
}
