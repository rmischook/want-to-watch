//
//  MediaType.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import Foundation

enum MediaType: String, Codable, CaseIterable {
    case movie = "movie"
    case tv = "tv"
    
    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tv: return "TV Show"
        }
    }
    
    /// Shorter name for filter buttons
    var filterDisplayName: String {
        switch self {
        case .movie: return "Movie"
        case .tv: return "TV"
        }
    }
}
