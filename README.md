# ualaCities - iOS App

Una aplicación iOS para explorar y buscar ciudades, sistema de favoritos y arquitectura Clean Architecture con ViewModels especializados.

## ✨ Características Principales

### 🔍 Búsqueda de Ciudades
- **Búsqueda en tiempo real** con debouncing de 300ms
- **Búsqueda por nombre de ciudad y país** con priorización (ciudad primero, país segundo)
- **Soporte para diacríticos** - búsqueda bidireccional insensible a acentos
- **Búsqueda tolerante a mayúsculas/minúsculas** con normalización Unicode
- **Filtros combinables**: solo favoritos + búsqueda por texto

### ⭐ Sistema de Favoritos
- **Persistencia con Core Data** que preserva favoritos durante refresh
- **Toggle instantáneo** con feedback visual
- **Contador dinámico** de favoritos en UI
- **Sincronización entre listas y búsquedas**

### 🏗️ Arquitectura Clean Architecture + MVVM 
- **Separación por capas**: Presentation → Domain → Data
- **ViewModels especializados** siguiendo Single Responsibility Principle
- **Composition Pattern** con CitySearchCoordinator
- **Inyección de dependencias** con UseCaseContainer
- **Principios SOLID** aplicados correctamente
- **Swift 6 concurrency** con @MainActor isolation

### 🧪 Testing Comprehensivo
- **Tests unitarios** para algoritmos de búsqueda
- **Tests de ViewModels especializados** con mocks aislados
- **Tests de casos de uso** con coverage completo
- **Tests de rendimiento** para operaciones de búsqueda
- **Tests de integración** para coordinación entre ViewModels

## 🏛️ Arquitectura del Sistema

### 📱 Presentation Layer 
| Componente | Descripción |
|------------|-------------|
| **CitySearchView** | Vista principal con navegación adaptativa |
| **CitySearchCoordinator** | Coordinador principal que compone ViewModels especializados |
| **SearchViewModel** | ViewModel especializado para funcionalidad de búsqueda |
| **FavoritesViewModel** | ViewModel especializado para gestión de favoritos |
| **DataLoadingViewModel** | ViewModel especializado para carga de datos |
| **ErrorHandlingViewModel** | ViewModel especializado para manejo de errores |
| **SearchBarView** | Componente reutilizable para barra de búsqueda |
| **CityListView** | Componente reutilizable para lista de ciudades |
| **CityDetailView** | Vista de detalle con información de ciudad |
| **CityMapView** | Vista de mapa con MapKit |

### 🔧 Domain Layer  
| Componente | Descripción |
|------------|-------------|
| **LoadCitiesUseCase** | Carga de datos con cache (24h TTL) |
| **SearchCitiesUseCase** | Lógica de búsqueda con validaciones |
| **FavoriteCitiesUseCase** | Gestión de favoritos |
| **UseCaseContainer** | Container de inyección de dependencias |
| **City Entity** | Modelo de dominio con propiedades de búsqueda |
| **SearchFilter** | Filtros de búsqueda configurables |

### 💾 Data Layer
| Componente | Descripción |
|------------|-------------|
| **CityRepositoryImpl** | Implementación de repositorio con cache |
| **CoreDataLocalDataSource** | Persistencia optimizada con batch operations |
| **URLSessionRemoteDataSource** | Cliente HTTP con retry automático |
| **CoreDataStack** | Stack de Core Data thread-safe |

## 🛠️ Tecnologías y Patrones

### Core Technologies
- **Swift 6** con strict concurrency y async/await
- **SwiftUI** para interfaces declarativas
- **MapKit** para mapas 
- **Core Data** para persistencia local

### Patrones de Diseño
- **Clean Architecture** con separación de responsabilidades
- **MVVM Especializado** con ViewModels de responsabilidad única
- **Composition Pattern** para coordinación de ViewModels
- **Repository Pattern** con abstracción de datos
- **Factory Pattern** para creación de dependencias
- **Dependency Injection** con UseCaseContainer

### Performance & Concurrency
- **MainActor isolation** para UI thread safety
- **Background tasks** para operaciones de datos
- **Debouncing** para búsquedas (300ms)
- **Batch operations** para inserción masiva de datos
- **Memory management** con weak references
- **Task cancellation** para operaciones asíncronas

## 🔧 Configuración del Proyecto

### Requisitos
- **iOS 17.0+**
- **Xcode 16.0+**
- **Swift 6.0+**

### Instalación
1. Clonar el repositorio
```bash
git clone <repository-url>
cd SmartCityExploration/SampleCities
```

2. Generar el proyecto Xcode (si usas XcodeGen)
```bash
xcodegen generate
```

3. Abrir `SmartCityExploration.xcodeproj`
4. Seleccionar scheme `SmartCityExploration`
5. Build y ejecutar

### Estructura del Proyecto
```
SampleCities/
├── App/MainApp/
│   ├── AppDelegate/
│   ├── Coordinators/
│   └── Features/SmartCityExploration/
│       ├── Presentation/    # Views, ViewModels especializados
│       ├── Domain/          # UseCases, Entities, Container
│       ├── Data/           # Repositories, DataSources
│       └── Tests/          # Unit Tests especializados
└── project.yml             # XcodeGen configuration
```

## 🧪 Testing

### Cobertura de Tests
- ✅ **Algorithm Tests**: Búsqueda, normalización, diacríticos
- ✅ **UseCase Tests**: Casos de uso con mocks
- ✅ **ViewModel Tests**: ViewModels especializados (Swift 6 compliant)
- ✅ **Coordinator Tests**: Integración entre ViewModels
- ✅ **Performance Tests**: Operaciones de búsqueda

### Ejecutar Tests
```bash
# Todos los tests
xcodebuild test -scheme SmartCityExploration

# Tests específicos
xcodebuild test -scheme SmartCityExploration -only-testing:SmartCityExplorationTests/SearchAlgorithmTests
```

### Tests Implementados
| Test Suite | Cobertura | Estado |
|------------|-----------|--------|
| **SearchAlgorithmTests** | Algoritmos de búsqueda | ✅ |
| **SearchViewModelTests** | ViewModel de búsqueda | ✅ |
| **FavoritesViewModelTests** | ViewModel de favoritos | ✅ |
| **CitySearchViewModelTests** | Coordinador principal | ✅ |
| **FavoriteCitiesUseCaseTests** | Lógica de favoritos | ✅ |

## 🚀 Funcionalidades

### Búsqueda
```swift
// Ejemplos de búsqueda
"A" → Alabama, ÁLAVA, Australia (ciudades primero, países segundo)
"s" → Sydney, AU (solo Sydney porque coincide por ciudad)
"Á" → ÁLAVA, Alabama (búsqueda bidireccional de acentos)
```

### Gestión de Favoritos
- **Preservación durante refresh**: Los favoritos se mantienen al actualizar datos
- **Límites configurables**: Máximo 100 favoritos por defecto
- **UI reactiva**: Contador se actualiza automáticamente
- **Validaciones**: Previene duplicados y límites excedidos

### Cache
- **TTL de 24 horas** para datos de ciudades
- **Fallback automático** a datos locales si falla la red
- **Batch operations** para performance en grandes datasets
- **Preserve favorites** durante operaciones de refresh

## 📊 Métricas y Performance

### Optimizaciones Implementadas
- **Búsqueda por prioridad**: Ciudad → País para relevancia
- **Normalización Unicode**: Consistente en toda la app
- **Batch Core Data operations**: Para datasets grandes
- **Debouncing**: Previene búsquedas excesivas
- **Background processing**: Operaciones de datos fuera del main thread
- **ViewModels especializados**: Mejor separación de responsabilidades

### Métricas de Performance
```swift
// Logs de performance (sin emojis, limpio)
"Found 45 cities for 'lon' in 0.0123s (city matches first)"
"Saved 10000 cities in 2.34s"
"Restored 15 favorites after refresh"
```

## 🔄 Flujo de Datos

### Carga Inicial
1. **Verificar cache local** (Core Data)
2. **Validar TTL** (24 horas)
3. **Si válido**: usar datos locales
4. **Si expirado**: descargar desde API
5. **Preservar favoritos** durante refresh
6. **Actualizar UI** con nuevos datos

### Búsqueda de Ciudades
1. **Input del usuario** en search bar
2. **Debouncing** (300ms delay)
3. **Validación de entrada** (longitud mínima)
4. **Búsqueda priorizada**: ciudad → país
5. **Aplicar filtros** (favoritos, límites)
6. **Actualizar resultados** en UI

### Toggle de Favoritos
1. **Verificar límites** de favoritos
2. **Actualizar en Core Data** (background thread)
3. **Propagar cambios** a todas las listas
4. **Refrescar contador** en UI
5. **Mostrar feedback** visual

## 🎯 Estado del Proyecto

### ✅ Completado
- [x] Arquitectura Clean Architecture + MVVM especializado
- [x] ViewModels especializados siguiendo SRP
- [x] Composition Pattern con CitySearchCoordinator
- [x] Búsqueda inteligente con priorización
- [x] Sistema de favoritos completo
- [x] Tests unitarios comprehensivos
- [x] Swift 6 concurrency compliance
- [x] Normalización Unicode bidireccional
- [x] Core Data optimizations
- [x] Componentes reutilizables (SearchBarView, CityListView)

### 🔧 Pendientes
- [ ] UI Tests automatizados
- [ ] Navegación entre vistas (MapView, DetailView)
- [ ] Accessibility improvements
- [ ] Error handling UI states mejorados

## Características Técnicas

### Swift 6 Concurrency
- **@MainActor isolation** para thread safety
- **Sendable protocols** en todos los models
- **Async/await** en lugar de completion handlers
- **Strict concurrency** enabled

### Clean Architecture
- **Dependency inversion** con protocols
- **Single responsibility** por clase
- **Separation of concerns** por layers
- **Testable design** con dependency injection

### Performance Engineering
- **Batch operations** para Core Data
- **Background processing** para operaciones pesadas
- **Memory efficient** búsquedas
- **Responsive UI** con debouncing
- **ViewModels especializados** para mejor performance

---

