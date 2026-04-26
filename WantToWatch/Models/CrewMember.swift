//
//  CrewMember.swift
//  WantToWatch
//
//  Created on 26/04/2026.
//

import Foundation
import SwiftData

@Model
final class CrewMember {
    var id: Int = 0
    var name: String = ""
    var job: String?
    var department: String?
    var profilePath: String?
    
    // Relationship to show/movie
    var show: WatchlistItem?
    
    var profileImageURL: URL? {
        guard let path = profilePath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w185\(path)")
    }
    
    init(from tmdbCrew: TMDBCrewMember) {
        self.id = tmdbCrew.id
        self.name = tmdbCrew.name
        self.job = tmdbCrew.job
        self.department = tmdbCrew.department
        self.profilePath = tmdbCrew.profilePath
    }
}
