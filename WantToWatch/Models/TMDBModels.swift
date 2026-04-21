//
//  TMDBModels.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import Foundation

// MARK: - Search Response

struct TMDBSearchResponse: Codable {
    let page: Int
    let results: [TMDBSearchResult]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Search Result (multi search returns both movies and TV)

struct TMDBSearchResult: Codable, Identifiable {
    let id: Int
    let title: String?
    let name: String?                    // TV shows use "name" instead of "title"
    let originalTitle: String?
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let mediaType: String                // "movie" or "tv"
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let releaseDate: String?             // For movies
    let firstAirDate: String?            // For TV shows
    let genreIds: [Int]?
    let originalLanguage: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, popularity
        case originalTitle = "original_title"
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case mediaType = "media_type"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case genreIds = "genre_ids"
        case originalLanguage = "original_language"
    }
    
    // Computed properties for convenience
    var displayTitle: String {
        title ?? name ?? "Unknown"
    }
    
    var displayDate: String? {
        releaseDate ?? firstAirDate
    }
    
    var year: String? {
        guard let date = displayDate, !date.isEmpty else { return nil }
        return String(date.prefix(4))
    }
    
    var fullPosterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w342\(path)")
    }
    
    var fullBackdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w780\(path)")
    }
}
