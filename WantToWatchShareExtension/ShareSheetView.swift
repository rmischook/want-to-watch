//
//  ShareSheetView.swift
//  WantToWatchShareExtension
//
//  Created on 21/04/2026.
//

import SwiftUI
import SwiftData

struct ShareSheetView: View {
    let sharedURL: URL?
    let initialSearchText: String?
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var extractedTitle: String?
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var searchText: String = ""
    @State private var isLoading = true
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var addedItemIds: Set<Int> = []
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    emptySearchView
                } else {
                    resultsView
                }
            }
            .navigationTitle("Add to Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .task {
            await processSharedURL()
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                await searchTMDB(query: newValue)
            }
        }
    }
    
    // MARK: - Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Looking up title...")
                .font(.headline)
            if let host = sharedURL?.host {
                Text(host)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Could not identify content")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Show manual search option
            VStack(spacing: 12) {
                Text("Search manually:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Search movies & TV shows", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private var emptySearchView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No matches found for \"\(searchText)\"")
        }
    }
    
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search movies & TV shows", text: $searchText)
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Results list
            if isSearching {
                ProgressView()
                    .padding()
            } else {
                List(searchResults) { result in
                    ResultRow(result: result, isAdded: addedItemIds.contains(result.id)) {
                        await addToWatchlist(result)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Logic
    
    private func processSharedURL() async {
        // If we have initial search text (from text sharing), use it directly
        if let initialText = initialSearchText {
            extractedTitle = initialText
            searchText = initialText
            isLoading = false
            // Trigger the search
            await searchTMDB(query: initialText)
            return
        }
        
        // Otherwise, try to process URL
        guard let url = sharedURL else {
            errorMessage = "No URL or search text provided"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch the page content
            let html = try await fetchPageContent(url: url)
            NSLog("[ShareExtension] Fetched HTML, length: \(html.count)")
            
            // Parse the title
            if let title = parseTitle(from: html, url: url) {
                NSLog("[ShareExtension] Extracted title: \(title)")
                extractedTitle = title
                searchText = title
            } else {
                // Could not extract title
                errorMessage = "Could not find title on page"
                isLoading = false
            }
        } catch {
            NSLog("[ShareExtension] Error fetching page: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func fetchPageContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func parseTitle(from html: String, url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        
        // Use appropriate parser based on domain
        if host.contains("netflix") {
            return parseNetflixTitle(from: html)
        } else if host.contains("tv.apple") || host.contains("apple.com/tv") {
            return parseAppleTVTitle(from: html)
        } else if host.contains("primevideo") || host.contains("amazon") {
            return parsePrimeVideoTitle(from: html)
        } else if host.contains("nowtv") || host.contains("now.tv") {
            return parseNowTVTitle(from: html)
        } else {
            // Generic parser - try og:title or title tag
            return parseGenericTitle(from: html)
        }
    }
    
    // MARK: - Platform-specific Parsers
    
    private func parseNetflixTitle(from html: String) -> String? {
        // Try og:title first
        if let ogTitle = extractMetaContent(html: html, property: "og:title") {
            return cleanNetflixTitle(ogTitle)
        }
        
        // Try title tag
        if let title = extractTitleTag(html: html) {
            return cleanNetflixTitle(title)
        }
        
        return nil
    }
    
    private func cleanNetflixTitle(_ title: String) -> String {
        var cleaned = title
        
        // Remove common Netflix suffixes/prefixes
        cleaned = cleaned.replacingOccurrences(of: "Watch ", with: "")
        cleaned = cleaned.replacingOccurrences(of: " | Netflix Official Site", with: "")
        cleaned = cleaned.replacingOccurrences(of: " | Netflix", with: "")
        cleaned = cleaned.replacingOccurrences(of: " on Netflix", with: "")
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private func parseAppleTVTitle(from html: String) -> String? {
        // Try og:title
        if let ogTitle = extractMetaContent(html: html, property: "og:title") {
            return cleanAppleTVTitle(ogTitle)
        }
        
        // Try title tag
        if let title = extractTitleTag(html: html) {
            return cleanAppleTVTitle(title)
        }
        
        return nil
    }
    
    private func cleanAppleTVTitle(_ title: String) -> String? {
        var cleaned = title
        
        // Remove common Apple TV suffixes
        cleaned = cleaned.replacingOccurrences(of: " on Apple TV", with: "")
        cleaned = cleaned.replacingOccurrences(of: " — Apple TV", with: "")
        cleaned = cleaned.replacingOccurrences(of: " - Apple TV", with: "")
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private func parsePrimeVideoTitle(from html: String) -> String? {
        if let ogTitle = extractMetaContent(html: html, property: "og:title") {
            return cleanPrimeVideoTitle(ogTitle)
        }
        
        if let title = extractTitleTag(html: html) {
            return cleanPrimeVideoTitle(title)
        }
        
        return nil
    }
    
    private func cleanPrimeVideoTitle(_ title: String) -> String? {
        var cleaned = title
        
        cleaned = cleaned.replacingOccurrences(of: " on Prime Video", with: "")
        cleaned = cleaned.replacingOccurrences(of: " | Prime Video", with: "")
        cleaned = cleaned.replacingOccurrences(of: " - Prime Video", with: "")
        cleaned = cleaned.replacingOccurrences(of: "Amazon Prime Video: ", with: "")
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private func parseNowTVTitle(from html: String) -> String? {
        if let ogTitle = extractMetaContent(html: html, property: "og:title") {
            return cleanNowTVTitle(ogTitle)
        }
        
        if let title = extractTitleTag(html: html) {
            return cleanNowTVTitle(title)
        }
        
        return nil
    }
    
    private func cleanNowTVTitle(_ title: String) -> String? {
        var cleaned = title
        
        cleaned = cleaned.replacingOccurrences(of: " | NOW TV", with: "")
        cleaned = cleaned.replacingOccurrences(of: " | NOW", with: "")
        cleaned = cleaned.replacingOccurrences(of: "Watch ", with: "")
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private func parseGenericTitle(from html: String) -> String? {
        // Try og:title first
        if let ogTitle = extractMetaContent(html: html, property: "og:title") {
            return ogTitle.trimmingCharacters(in: .whitespaces)
        }
        
        // Try title tag
        if let title = extractTitleTag(html: html) {
            return title.trimmingCharacters(in: .whitespaces)
        }
        
        return nil
    }
    
    // MARK: - HTML Helpers
    
    private func extractMetaContent(html: String, property: String) -> String? {
        // Match <meta property="og:title" content="...">
        let pattern = #"<meta[^>]*property="\#(property)"[^>]*content="([^"]*)"[^>]*>"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }
        
        // Try alternate format: <meta content="..." property="og:title">
        let altPattern = #"<meta[^>]*content="([^"]*)"[^>]*property="\#(property)"[^>]*>"#
        
        if let regex = try? NSRegularExpression(pattern: altPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }
        
        return nil
    }
    
    private func extractTitleTag(html: String) -> String? {
        let pattern = #"<title[^>]*>([^<]*)</title>"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }
        
        return nil
    }
    
    // MARK: - TMDB
    
    private func searchTMDB(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        do {
            let response = try await TMDBService.search(query: query)
            // Filter out people
            searchResults = response.results.filter { $0.mediaType != "person" }
            isLoading = false
        } catch {
            NSLog("[ShareExtension] Search error: \(error)")
            errorMessage = "Search failed: \(error.localizedDescription)"
            isLoading = false
        }
        
        isSearching = false
    }
    
    private func addToWatchlist(_ result: TMDBSearchResult) async {
        do {
            let appGroupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.rmischook.WantToWatch"
            )!
            let storeURL = appGroupURL.appendingPathComponent("default.store")
            
            let schema = Schema([WatchlistItem.self])
            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .private("iCloud.com.rmischook.WantToWatch")
            )
            
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = container.mainContext
            
            let item = WatchlistItem(from: result, sourceUrl: sharedURL)
            context.insert(item)
            
            try context.save()
            
            addedItemIds.insert(result.id)
            NSLog("[ShareExtension] Added: \(result.displayTitle)")
        } catch {
            NSLog("[ShareExtension] Error adding to watchlist: \(error)")
        }
    }
}

// MARK: - Result Row

struct ResultRow: View {
    let result: TMDBSearchResult
    let isAdded: Bool
    let onAdd: () async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster
            AsyncImage(url: result.thumbnailPosterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
                    .overlay(Image(systemName: "film"))
            }
            .frame(width: 60, height: 90)
            .cornerRadius(6)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(result.mediaType == "tv" ? "TV Show" : "Movie")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    if let year = result.year {
                        Text(year)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let rating = result.voteAverage {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                        }
                    }
                }
                
                if let overview = result.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Add button
            Button {
                Task {
                    await onAdd()
                }
            } label: {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ShareSheetView(
        sharedURL: URL(string: "https://www.netflix.com/title/81920687")!,
        initialSearchText: nil,
        onComplete: {},
        onCancel: {}
    )
}
