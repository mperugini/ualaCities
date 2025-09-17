//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

// MARK: - Error System Export
// Este archivo exporta todos los tipos relacionados con el manejo de errores

@_exported import Foundation
@_exported import os.log

// MARK: - SmartCity Error Wrapper
public enum SmartCityErrorWrapper: Error {
    case domain(DomainError)
    case data(DataError)
    case network(NetworkError)
    case unknown(Error)
    
    public var localizedDescription: String {
        switch self {
        case .domain(let error): return error.localizedDescription
        case .data(let error): return error.localizedDescription
        case .network(let error): return error.localizedDescription
        case .unknown(let error): return error.localizedDescription
        }
    }
}

// Re-exportar todos los tipos de error
public typealias SmartCityResult<T> = Result<T, SmartCityErrorWrapper> 
