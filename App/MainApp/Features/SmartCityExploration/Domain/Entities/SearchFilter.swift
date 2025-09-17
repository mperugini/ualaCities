//
//  SearchFilter.swift
//  SmartCityExploration
//
//  Created by Mariano Perugini on 15/09/2025.
//

import Foundation

// MARK: - Search Filter
public struct SearchFilter: Sendable, Equatable {
    public let query: String
    public let showOnlyFavorites: Bool
    public let limit: Int?
    public let searchInCountry: Bool
    
    public init(
        query: String = "", 
        showOnlyFavorites: Bool = false, 
        limit: Int? = nil,
        searchInCountry: Bool = true
    ) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.showOnlyFavorites = showOnlyFavorites
        self.limit = limit
        self.searchInCountry = searchInCountry
    }
    
    public var isEmpty: Bool {
        query.isEmpty && !showOnlyFavorites
    }
    
    public var isValidQuery: Bool {
        query.isEmpty || query.count >= SearchConstants.minimumQueryLength
    }
}
