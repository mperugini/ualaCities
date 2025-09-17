//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Network Errors
public enum NetworkError: Error, LocalizedError, Equatable {
    case invalidURL
    case noConnection
    case timeout
    case hostNotFound
    case connectionLost
    case invalidResponse
    case clientError(Int)
    case serverError(Int)
    case unexpectedStatusCode(Int)
    case decodingFailed(Error)
    case urlSessionError(URLError)
    case unknown(Error)
    case maxRetriesExceeded
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .hostNotFound:
            return "Server not found"
        case .connectionLost:
            return "Network connection lost"
        case .invalidResponse:
            return "Invalid server response"
        case .clientError(let code):
            return "Client error (\(code))"
        case .serverError(let code):
            return "Server error (\(code))"
        case .unexpectedStatusCode(let code):
            return "Unexpected status code (\(code))"
        case .decodingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .urlSessionError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
    
    // MARK: - Equatable Implementation
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.noConnection, .noConnection),
             (.timeout, .timeout),
             (.hostNotFound, .hostNotFound),
             (.connectionLost, .connectionLost),
             (.invalidResponse, .invalidResponse),
             (.maxRetriesExceeded, .maxRetriesExceeded):
            return true
        case (.clientError(let lhsCode), .clientError(let rhsCode)),
             (.serverError(let lhsCode), .serverError(let rhsCode)),
             (.unexpectedStatusCode(let lhsCode), .unexpectedStatusCode(let rhsCode)):
            return lhsCode == rhsCode
        case (.urlSessionError(let lhsError), .urlSessionError(let rhsError)):
            return lhsError == rhsError
        case (.decodingFailed(let lhsError), .decodingFailed(let rhsError)),
             (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Network Configuration
public struct NetworkConfiguration : Sendable{
    public let baseURL: String
    public let timeoutInterval: TimeInterval
    public let maxRetries: Int
    public let retryDelay: TimeInterval
    
    public init(
        baseURL: String = "https://gist.githubusercontent.com/hernan-uala/dce8843a8edbe0b0018b32e137bc2b3a/raw/0996accf70cb0ca0e16f9a99e0ee185fafca7af1/cities.json",
        timeoutInterval: TimeInterval = 30.0,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
    
    // MARK: - Default Configuration
    public static let `default` = NetworkConfiguration()
}

// MARK: - Network Service Protocol (Single Responsibility Principle)
public protocol NetworkService: Sendable {
    func fetchData(from url: URL) async -> Result<Data, NetworkError>
    func downloadJSON<T: Codable>(from url: URL, as type: T.Type) async -> Result<T, NetworkError>
}

// MARK: - URLSession Remote Data Source Implementation
public final class URLSessionRemoteDataSource: RemoteDataSource {
    
    private let networkService: NetworkService
    private let configuration: NetworkConfiguration
    
    // MARK: - Initialization (Dependency Injection)
    public init(
        networkService: NetworkService = URLSessionNetworkService(),
        configuration: NetworkConfiguration = .default
    ) {
        self.networkService = networkService
        self.configuration = configuration
    }
    
    // MARK: - RemoteDataSource Implementation
    public func downloadCities() async -> Result<[City], Error> {
        guard let url = URL(string: configuration.baseURL) else {
            return .failure(NetworkError.invalidURL)
        }
        
        print("Starting download of cities from: \(configuration.baseURL)")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = await networkService.downloadJSON(from: url, as: [City].self)
        
        switch result {
        case .success(let cities):
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Downloaded \(cities.count) cities in \(String(format: "%.2f", timeElapsed))s")
            return .success(cities)
            
        case .failure(let error):
            print("Failed to download cities: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    public func getDataSourceURL() -> String {
        return configuration.baseURL
    }
}

// MARK: - URLSession Network Service Implementation
public final class URLSessionNetworkService: NetworkService {
    
    private let urlSession: URLSession
    private let configuration: NetworkConfiguration
    
    public init(configuration: NetworkConfiguration = .default) {
        self.configuration = configuration
        
        // Configure URLSession for optimal performance
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeoutInterval
        config.timeoutIntervalForResource = configuration.timeoutInterval * 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil // Disable cache for fresh data
        
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - NetworkService Implementation
    public func fetchData(from url: URL) async -> Result<Data, NetworkError> {
        var lastError: NetworkError?
        
        for attempt in 1...configuration.maxRetries {
            do {
                let (data, response) = try await urlSession.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = .invalidResponse
                    continue
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return .success(data)
                case 400...499:
                    return .failure(.clientError(httpResponse.statusCode))
                case 500...599:
                    lastError = .serverError(httpResponse.statusCode)
                default:
                    lastError = .unexpectedStatusCode(httpResponse.statusCode)
                }
                
            } catch {
                if let urlError = error as? URLError {
                    lastError = mapURLError(urlError)
                } else {
                    lastError = .unknown(error)
                }
            }
            
            // Wait before retry, except for last attempt
            if attempt < configuration.maxRetries {
                print("Download attempt \(attempt) failed, retrying in \(configuration.retryDelay)s...")
                try? await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * 1_000_000_000))
            }
        }
        
        return .failure(lastError ?? .unknown(NetworkError.maxRetriesExceeded))
    }
    
    public func downloadJSON<T: Codable>(from url: URL, as type: T.Type) async -> Result<T, NetworkError> {
        let dataResult = await fetchData(from: url)
        
        switch dataResult {
        case .success(let data):
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Add detailed debug logging for decoding issues
                #if DEBUG
                print("Attempting to decode \(type) from \(data.count) bytes")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("JSON sample: \(String(jsonString.prefix(200)))")
                }
                #endif
                
                let decodedData = try decoder.decode(type, from: data)
                
                #if DEBUG
                print("Successfully decoded \(type)")
                #endif
                
                return .success(decodedData)
                
            } catch let decodingError {
                #if DEBUG
                print("Decoding failed for \(type): \(decodingError)")
                
                if let decodingError = decodingError as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("Type mismatch: expected \(type), at \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found: \(type), at \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("Key not found: \(key), at \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("Data corrupted at \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error: \(decodingError)")
                    }
                }
                #endif
                
                return .failure(.decodingFailed(decodingError))
            }
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Error Mapping
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet:
            return .noConnection
        case .timedOut:
            return .timeout
        case .cannotFindHost, .cannotConnectToHost:
            return .hostNotFound
        case .networkConnectionLost:
            return .connectionLost
        case .badURL:
            return .invalidURL
        default:
            return .urlSessionError(error)
        }
    }
    
}
    // MARK: - Mock Implementation for Testing
#if DEBUG
    public final class MockRemoteDataSource: RemoteDataSource, @unchecked Sendable {
        
        private let lock = NSLock()
        private var _shouldFail = false
        private var _mockError: Error = NetworkError.noConnection
        private var _mockDelay: TimeInterval = 0
        private var _mockCities: [City] = []
        
        public var shouldFail: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _shouldFail
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _shouldFail = newValue
            }
        }
        
        public var mockError: Error {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _mockError
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _mockError = newValue
            }
        }
        
        public var mockDelay: TimeInterval {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _mockDelay
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _mockDelay = newValue
            }
        }
        
        public var mockCities: [City] {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _mockCities
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _mockCities = newValue
            }
        }
        
        public init() {}
        
        public func downloadCities() async -> Result<[City], Error> {
            if mockDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
            }
            
            if shouldFail {
                return .failure(mockError)
            }
            
            return .success(mockCities)
        }
        
        public func getDataSourceURL() -> String {
            return "mock://cities.json"
        }
    }
#endif

