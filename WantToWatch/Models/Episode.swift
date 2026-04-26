//
//  Episode.swift
//  WantToWatch
//
//  Created on 26/04/2026.
//

import Foundation
import SwiftData

@Model
final class Episode {
    var id: Int = 0
    var episodeNumber: Int = 0
    var seasonNumber: Int = 0
    var name: String = ""
    var overview: String?
    var airDate: String?
    var stillPath: String?
    var voteAverage: Double = 0
    var runtime: Int?
    
    // Relationship to season
    var season: Season?
    
    var displayAirDate: String? {
        guard let date = airDate, !date.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let parsedDate = formatter.date(from: String(date.prefix(10))) {
            return parsedDate.formatted(date: .abbreviated, time: .omitted)
        }
        return nil
    }
    
    var stillImageURL: URL? {
        guard let path = stillPath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w300\(path)")
    }
    
    var displayRuntime: String? {
        guard let runtime = runtime, runtime > 0 else { return nil }
        return "\(runtime) min"
    }
    
    init(from tmdbEpisode: TMDBEpisode) {
        self.id = tmdbEpisode.id
        self.episodeNumber = tmdbEpisode.episodeNumber
        self.seasonNumber = tmdbEpisode.seasonNumber
        self.name = tmdbEpisode.name
        self.overview = tmdbEpisode.overview
        self.airDate = tmdbEpisode.airDate
        self.stillPath = tmdbEpisode.stillPath
        self.voteAverage = tmdbEpisode.voteAverage ?? 0
        self.runtime = tmdbEpisode.runtime
    }
}
