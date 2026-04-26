//
//  CastMember.swift
//  WantToWatch
//
//  Created on 26/04/2026.
//

import Foundation
import SwiftData

@Model
final class CastMember {
    var id: Int = 0
    var name: String = ""
    var character: String?
    var profilePath: String?
    var order: Int = 0
    
    // Relationship to show/movie
    var show: WatchlistItem?
    
    var profileImageURL: URL? {
        guard let path = profilePath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w185\(path)")
    }
    
    init(from tmdbCast: TMDBCastMember) {
        self.id = tmdbCast.id
        self.name = tmdbCast.name
        self.character = tmdbCast.character
        self.profilePath = tmdbCast.profilePath
        self.order = tmdbCast.order
    }
}
