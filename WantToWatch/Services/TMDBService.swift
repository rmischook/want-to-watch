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
    
    // MARK: - Search
    
    static func search(query: String, page: Int = 1) async throws -> TMDBSearchResponse {
        let apiKey = TMDBConfig.getAPIKey()
        
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
        let apiKey = TMDBConfig.getAPIKey()
        
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/tv/\(tvId)")!
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
            return try decoder.decode(TMDBTVShowDetails.self, from: data)
        } catch {
            throw TMDBError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - TV Season Details
    
    static func getTVSeasonDetails(tvId: Int, seasonNumber: Int) async throws -> TMDBSeasonDetails {
        let apiKey = TMDBConfig.getAPIKey()
        
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/tv/\(tvId)/season/\(seasonNumber)")!
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
            return try decoder.decode(TMDBSeasonDetails.self, from: data)
        } catch {
            throw TMDBError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Credits
    
    static func getMovieCredits(movieId: Int) async throws -> TMDBCredits {
        let apiKey = TMDBConfig.getAPIKey()
        
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/movie/\(movieId)/credits")!
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
            return try decoder.decode(TMDBCredits.self, from: data)
        } catch {
            throw TMDBError.decodingError(error.localizedDescription)
        }
    }
    
    static func getTVCredits(tvId: Int) async throws -> TMDBCredits {
        let apiKey = TMDBConfig.getAPIKey()
        
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/tv/\(tvId)/credits")!
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
            return try decoder.decode(TMDBCredits.self, from: data)
        } catch {
            throw TMDBError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum TMDBError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(String)
    
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
        }
    }
}
