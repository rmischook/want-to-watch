//
//  Season.swift
//  WantToWatch
//
//  Created on 26/04/2026.
//

import Foundation
import SwiftData

@Model
final class Season {
    var id: Int = 0
    var seasonNumber: Int = 0
    var name: String = ""
    var overview: String?
    var airDate: String?
    var episodeCount: Int = 0
    var posterPath: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade)
    var episodes: [Episode]?
    
    var show: WatchlistItem?
    
    // Convenience accessor
    var episodesList: [Episode] {
        get { episodes ?? [] }
        set { episodes = newValue.isEmpty ? nil : newValue }
    }
    
    var year: String? {
        guard let date = airDate, !date.isEmpty else { return nil }
        return String(date.prefix(4))
    }
    
    var thumbnailPosterURL: URL? {
        guard let path = posterPath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w185\(path)")
    }
    
    init(from tmdbSeason: TMDBSeason) {
        self.id = tmdbSeason.id
        self.seasonNumber = tmdbSeason.seasonNumber
        self.name = tmdbSeason.name
        self.overview = tmdbSeason.overview
        self.airDate = tmdbSeason.airDate
        self.episodeCount = tmdbSeason.episodeCount
        self.posterPath = tmdbSeason.posterPath
    }
    
    init(from tmdbSeasonDetails: TMDBSeasonDetails, seasonNumber: Int) {
        self.id = tmdbSeasonDetails.id
        self.seasonNumber = seasonNumber
        self.name = tmdbSeasonDetails.name
        self.overview = tmdbSeasonDetails.overview
        self.airDate = tmdbSeasonDetails.airDate
        self.episodeCount = tmdbSeasonDetails.episodes.count
        self.posterPath = nil // Season details don't include poster
    }
}
