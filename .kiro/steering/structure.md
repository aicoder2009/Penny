# Project Structure

## Root Directory Layout
```
Penny/
├── Penny.xcodeproj/          # Xcode project configuration
├── Penny/                    # Main source code directory
├── README.md                 # Project documentation
├── README-AI.md             # AI-specific documentation
└── .kiro/                   # Kiro AI assistant configuration
```

## Source Code Organization (`Penny/`)
```
Penny/
├── PennyApp.swift           # Main app entry point (@main)
├── ContentView.swift        # Primary SwiftUI interface with TabView
├── AddTransactionView.swift # Transaction input interface
├── CameraAffordabilityView.swift    # Camera scanner UI
├── CameraAffordabilityTest.swift    # Camera functionality tests
├── VisionProcessor.swift    # Vision/ML processing logic
├── AffordabilityModels.swift # Data models for affordability features
├── Assets.xcassets/         # App icons, colors, and visual assets
├── Info.plist              # App configuration and permissions
└── Preview Content/         # SwiftUI preview assets
```

## Code Architecture Patterns

### File Naming Conventions
- **Views**: `*View.swift` (e.g., `ContentView.swift`, `CameraAffordabilityView.swift`)
- **Models**: `*Models.swift` (e.g., `AffordabilityModels.swift`)
- **Processors**: `*Processor.swift` (e.g., `VisionProcessor.swift`)
- **Tests**: `*Test.swift` (e.g., `CameraAffordabilityTest.swift`)

### Code Organization Within Files
- **MARK Comments**: Use `// MARK: -` to separate logical sections
- **Data Models**: Defined at top of files or in dedicated model files
- **Extensions**: Group related functionality using extensions
- **View Hierarchy**: Main views contain child views and components

### Key Architectural Components
- **BudgetViewModel**: Central ObservableObject managing app state
- **Transaction/Budget/Streak Models**: Core data structures
- **Category Enums**: Expense and income categorization
- **Vision Processing**: Camera-based object detection and price estimation
- **Affordability Engine**: AI-powered purchase decision logic

## Asset Organization
- **App Icons**: Standard iOS app icon sizes in `Assets.xcassets/AppIcon.appiconset/`
- **Colors**: Accent colors and theme colors in `Assets.xcassets/AccentColor.colorset/`
- **Preview Assets**: Development-only assets in `Preview Content/`

## Configuration Files
- **Info.plist**: Contains camera usage permissions and app metadata
- **project.pbxproj**: Xcode build configuration with iOS 17.0 deployment target
- **Bundle Identifier**: `com.aicoder2009.Penny`