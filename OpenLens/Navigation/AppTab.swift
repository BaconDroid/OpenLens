import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case chat
    case micro
    case review
    case workspace
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: "Sessions"
        case .micro: "Micro"
        case .review: "Review"
        case .workspace: "Workspace"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .chat: "message"
        case .micro: "command"
        case .review: "magnifyingglass.circle"
        case .workspace: "folder"
        case .settings: "gearshape"
        }
    }
}
