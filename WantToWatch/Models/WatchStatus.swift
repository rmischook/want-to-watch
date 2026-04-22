//
//  WatchStatus.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import Foundation

enum WatchStatus: String, Codable, CaseIterable {
    case wantToWatch = "Want to Watch"
    case watching = "Watching"
    case waiting = "Waiting"
    case watched = "Watched"
    
    var displayName: String {
        return rawValue
    }
    
    /// Shorter name for filter buttons
    var filterDisplayName: String {
        switch self {
        case .wantToWatch: return "Want to"
        case .watching: return "Watching"
        case .waiting: return "Waiting"
        case .watched: return "Watched"
        }
    }
    
    var icon: String {
        switch self {
        case .wantToWatch: return "bookmark"
        case .watching: return "play.circle"
        case .waiting: return "clock"
        case .watched: return "checkmark.circle"
        }
    }
}
