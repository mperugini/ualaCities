//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation
@preconcurrency import CoreData

// MARK: - Core Data Stack Protocol (Interface Segregation Principle)
public protocol CoreDataStackProtocol: Sendable {
    func performBackgroundTask<T: Sendable>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T
    func performViewContextTask<T: Sendable>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T
    func save() async throws
    func saveBackgroundContext() async throws
}

// MARK: - Core Data Stack Implementation
public final class CoreDataStack: CoreDataStackProtocol, @unchecked Sendable {
    public static let shared = CoreDataStack()
    
    private let container: NSPersistentContainer
    
    // MARK: - Initialization
    private init() {
        container = NSPersistentContainer(name: "CityDataModel")
        
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
        }
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                print("Core Data loading error: \(error.localizedDescription)")
                print("Error domain: \(error.domain)")
                print("Error code: \(error.code)")
                print("Error userInfo: \(error.userInfo)")
                
                // More specific error handling
                if error.domain == NSCocoaErrorDomain {
                    switch error.code {
                    case NSPersistentStoreIncompatibleVersionHashError:
                        print("Model version mismatch - store needs migration")
                    case NSMigrationMissingSourceModelError:
                        print("Missing source model for migration")
                    default:
                        print("Cocoa domain error: \(error.code)")
                    }
                }
                
                fatalError("Failed to load Core Data store: \(error.localizedDescription)")
            }
            
            print("Core Data store loaded successfully")
            print("Store URL: \(storeDescription.url?.absoluteString ?? "unknown")")
            self?.configureContexts()
        }
    }
    
    private func configureContexts() {
        // Configure view context for UI updates
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Performance opt
        container.viewContext.shouldDeleteInaccessibleFaults = true
    }
    
    // MARK: - CoreDataStackProtocol Implementation
    
    public func performViewContextTask<T: Sendable>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await MainActor.run {
            let context = container.viewContext
            return try block(context)
        }
    }
    
    public func performBackgroundTask<T: Sendable>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                let result: Result<T, Error>
                do {
                    result = .success(try block(context))
                } catch {
                    result = .failure(error)
                }
                
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    @MainActor
    public func save() async throws {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw CoreDataError.saveFailed(underlying: error)
        }
    }
    
    public func saveBackgroundContext() async throws {
        try await performBackgroundTask { context in
            guard context.hasChanges else { return }
            
            do {
                try context.save()
            } catch {
                context.rollback()
                throw CoreDataError.saveFailed(underlying: error)
            }
        }
    }
    
    // MARK: - Utility Methods
    public func createChildContext(from parent: NSManagedObjectContext? = nil) async -> NSManagedObjectContext {
        let parentContext = parent ?? container.viewContext
        let childContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        childContext.parent = parentContext
        return childContext
    }
    
    // MARK: - Development Utilities
    #if DEBUG
    public func deleteAllData() async throws {
        try await performBackgroundTask { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CityEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
        }
        
        try await saveBackgroundContext()
    }
    
    public func getStorePath() -> URL? {
        return container.persistentStoreDescriptions.first?.url
    }
    #endif
}

// MARK: - Core Data Errors
public enum CoreDataError: Error, LocalizedError {
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case contextNotAvailable
    case invalidEntity
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save to Core Data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch from Core Data: \(error.localizedDescription)"
        case .contextNotAvailable:
            return "Core Data context is not available"
        case .invalidEntity:
            return "Invalid Core Data entity"
        }
    }
}
