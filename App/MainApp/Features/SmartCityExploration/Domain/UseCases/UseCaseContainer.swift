//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import Foundation

// MARK: - Use Case Container (DI)
public final class UseCaseContainer {
    
    // MARK: - Use Cases
    public let searchUseCase: SearchCitiesUseCaseProtocol
    public let favoriteUseCase: FavoriteCitiesUseCaseProtocol
    public let loadUseCase: LoadCitiesUseCaseProtocol
    
    // MARK: - Initialization
    public init() {
        let repository = CityRepositoryFactory.create()
        
        self.searchUseCase = SearchCitiesUseCase(repository: repository)
        self.favoriteUseCase = FavoriteCitiesUseCase(repository: repository)
        self.loadUseCase = LoadCitiesUseCase(repository: repository)
    }
    
    public init(
        searchUseCase: SearchCitiesUseCaseProtocol,
        favoriteUseCase: FavoriteCitiesUseCaseProtocol,
        loadUseCase: LoadCitiesUseCaseProtocol
    ) {
        self.searchUseCase = searchUseCase
        self.favoriteUseCase = favoriteUseCase
        self.loadUseCase = loadUseCase
    }
    
    #if DEBUG
    public static func createMock() -> UseCaseContainer {
        let mockRepository = CityRepositoryFactory.createMock()
        
        return UseCaseContainer(
            searchUseCase: SearchCitiesUseCase(repository: mockRepository),
            favoriteUseCase: FavoriteCitiesUseCase(repository: mockRepository),
            loadUseCase: LoadCitiesUseCase(repository: mockRepository)
        )
    }
    #endif
}

// MARK: - Factory for Use Case Container
public final class UseCaseContainerFactory {
    
    public static func create() -> UseCaseContainer {
        return UseCaseContainer()
    }
    
    #if DEBUG
    public static func createMock() -> UseCaseContainer {
        return UseCaseContainer.createMock()
    }
    #endif
}
