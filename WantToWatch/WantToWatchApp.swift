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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WatchlistItem.self,
        ])
        
        print("[CloudKit] Setting up ModelContainer...")
        print("[CloudKit] Schema: \(schema)")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
