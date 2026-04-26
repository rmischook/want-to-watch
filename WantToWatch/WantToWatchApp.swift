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
    
    init() {
        // Initialize iCloud key-value store early
        _ = NSUbiquitousKeyValueStore.default
    }
    
    var sharedModelContainer: ModelContainer = {
        // Copy API key to App Groups container for extension access
        copyAPIKeyToAppGroup()
        
        let schema = Schema([
            WatchlistItem.self,
            Season.self,
            Episode.self,
            CastMember.self,
            CrewMember.self,
        ])
        
        print("[CloudKit] Setting up ModelContainer...")
        print("[CloudKit] Schema: \(schema)")
        
        // Use App Group container for shared storage
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.rmischook.WantToWatch"
        ) else {
            fatalError("App Groups container not available. Ensure 'group.com.rmischook.WantToWatch' is configured in entitlements.")
        }
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
            RootView(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                modelContainer: sharedModelContainer
            )
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

// MARK: - Root View

struct RootView: View {
    @Binding var hasCompletedOnboarding: Bool
    let modelContainer: ModelContainer
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        #if DEBUG
        .onAppear {
            refreshAllItemDataIfEnabled()
        }
        #endif
    }
    
    #if DEBUG
    private func refreshAllItemDataIfEnabled() {
        guard ProcessInfo.processInfo.environment["REFRESH_ALL_DATA"] == "1" else { return }
        
        print("[DEBUG] REFRESH_ALL_DATA enabled - refreshing all item data...")
        
        Task {
            let context = modelContainer.mainContext
            let descriptor = FetchDescriptor<WatchlistItem>()
            
            do {
                let items = try context.fetch(descriptor)
                
                // Only refresh items missing data
                let needsRefresh = items.filter { item in
                    item.imdbId == nil ||
                    item.runtime == nil ||
                    item.castList.isEmpty ||
                    item.crewList.isEmpty ||
                    item.watchProviders.isEmpty
                }
                
                print("[DEBUG] Found \(items.count) items, \(needsRefresh.count) need refresh:")
                for item in needsRefresh {
                    let missing: [String] = [
                        item.imdbId == nil ? "imdbId" : nil,
                        item.runtime == nil ? "runtime" : nil,
                        item.castList.isEmpty ? "cast" : nil,
                        item.crewList.isEmpty ? "crew" : nil,
                        item.watchProviders.isEmpty ? "providers" : nil,
                    ].compactMap { $0 }
                    print("[DEBUG]   - \(item.title) (missing: \(missing.joined(separator: ", ")))")
                }
                
                // DRY RUN: skip actual fetching
                // print("[DEBUG] DRY RUN - skipping fetch. Remove this line to actually refresh.")
                // return
                
                for (index, item) in needsRefresh.enumerated() {
                    print("[DEBUG] Refreshing \(item.title) (\(index + 1)/\(needsRefresh.count))")
                    await refreshItemData(item: item, context: context)
                    // Throttle to avoid CloudKit rate limiting
                    try? await Task.sleep(for: .seconds(2))
                }
                
                // Save once after all items are refreshed
                try? context.save()
                print("[DEBUG] ✅ Finished refreshing all items")
            } catch {
                print("[DEBUG] ❌ Error fetching items: \(error)")
            }
        }
    }
    
    private func refreshItemData(item: WatchlistItem, context: ModelContext) async {
        do {
            // Fetch details for runtime and IMDB ID
            let imdbId: String?
            let runtime: Int?
            
            if item.mediaType == .tv {
                let details = try await TMDBService.getTVShowDetails(tvId: item.tmdbId)
                imdbId = details.imdbId
                runtime = details.episodeRunTime?.first
            } else {
                let details = try await TMDBService.getMovieDetails(movieId: item.tmdbId)
                imdbId = details.imdbId
                runtime = details.runtime
            }
            
            // Fetch credits
            let credits: TMDBCredits
            if item.mediaType == .tv {
                credits = try await TMDBService.getTVCredits(tvId: item.tmdbId)
            } else {
                credits = try await TMDBService.getMovieCredits(movieId: item.tmdbId)
            }
            
            // Fetch watch providers
            let region = Locale.current.region?.identifier ?? "US"
            let watchProviders: TMDBWatchProviders
            if item.mediaType == .tv {
                watchProviders = try await TMDBService.getTVWatchProviders(tvId: item.tmdbId)
            } else {
                watchProviders = try await TMDBService.getMovieWatchProviders(movieId: item.tmdbId)
            }
            
            await MainActor.run {
                if item.imdbId == nil { item.imdbId = imdbId }
                if item.runtime == nil { item.runtime = runtime }
                
                item.castList = credits.cast.map { CastMember(from: $0) }
                item.crewList = credits.crew.map { CrewMember(from: $0) }
                
                if let countryProviders = watchProviders.results?[region] {
                    var allProviders: [StoredWatchProvider] = []
                    var seenIds = Set<Int>()
                    
                    for providerList in [countryProviders.flatrate, countryProviders.rent, countryProviders.buy, countryProviders.free] {
                        guard let providers = providerList else { continue }
                        for provider in providers {
                            if !seenIds.contains(provider.id) {
                                seenIds.insert(provider.id)
                                allProviders.append(StoredWatchProvider(from: provider))
                            }
                        }
                    }
                    
                    item.watchProviders = allProviders
                }
                
                print("[DEBUG] ✅ Refreshed: \(item.title)")
            }
        } catch {
            print("[DEBUG] ❌ Error refreshing \(item.title): \(error.localizedDescription)")
        }
    }
    #endif
}
