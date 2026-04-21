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
    case watched = "Watched"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .wantToWatch: return "bookmark"
        case .watching: return "play.circle"
        case .watched: return "checkmark.circle"
        }
    }
}
