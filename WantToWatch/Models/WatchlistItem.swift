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
    
    // External IDs
    var imdbId: String?
    
    // Runtime (movie total or TV typical episode runtime in minutes)
    var runtime: Int?
    
    // Relationships
    @Relationship(deleteRule: .cascade)
    var seasons: [Season]?
    
    @Relationship(deleteRule: .cascade)
    var cast: [CastMember]?
    
    @Relationship(deleteRule: .cascade)
    var crew: [CrewMember]?
    
    // Convenience accessors
    var seasonsList: [Season] {
        get { seasons ?? [] }
        set { seasons = newValue.isEmpty ? nil : newValue }
    }
    
    var castList: [CastMember] {
        get { cast ?? [] }
        set { cast = newValue.isEmpty ? nil : newValue }
    }
    
    var crewList: [CrewMember] {
        get { crew ?? [] }
        set { crew = newValue.isEmpty ? nil : newValue }
    }
    
    // Watch providers stored as JSON (no need for relationships for search)
    var watchProvidersJSON: Data?
    
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
    
    // Formatted runtime display
    var displayRuntime: String? {
        guard let runtime = runtime, runtime > 0 else { return nil }
        if mediaType == .movie {
            let hours = runtime / 60
            let minutes = runtime % 60
            if hours > 0 {
                return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
            } else {
                return "\(minutes)m"
            }
        } else {
            return "\(runtime) min/ep"
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
