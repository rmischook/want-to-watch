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
        NSLog("[TMDBConfig] Looking for API key...")
        
        // Try to get from bundle first (works for main app)
        if let url = Bundle.main.url(forResource: "tmdb_api_key", withExtension: "txt") {
            NSLog("[TMDBConfig] Found in bundle: \(url.path)")
            if let data = try? Data(contentsOf: url),
               let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty,
               key != "YOUR_TMDB_API_KEY_HERE" {
                NSLog("[TMDBConfig] Got key from bundle, length: \(key.count)")
                return key
            }
        }
        
        // Fallback: try App Groups shared location
        NSLog("[TMDBConfig] Trying App Groups container...")
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.rmischook.WantToWatch") {
            NSLog("[TMDBConfig] Container URL: \(containerURL.path)")
            let fileURL = containerURL.appendingPathComponent("tmdb_api_key.txt")
            NSLog("[TMDBConfig] Looking for file at: \(fileURL.path)")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                NSLog("[TMDBConfig] File exists!")
                if let data = try? Data(contentsOf: fileURL),
                   let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !key.isEmpty {
                    NSLog("[TMDBConfig] Got key from App Groups, length: \(key.count)")
                    return key
                }
            } else {
                NSLog("[TMDBConfig] File does NOT exist at that path")
            }
        }
        
        NSLog("[TMDBConfig] FAILED to find API key")
        // Return empty string - API calls will fail with proper error handling
        // This prevents crashes in production while still logging the issue
        return ""
    }
}
