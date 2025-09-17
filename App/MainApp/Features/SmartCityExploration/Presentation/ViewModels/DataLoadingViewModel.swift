//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import SwiftUI

@MainActor
public final class DataLoadingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var cities: [City] = []
    @Published public var isLoading = false
    @Published public var isInitialLoading = false
    @Published public var isRefreshing = false
    @Published public var dataSourceInfo: DataSourceInfo?
    
    // MARK: - Dependencies
    private let loadUseCase: LoadCitiesUseCaseProtocol
    
    // MARK: - Callbacks
    public var onDataLoaded: (() -> Void)?
    public var onErrorOccurred: ((Error) -> Void)?
    
    // MARK: - Initialization
    public init(loadUseCase: LoadCitiesUseCaseProtocol) {
        self.loadUseCase = loadUseCase
    }
    
    // MARK: - Public Methods
    public func loadInitialData() async {
        guard !isInitialLoading else { return }
        
        isInitialLoading = true
        isLoading = true
        
        let result = await loadUseCase.execute()
        
        switch result {
        case .success(let info):
            dataSourceInfo = info
            onDataLoaded?()
            
        case .failure(let error):
            onErrorOccurred?(error)
        }
        
        isInitialLoading = false
        isLoading = false
    }
    
    public func refreshData() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        let result = await loadUseCase.forceRefresh()
        
        switch result {
        case .success(let info):
            dataSourceInfo = info
            onDataLoaded?()
            
        case .failure(let error):
            onErrorOccurred?(error)
        }
        
        isRefreshing = false
    }
    
    public func getDataInfo() async {
        let result = await loadUseCase.getDataInfo()
        
        switch result {
        case .success(let info):
            dataSourceInfo = info
            
        case .failure(let error):
            onErrorOccurred?(error)
        }
    }
}

// MARK: - Factory
public final class DataLoadingViewModelFactory {
    
    @MainActor
    public static func create(loadUseCase: LoadCitiesUseCaseProtocol) -> DataLoadingViewModel {
        return DataLoadingViewModel(loadUseCase: loadUseCase)
    }
    
    #if DEBUG
    @MainActor
    public static func createMock() -> DataLoadingViewModel {
        let mockUseCase = MockLoadCitiesUseCase()
        return DataLoadingViewModel(loadUseCase: mockUseCase)
    }
    #endif
}

// MARK: - Mock Load Cities Use Case
#if DEBUG
@MainActor
private final class MockLoadCitiesUseCase: LoadCitiesUseCaseProtocol, @unchecked Sendable {
    
    var mockDataInfo: DataSourceInfo!
    var mockRefreshDataInfo: DataSourceInfo!
    var shouldFail = false
    var mockError: Error = LoadCitiesUseCaseError.noDataAvailable
    var delay: TimeInterval = 0
    var refreshDelay: TimeInterval = 0
    
    var executeCallCount = 0
    var forceRefreshCallCount = 0
    
    func execute() async -> Result<DataSourceInfo, Error> {
        executeCallCount += 1
        
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldFail {
            return .failure(mockError)
        }
        
        return .success(mockDataInfo)
    }
    
    func forceRefresh() async -> Result<DataSourceInfo, Error> {
        forceRefreshCallCount += 1
        
        if refreshDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(refreshDelay * 1_000_000_000))
        }
        
        if shouldFail {
            return .failure(mockError)
        }
        
        return .success(mockRefreshDataInfo ?? mockDataInfo)
    }
    
    func getCityById(_ id: Int) async -> Result<City?, Error> {
        .success(nil)
    }
    
    func getDataInfo() async -> Result<DataSourceInfo, Error> {
        .success(mockDataInfo)
    }
}
#endif
