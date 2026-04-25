//
//  WatchlistItem.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import Foundation
import SwiftData

@Model
final class WatchlistItem: Equatable, Hashable {
    var id: UUID = UUID()
    var tmdbId: Int = 0
    var title: String = ""
    var originalTitle: String?
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var releaseDate: Date?
    var voteAverage: Double = 0
    var voteCount: Int = 0
    var popularity: Double = 0
    var genres: [String] = []
    var originalLanguage: String?
    var mediaTypeRaw: String = MediaType.movie.rawValue
    var watchStatusRaw: String = WatchStatus.wantToWatch.rawValue
    var sourceUrl: URL?
    var dateAdded: Date = Date()
    var userRating: Double?
    var notes: String?
    
    // TV Show specific data
    var seasonsJSON: Data?  // Stored as JSON encoded [StoredSeason]
    
    // Cast data
    var castJSON: Data?  // Stored as JSON encoded [StoredCastMember]
    
    // Watch providers data
    var watchProvidersJSON: Data?  // Stored as JSON encoded [StoredWatchProvider]
    
    // Equatable conformance
    static func == (lhs: WatchlistItem, rhs: WatchlistItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Computed properties for enums
    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .movie }
        set { mediaTypeRaw = newValue.rawValue }
    }
    
    var watchStatus: WatchStatus {
        get { WatchStatus(rawValue: watchStatusRaw) ?? .wantToWatch }
        set { watchStatusRaw = newValue.rawValue }
    }
    
    // Full image URLs
    var thumbnailPosterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }
    
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }
    
    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }
    
    // Seasons access
    var seasons: [StoredSeason] {
        get {
            guard let data = seasonsJSON else { return [] }
            return (try? JSONDecoder().decode([StoredSeason].self, from: data)) ?? []
        }
        set {
            seasonsJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    // Cast access
    var cast: [StoredCastMember] {
        get {
            guard let data = castJSON else { return [] }
            return (try? JSONDecoder().decode([StoredCastMember].self, from: data)) ?? []
        }
        set {
            castJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    // Watch providers access
    var watchProviders: [StoredWatchProvider] {
        get {
            guard let data = watchProvidersJSON else { return [] }
            return (try? JSONDecoder().decode([StoredWatchProvider].self, from: data)) ?? []
        }
        set {
            watchProvidersJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(from searchResult: TMDBSearchResult, sourceUrl: URL? = nil) {
        self.id = UUID()
        self.tmdbId = searchResult.id
        self.title = searchResult.displayTitle
        self.originalTitle = searchResult.originalTitle ?? searchResult.originalName
        self.overview = searchResult.overview
        self.posterPath = searchResult.posterPath
        self.backdropPath = searchResult.backdropPath
        self.voteAverage = searchResult.voteAverage ?? 0
        self.voteCount = searchResult.voteCount ?? 0
        self.popularity = searchResult.popularity ?? 0
        self.genres = []
        self.originalLanguage = searchResult.originalLanguage
        self.mediaTypeRaw = searchResult.mediaType == "tv" ? MediaType.tv.rawValue : MediaType.movie.rawValue
        
        // Parse date if available
        if let dateString = searchResult.displayDate, !dateString.isEmpty {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            self.releaseDate = formatter.date(from: String(dateString.prefix(10)))
        } else {
            self.releaseDate = nil
        }
        
        self.watchStatusRaw = WatchStatus.wantToWatch.rawValue
        self.sourceUrl = sourceUrl
        self.dateAdded = Date()
        self.userRating = nil
        self.notes = nil
        self.seasonsJSON = nil
        self.castJSON = nil
    }
}

// MARK: - Stored Cast Member

struct StoredCastMember: Codable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    
    var profileImageURL: URL? {
        guard let path = profilePath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w185\(path)")
    }
    
    init(from tmdbCast: TMDBCastMember) {
        self.id = tmdbCast.id
        self.name = tmdbCast.name
        self.character = tmdbCast.character
        self.profilePath = tmdbCast.profilePath
    }
}

// MARK: - Stored Watch Provider

struct StoredWatchProvider: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let logoPath: String?
    
    var logoURL: URL? {
        guard let path = logoPath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w92\(path)")
    }
    
    init(from tmdbProvider: TMDBWatchProvider) {
        self.id = tmdbProvider.id
        self.name = tmdbProvider.name
        self.logoPath = tmdbProvider.logoPath
    }
}

// MARK: - Stored Episode

struct StoredEpisode: Codable, Identifiable {
    let id: Int
    let episodeNumber: Int
    let seasonNumber: Int
    let name: String
    let overview: String?
    let airDate: String?
    let stillPath: String?
    let voteAverage: Double
    
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
    
    init(from tmdbEpisode: TMDBEpisode) {
        self.id = tmdbEpisode.id
        self.episodeNumber = tmdbEpisode.episodeNumber
        self.seasonNumber = tmdbEpisode.seasonNumber
        self.name = tmdbEpisode.name
        self.overview = tmdbEpisode.overview
        self.airDate = tmdbEpisode.airDate
        self.stillPath = tmdbEpisode.stillPath
        self.voteAverage = tmdbEpisode.voteAverage ?? 0
    }
}

// MARK: - Stored Season

struct StoredSeason: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let overview: String?
    let airDate: String?
    let episodeCount: Int
    let posterPath: String?
    var episodes: [StoredEpisode]
    
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
        self.episodes = [] // Episodes are loaded separately
    }
    
    init(from tmdbSeasonDetails: TMDBSeasonDetails) {
        self.id = tmdbSeasonDetails.id
        self.seasonNumber = tmdbSeasonDetails.seasonNumber
        self.name = tmdbSeasonDetails.name
        self.overview = tmdbSeasonDetails.overview
        self.airDate = tmdbSeasonDetails.airDate
        self.episodeCount = tmdbSeasonDetails.episodes.count
        self.posterPath = nil // Season details don't include poster
        self.episodes = tmdbSeasonDetails.episodes.map { StoredEpisode(from: $0) }
    }
}
