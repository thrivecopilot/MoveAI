# MoveAI Project Rules

## Architecture Contract

### Core Framework
- **SwiftUI** for UI layer
- **Mini-TCA (The Composable Architecture)** pattern for state management
- **No external dependencies** - use only Apple frameworks

### State Management

#### Single Source of Truth
```swift
@MainActor
class AppStore: ObservableObject {
    @Published private(set) var state: AppState
    private let services: Services
    
    func send(_ action: AppAction) {
        // Only place that mutates state
    }
}
```

#### State Structure
- **AppState**: Value type containing all app state
- **Route**: Enum for navigation state
- **AppAction**: Enum describing all possible mutations

#### Reducer Pattern
- `func send(_ action: AppAction)` is the **only** place that mutates state
- All state changes flow through this single function
- No direct state mutations anywhere else

### Dependencies

#### Service Layer
```swift
struct Services {
    var auth: AuthService
    var health: HealthService
    // Add other services as needed
}
```

#### Implementation Strategy
- **Live implementations** for production
- **Fake implementations** for testing and previews
- Dependency injection through Services struct

### View Layer

#### Stateless Views
- Views are **stateless** - no `@State` or `@ObservedObject` for business logic
- Read from `store.state`
- Dispatch actions via `store.send(_)`
- **No side-effects** in `body` - all side-effects go through actions

#### View Structure
```swift
struct SomeView: View {
    let store: AppStore
    
    var body: some View {
        // Read from store.state
        // Dispatch via store.send(_)
        // No side-effects here
    }
}
```

### Concurrency

#### Main Actor Enforcement
- All state writes happen on main thread
- `@MainActor` on AppStore ensures thread safety
- Async operations complete on main thread

#### Async Pattern
```swift
Task {
    let result = await services.auth.signIn()
    await MainActor.run {
        // Update state here
    }
}
```

### Navigation

#### Navigation Invariant
```swift
// This must always be true:
route == .home <=> isSignedIn && hasHealthPermissions
```

#### Route Management
- Single function `updateRoute()` controls all navigation
- App can switch routes by editing this one function
- Navigation state is derived from business state

### Output Style

#### Code Format
- **Unified diffs only** - show only the changes
- **Compilable Swift** - all code must build without errors
- **#Preview** for each SwiftUI view
- **Minimal XCTest** for reducer transitions

#### Testing Requirements
- Cover **happy paths** and **failure paths**
- Test reducer state transitions
- Mock dependencies for isolated testing

## Red Flags (Never Do)

### ❌ Multiple Sources of Truth
- **Never** have duplicate onboarding flags
- **Never** store the same data in multiple places
- **Always** unify to single source of truth

### ❌ Off-Main State Writes
- **Never** write to `@Published` properties off main thread
- **Always** use `@MainActor` or `MainActor.run`

### ❌ Side-Effects in Views
- **Never** perform side-effects in `body`
- **Always** dispatch actions instead

### ❌ Public Type Renaming
- **Never** rename public types once introduced
- **Always** maintain API stability

## Self-Check Questions

Before submitting any code, ask:

1. **Did any mutation happen outside AppStore.send?**
   - If yes, move it to the reducer

2. **Are there duplicate sources of truth?**
   - If yes, unify them

3. **Are async completions writing on main?**
   - If no, fix the concurrency

4. **Do tests cover happy + failure paths?**
   - If no, add missing test cases

5. **Can the app switch routes by editing a single function?**
   - If no, refactor navigation logic

## Implementation Guidelines

### State Structure Example
```swift
struct AppState {
    var route: Route = .onboarding
    var isSignedIn: Bool = false
    var hasHealthPermissions: Bool = false
    var userProfile: UserProfile?
    var isLoading: Bool = false
    var errorMessage: String?
}

enum Route {
    case onboarding
    case home
    case profile
}

enum AppAction {
    case signInTapped
    case signInSucceeded
    case signInFailed(Error)
    case healthPermissionRequested
    case healthPermissionGranted
    case healthPermissionDenied
    case profileUpdated(UserProfile)
    case routeChanged(Route)
}
```

### Service Protocol Example
```swift
protocol AuthService {
    func signIn() async throws -> User
    func signOut() async
}

protocol HealthService {
    func requestPermissions() async throws -> Bool
    func syncUserData() async throws -> UserProfile
}
```

### View Example
```swift
struct OnboardingView: View {
    let store: AppStore
    
    var body: some View {
        VStack {
            if store.state.isLoading {
                ProgressView()
            } else {
                Button("Sign In") {
                    store.send(.signInTapped)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(store: AppStore(services: .fakes))
}
```

## Testing Strategy

### Reducer Tests
```swift
func testSignInSuccess() {
    let store = AppStore(services: .fakes)
    store.send(.signInTapped)
    // Assert state changes
    XCTAssertTrue(store.state.isSignedIn)
    XCTAssertEqual(store.state.route, .home)
}
```

### Service Tests
```swift
func testAuthServiceSignIn() async throws {
    let service = AuthService.fake
    let user = try await service.signIn()
    XCTAssertNotNil(user)
}
```

---

**Remember**: This architecture ensures predictable state management, testable code, and maintainable SwiftUI applications. Follow these rules religiously to avoid common pitfalls and maintain code quality.

