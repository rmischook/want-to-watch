//
//  WantToWatchApp.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import SwiftUI
import SwiftData

@main
struct WantToWatchApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var sharedModelContainer: ModelContainer = {
        // Copy API key to App Groups container for extension access
        copyAPIKeyToAppGroup()
        
        let schema = Schema([
            WatchlistItem.self,
        ])
        
        print("[CloudKit] Setting up ModelContainer...")
        print("[CloudKit] Schema: \(schema)")
        
        // Use App Group container for shared storage
        let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.rmischook.WantToWatch"
        )!
        let storeURL = appGroupURL.appendingPathComponent("default.store")
        
        print("[CloudKit] App Group URL: \(storeURL.path)")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private("iCloud.com.rmischook.WantToWatch")
        )
        
        print("[CloudKit] Configuration: \(modelConfiguration)")
        print("[CloudKit] CloudKit Database: \(modelConfiguration.cloudKitDatabase)")
        print("[CloudKit] URL: \(modelConfiguration.url.path)")

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[CloudKit] ✅ ModelContainer created successfully")
            return container
        } catch {
            print("[CloudKit] ❌ Could not create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// Copy API key from main bundle to App Groups container for extension access
    private static func copyAPIKeyToAppGroup() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.rmischook.WantToWatch"
        ) else {
            NSLog("[WantToWatch] Could not get App Groups container")
            return
        }
        
        let destinationURL = containerURL.appendingPathComponent("tmdb_api_key.txt")
        NSLog("[WantToWatch] Destination URL: \(destinationURL.path)")
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
            NSLog("[WantToWatch] Removed existing file")
        }
        
        // Copy from main bundle
        if let sourceURL = Bundle.main.url(forResource: "tmdb_api_key", withExtension: "txt") {
            NSLog("[WantToWatch] Source URL: \(sourceURL.path)")
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                NSLog("[WantToWatch] ✅ Copied API key to App Groups container")
            } catch {
                NSLog("[WantToWatch] ❌ Failed to copy: \(error)")
            }
        } else {
            NSLog("[WantToWatch] Could not find tmdb_api_key.txt in bundle")
        }
    }
}
