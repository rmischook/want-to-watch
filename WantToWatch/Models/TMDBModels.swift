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
    
    var thumbnailPosterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w185\(path)")
    }
    
    var fullBackdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w780\(path)")
    }
}

// MARK: - TV Show Details

struct TMDBTVShowDetails: Codable {
    let id: Int
    let name: String
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let status: String?
    let voteAverage: Double?
    let voteCount: Int?
    let seasons: [TMDBSeason]
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, status, seasons
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}

// MARK: - TV Season

struct TMDBSeason: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let overview: String?
    let airDate: String?
    let episodeCount: Int
    let posterPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case seasonNumber = "season_number"
        case airDate = "air_date"
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
    }
    
    var year: String? {
        guard let date = airDate, !date.isEmpty else { return nil }
        return String(date.prefix(4))
    }
    
    var thumbnailPosterURL: URL? {
        guard let path = posterPath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w185\(path)")
    }
}

// MARK: - TV Season Details (with episodes)

struct TMDBSeasonDetails: Codable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let overview: String?
    let airDate: String?
    let episodes: [TMDBEpisode]
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, episodes
        case seasonNumber = "season_number"
        case airDate = "air_date"
    }
}

// MARK: - TV Episode

struct TMDBEpisode: Codable, Identifiable {
    let id: Int
    let episodeNumber: Int
    let seasonNumber: Int
    let name: String
    let overview: String?
    let airDate: String?
    let stillPath: String?
    let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case airDate = "air_date"
        case stillPath = "still_path"
        case voteAverage = "vote_average"
    }
    
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
}

// MARK: - Credits

struct TMDBCredits: Codable {
    let cast: [TMDBCastMember]
    let crew: [TMDBCrewMember]
}

struct TMDBCastMember: Codable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, character, order
        case profilePath = "profile_path"
    }
    
    var profileImageURL: URL? {
        guard let path = profilePath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w185\(path)")
    }
}

struct TMDBCrewMember: Codable, Identifiable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}

// MARK: - Watch Providers

struct TMDBWatchProviders: Codable {
    let results: [String: TMDBWatchProvidersForCountry]?
}

struct TMDBWatchProvidersForCountry: Codable {
    let flatrate: [TMDBWatchProvider]?
    let rent: [TMDBWatchProvider]?
    let buy: [TMDBWatchProvider]?
    let free: [TMDBWatchProvider]?
    let link: String?  // TMDB page link
}

struct TMDBWatchProvider: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let logoPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
    }
    
    var logoURL: URL? {
        guard let path = logoPath, !path.isEmpty else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w92\(path)")
    }
}
