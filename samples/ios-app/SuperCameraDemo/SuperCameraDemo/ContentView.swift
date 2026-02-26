import Foundation

/// Describes the content view structure for the iOS demo.
/// In a real Xcode project, this would be a SwiftUI View.
/// For SPM library builds, this serves as documentation.
struct ContentView {
    static let description = """
    SuperCamera Demo UI:
    - Preview Placeholder
    - [Start Preview] [Take Photo]
    - [Start/Stop Record] [Toggle UI Badge]
    - UI Badge: {badge}
    - {lastMessage}
    """
}
