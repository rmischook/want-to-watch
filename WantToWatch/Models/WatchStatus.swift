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
}
