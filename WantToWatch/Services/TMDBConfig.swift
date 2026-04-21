//
//  TMDBConfig.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import Foundation

enum TMDBConfig {
    static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p"
    
    static func getAPIKey() -> String {
        guard let url = Bundle.main.url(forResource: "tmdb_api_key", withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              key != "YOUR_TMDB_API_KEY_HERE"
        else {
            fatalError("TMDB API key not found or not configured. Please add your key to tmdb_api_key.txt")
        }
        return key
    }
}
