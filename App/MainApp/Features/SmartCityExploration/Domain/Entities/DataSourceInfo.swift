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

// MARK: - Pagination Models
public struct PaginationRequest: Sendable {
    public let page: Int
    public let pageSize: Int
    public let offset: Int

    public init(page: Int, pageSize: Int = PaginationConstants.defaultPageSize) {
        self.page = page
        self.pageSize = pageSize
        self.offset = page * pageSize
    }

    public var nextPage: PaginationRequest {
        PaginationRequest(page: page + 1, pageSize: pageSize)
    }
}

public struct PaginatedResult<T: Sendable>: Sendable {
    public let items: [T]
    public let pagination: PaginationInfo

    public init(items: [T], pagination: PaginationInfo) {
        self.items = items
        self.pagination = pagination
    }

    public var hasMorePages: Bool {
        pagination.hasNextPage
    }
}

public struct PaginationInfo: Sendable {
    public let currentPage: Int
    public let pageSize: Int
    public let totalItems: Int
    public let totalPages: Int
    public let hasNextPage: Bool
    public let hasPreviousPage: Bool

    public init(currentPage: Int, pageSize: Int, totalItems: Int) {
        self.currentPage = currentPage
        self.pageSize = pageSize
        self.totalItems = totalItems
        self.totalPages = max(1, Int(ceil(Double(totalItems) / Double(pageSize))))
        self.hasNextPage = currentPage < totalPages - 1
        self.hasPreviousPage = currentPage > 0
    }
}

// MARK: - Pagination Constants
public enum PaginationConstants {
    public static let defaultPageSize = 50
    public static let searchPageSize = 100
    public static let maxPageSize = 200
    public static let prefetchThreshold = 10 // Load next page when 10 items from bottom
}

// MARK: - Search with Pagination
public struct SearchPaginationRequest: Sendable {
    public let query: String
    public let pagination: PaginationRequest
    public let showOnlyFavorites: Bool

    public init(query: String, pagination: PaginationRequest, showOnlyFavorites: Bool = false) {
        self.query = query
        self.pagination = pagination
        self.showOnlyFavorites = showOnlyFavorites
    }
}
