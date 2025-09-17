//
//  SearchResult.swift
//  SmartCityExploration
//
//  Created by Mariano Peruginoi on 15/09/2025.
//

import Foundation

// MARK: - Search Result
public struct SearchResult: Sendable {
    public let cities: [City]
    public let totalCount: Int
    public let query: String
    public let searchTime: TimeInterval
    
    public init(cities: [City], totalCount: Int, query: String, searchTime: TimeInterval) {
        self.cities = cities
        self.totalCount = totalCount
        self.query = query
        self.searchTime = searchTime
    }
}
