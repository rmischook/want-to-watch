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
    var id: UUID
    var tmdbId: Int
    var title: String
    var originalTitle: String?
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var releaseDate: Date?
    var voteAverage: Double
    var voteCount: Int
    var popularity: Double
    var genres: [String]
    var originalLanguage: String?
    var mediaTypeRaw: String
    var watchStatusRaw: String
    var sourceUrl: URL?
    var dateAdded: Date
    var userRating: Double?
    var notes: String?
    
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
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }
    
    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
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
