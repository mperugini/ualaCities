//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
import os.log

// MARK: - Analytics Service Protocol
public protocol AnalyticsService {
    func track(_ event: String, parameters: [String: Any]?)
}

// MARK: - Smart City Error Factory
public final class SmartCityErrorFactory {
    public static func create(from error: Error) -> SmartCityError {
        if let smartCityError = error as? SmartCityError {
            return smartCityError
        }
        
        // Convert common errors to SmartCityError
        if let networkError = error as? NetworkError {
            return DataError.fetchFailed(reason: networkError.localizedDescription)
        }
        
        if let coreDataError = error as? CoreDataError {
            return DataError.coreDataError(underlying: coreDataError)
        }
        
        // Default fallback
        return DataError.fetchFailed(reason: error.localizedDescription)
    }
}

// MARK: - Error Logger Protocol
public protocol ErrorLogger {
    func log(_ error: SmartCityError, context: ErrorContext?)
    func log(_ error: Error, context: ErrorContext?)
    func logCritical(_ error: SmartCityError, context: ErrorContext?)
    func logCritical(_ error: Error, context: ErrorContext?)
}

// MARK: - Error Context
public struct ErrorContext {
    public let file: String
    public let function: String
    public let line: Int
    public let additionalInfo: [String: Any]?
    
    public init(file: String = #file, function: String = #function, line: Int = #line, additionalInfo: [String: Any]? = nil) {
        self.file = file
        self.function = function
        self.line = line
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Error Logger Implementation
public final class SmartCityErrorLogger: ErrorLogger {
    private let logger: Logger
    private let analyticsService: AnalyticsService?
    
    public init(subsystem: String = "com.smartcity.SmartCityExploration", analyticsService: AnalyticsService? = nil) {
        self.logger = Logger(subsystem: subsystem, category: "ErrorLogger")
        self.analyticsService = analyticsService
    }
    
    public func log(_ error: SmartCityError, context: ErrorContext?) {
        logError(error, context: context, isCritical: false)
    }
    
    public func log(_ error: Error, context: ErrorContext?) {
        let smartCityError = SmartCityErrorFactory.create(from: error)
        logError(smartCityError, context: context, isCritical: false)
    }
    
    public func logCritical(_ error: SmartCityError, context: ErrorContext?) {
        logError(error, context: context, isCritical: true)
    }
    
    public func logCritical(_ error: Error, context: ErrorContext?) {
        let smartCityError = SmartCityErrorFactory.create(from: error)
        logError(smartCityError, context: context, isCritical: true)
    }
    
    private func logError(_ error: SmartCityError, context: ErrorContext?, isCritical: Bool) {
        let logLevel: OSLogType = isCritical ? .fault : .error
        let prefix = isCritical ? "🚨 CRITICAL" : "❌ ERROR"
        
        // Log basico
        let message = createLogMessage(error: error, context: context, prefix: prefix)
        logger.log(level: logLevel, "\(message)")
        
        // Log detallado para debugging
        if let technicalDetails = error.technicalDetails {
            logger.debug("Technical details: \(technicalDetails)")
        }
        
        if let underlyingError = error.underlyingError {
            logger.debug("Underlying error: \(underlyingError)")
        }
        
        // Analytics para errores cr1ticos
        if isCritical {
            analyticsService?.track("error_critical", parameters: [
                "domain": error.domain.rawValue,
                "code": error.code,
                "description": error.errorDescription ?? "Unknown",
                "file": context?.file ?? "Unknown",
                "function": context?.function ?? "Unknown",
                "line": context?.line ?? 0
            ])
        }
        
        if error.domain == .network {
            logger.notice("Network error detected: \(error.errorDescription ?? "Unknown")")
        }
        
        if error.domain == .data {
            logger.error("Data error detected: \(error.errorDescription ?? "Unknown")")
        }
    }
    
    private func createLogMessage(error: SmartCityError, context: ErrorContext?, prefix: String) -> String {
        var message = "\(prefix) [\(error.domain.rawValue)] \(error.errorDescription ?? "Unknown error")"
        
        if let context = context {
            let fileName = URL(fileURLWithPath: context.file).lastPathComponent
            message += " at \(fileName):\(context.line) in \(context.function)"
        }
        
        message += " (Code: \(error.code))"
        
        if let additionalInfo = context?.additionalInfo, !additionalInfo.isEmpty {
            let infoString = additionalInfo.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " | Additional: \(infoString)"
        }
        
        return message
    }
}

// MARK: - Error Logger Extensions
extension ErrorLogger {
    public func log(_ error: SmartCityError, file: String = #file, function: String = #function, line: Int = #line, additionalInfo: [String: Any]? = nil) {
        let context = ErrorContext(file: file, function: function, line: line, additionalInfo: additionalInfo)
        log(error, context: context)
    }
    
    public func log(_ error: Error, file: String = #file, function: String = #function, line: Int = #line, additionalInfo: [String: Any]? = nil) {
        let context = ErrorContext(file: file, function: function, line: line, additionalInfo: additionalInfo)
        log(error, context: context)
    }
    
    public func logCritical(_ error: SmartCityError, file: String = #file, function: String = #function, line: Int = #line, additionalInfo: [String: Any]? = nil) {
        let context = ErrorContext(file: file, function: function, line: line, additionalInfo: additionalInfo)
        logCritical(error, context: context)
    }
    
    public func logCritical(_ error: Error, file: String = #file, function: String = #function, line: Int = #line, additionalInfo: [String: Any]? = nil) {
        let context = ErrorContext(file: file, function: function, line: line, additionalInfo: additionalInfo)
        logCritical(error, context: context)
    }
}

// MARK: - Global Error Logger
public extension ErrorLogger {
    static var shared: ErrorLogger {
        return SmartCityErrorLogger()
    }
} 
