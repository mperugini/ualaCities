//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import SwiftUI

// MARK: - Error Handling ViewModel
@MainActor
public final class ErrorHandlingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var errorMessage: String?
    @Published public var showError = false
    @Published public var lastError: Error?
    
    // MARK: - Callbacks
    public var onErrorOccurred: ((Error) -> Void)?
    
    // MARK: - Initialization
    public init() {
        setupErrorHandling()
    }
    
    // MARK: - Public Methods
    public func showError(_ message: String) {
        errorMessage = message
        showError = true
        onErrorOccurred?(DomainError.invalidCityData(reason: message))
    }
    
    public func showError(_ error: Error) {
        lastError = error
        errorMessage = error.localizedDescription
        showError = true
        onErrorOccurred?(error)
    }
    
    public func dismissError() {
        errorMessage = nil
        showError = false
        lastError = nil
    }
    
    public func clearError() {
        errorMessage = nil
        showError = false
        lastError = nil
    }
    
    // MARK: - Private Methods
    private func setupErrorHandling() {
        // Setup any error handling configuration when needed
    }
}

// MARK: - Factory 
public final class ErrorHandlingViewModelFactory {
    
    @MainActor
    public static func create() -> ErrorHandlingViewModel {
        return ErrorHandlingViewModel()
    }
}
