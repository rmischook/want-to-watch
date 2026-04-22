//
//  TMDBService.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import Foundation

enum TMDBService {
    static private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    
    static private let decoder: JSONDecoder = JSONDecoder()
    
    // MARK: - Private Helper
    
    private static func fetch<T: Codable>(endpoint: String) async throws -> T {
        let apiKey = TMDBConfig.getAPIKey()
        
        guard !apiKey.isEmpty else {
            throw TMDBError.apiKeyNotConfigured
        }
        
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/\(endpoint)")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TMDBError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw TMDBError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Search
    
    static func search(query: String, page: Int = 1) async throws -> TMDBSearchResponse {
        let apiKey = TMDBConfig.getAPIKey()
        
        guard !apiKey.isEmpty else {
            throw TMDBError.apiKeyNotConfigured
        }
        
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/search/multi")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        guard let url = components.url else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TMDBError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            return try decoder.decode(TMDBSearchResponse.self, from: data)
        } catch {
            throw TMDBError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - TV Show Details
    
    static func getTVShowDetails(tvId: Int) async throws -> TMDBTVShowDetails {
        try await fetch(endpoint: "tv/\(tvId)")
    }
    
    // MARK: - TV Season Details
    
    static func getTVSeasonDetails(tvId: Int, seasonNumber: Int) async throws -> TMDBSeasonDetails {
        try await fetch(endpoint: "tv/\(tvId)/season/\(seasonNumber)")
    }
    
    // MARK: - Credits
    
    static func getMovieCredits(movieId: Int) async throws -> TMDBCredits {
        try await fetch(endpoint: "movie/\(movieId)/credits")
    }
    
    static func getTVCredits(tvId: Int) async throws -> TMDBCredits {
        try await fetch(endpoint: "tv/\(tvId)/credits")
    }
    
    // MARK: - Watch Providers
    
    static func getMovieWatchProviders(movieId: Int) async throws -> TMDBWatchProviders {
        try await fetch(endpoint: "movie/\(movieId)/watch/providers")
    }
    
    static func getTVWatchProviders(tvId: Int) async throws -> TMDBWatchProviders {
        try await fetch(endpoint: "tv/\(tvId)/watch/providers")
    }
}

// MARK: - Errors

enum TMDBError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(String)
    case apiKeyNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .apiKeyNotConfigured:
            return "TMDB API key not configured. Please add your key to tmdb_api_key.txt"
        }
    }
}
