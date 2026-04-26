//
//  ShareSheetView.swift
//  WantToWatchShareExtension
//
//  Created on 21/04/2026.
//

import SwiftUI
import SwiftData
import NaturalLanguage

struct ShareSheetView: View {
    let sharedURL: URL?
    let initialSearchText: String?
    let modelContainer: ModelContainer
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onComplete()
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
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
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
        
        NSLog("[ShareExtension] Processing shared URL: \(url.absoluteString)")
        NSLog("[ShareExtension] URL scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil"), path: \(url.path)")
        
        // Special handling for IMDB - they block programmatic access
        let host = url.host?.lowercased() ?? ""
        if host.contains("imdb") {
            await processIMDBURL(url)
            return
        }
        
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
    
    // MARK: - IMDB Handling
    
    private func processIMDBURL(_ url: URL) async {
        NSLog("[ShareExtension] Processing IMDB URL")
        
        // Try to extract IMDb ID from URL (pattern: /title/tt0111161 or /title/tt0111161/)
        let path = url.path
        let imdbIdPattern = "/title/(tt[0-9]+)"
        
        guard let regex = try? NSRegularExpression(pattern: imdbIdPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let idRange = Range(match.range(at: 1), in: path) else {
            NSLog("[ShareExtension] No IMDb title ID found in URL")
            await MainActor.run {
                errorMessage = "This IMDB page isn't a specific movie or TV show. Try sharing from a title page."
                isLoading = false
            }
            return
        }
        
        let imdbId = String(path[idRange])
        NSLog("[ShareExtension] Found IMDb ID: \(imdbId)")
        
        do {
            // Look up the title in TMDB by IMDb ID
            if let result = try await TMDBService.findByIMDBId(imdbId) {
                NSLog("[ShareExtension] Found in TMDB: \(result.displayTitle)")
                await MainActor.run {
                    searchResults = [result]
                    extractedTitle = result.displayTitle
                    searchText = result.displayTitle
                    isLoading = false
                }
            } else {
                NSLog("[ShareExtension] IMDb ID not found in TMDB")
                await MainActor.run {
                    errorMessage = "Could not find this title in TMDB"
                    isLoading = false
                }
            }
        } catch {
            NSLog("[ShareExtension] Error looking up IMDb ID: \(error)")
            await MainActor.run {
                errorMessage = "Error looking up title: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func fetchPageContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        NSLog("[ShareExtension] Fetching URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            NSLog("[ShareExtension] Non-HTTP response: \(response)")
            throw URLError(.badServerResponse)
        }
        
        NSLog("[ShareExtension] HTTP status: \(httpResponse.statusCode)")
        NSLog("[ShareExtension] Response headers: \(httpResponse.allHeaderFields)")
        NSLog("[ShareExtension] Response body length: \(data.count) bytes")
        
        // Log first 500 chars of body for diagnosis
        if let body = String(data: data.prefix(500), encoding: .utf8) {
            NSLog("[ShareExtension] Response body preview: \(body)")
        }
        
        guard httpResponse.statusCode == 200 else {
            NSLog("[ShareExtension] Non-200 status code: \(httpResponse.statusCode)")
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
            return parseGenericTitle(from: html, url: url)
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
        
        // Remove 'Watch ' prefix
        cleaned = cleaned.replacingOccurrences(of: "Watch ", with: "")
        
        // Remove common Apple TV suffixes (try various dash types)
        cleaned = cleaned.replacingOccurrences(of: " on Apple TV", with: "")
        cleaned = cleaned.replacingOccurrences(of: " — Apple TV", with: "")
        cleaned = cleaned.replacingOccurrences(of: " – Apple TV", with: "")
        cleaned = cleaned.replacingOccurrences(of: " - Apple TV", with: "")
        cleaned = cleaned.replacingOccurrences(of: " | Apple TV", with: "")
        
        // Fallback: remove anything after a dash if it contains "Apple"
        if cleaned.contains("Apple") {
            if let range = cleaned.range(of: " - ") {
                cleaned = String(cleaned[..<range.lowerBound])
            } else if let range = cleaned.range(of: " – ") {
                cleaned = String(cleaned[..<range.lowerBound])
            } else if let range = cleaned.range(of: " — ") {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        
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
        
        cleaned = cleaned.replacingOccurrences(of: "Watch ", with: "")
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
    
    private func parseGenericTitle(from html: String, url: URL) -> String? {
        // Strategy 1: Try JSON-LD structured data (most reliable)
        if let jsonLdTitle = extractTitleFromJSONLD(html) {
            NSLog("[ShareExtension] JSON-LD extracted: \(jsonLdTitle)")
            return jsonLdTitle
        }
        
        // Strategy 2: Try og:title with suffix stripping
        var rawTitle: String?
        if let ogTitle = extractMetaContent(html: html, property: "og:title") {
            rawTitle = ogTitle.trimmingCharacters(in: .whitespaces)
        } else if let title = extractTitleTag(html: html) {
            rawTitle = title.trimmingCharacters(in: .whitespaces)
        }
        
        if let title = rawTitle {
            let cleaned = cleanGenericTitle(title)
            NSLog("[ShareExtension] Cleaned og/title: \(cleaned)")
            return cleaned
        }
        
        // Strategy 3: Try URL slug
        if let slugTitle = extractTitleFromURLSlug(url) {
            NSLog("[ShareExtension] URL slug extracted: \(slugTitle)")
            return slugTitle
        }
        
        return nil
    }
    
    // MARK: - JSON-LD Extraction
    
    private func extractTitleFromJSONLD(_ html: String) -> String? {
        let pattern = #"<script[^>]*type="application/ld\+json"[^>]*>([\s\S]*?)</script>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let fullRange = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: fullRange)
        
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[range])
            
            if let title = parseJSONLDTitle(jsonString) {
                return title
            }
        }
        
        return nil
    }
    
    private func parseJSONLDTitle(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        
        // Could be a single object or array
        let objects: [[String: Any]]
        if let array = json as? [[String: Any]] {
            objects = array
        } else if let dict = json as? [String: Any] {
            objects = [dict]
        } else {
            return nil
        }
        
        let movieTVTypes: Set<String> = [
            "movie", "tvseries", "tvepisode", "tvseason", "series",
            "creativework", "videoobject"
        ]
        
        for obj in objects {
            let typeValue = extractJSONLDType(from: obj)
            
            if let type = typeValue, movieTVTypes.contains(type.lowercased()) {
                if let name = obj["name"] as? String, !name.isEmpty {
                    return name
                }
            }
            
            // Also check nested @graph
            if let graph = obj["@graph"] as? [[String: Any]] {
                for graphObj in graph {
                    let graphType = extractJSONLDType(from: graphObj)
                    if let type = graphType, movieTVTypes.contains(type.lowercased()) {
                        if let name = graphObj["name"] as? String, !name.isEmpty {
                            return name
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractJSONLDType(from obj: [String: Any]) -> String? {
        if let typeStr = obj["@type"] as? String {
            return typeStr
        } else if let typeArr = obj["@type"] as? [String] {
            return typeArr.first
        }
        return nil
    }
    
    // MARK: - Generic Title Cleaning
    
    private func cleanGenericTitle(_ title: String) -> String {
        var cleaned = title
        
        // Strip common site suffixes after separators (search from end)
        // Handles: "Title | Site", "Title - Site", "Title — Site", "Title · Site"
        let separators = [" | ", " - ", " – ", " — ", " · "]
        for sep in separators {
            if let range = cleaned.range(of: sep, options: .backwards) {
                let afterSep = String(cleaned[range.upperBound...])
                if looksLikeSiteName(afterSep) {
                    cleaned = String(cleaned[..<range.lowerBound])
                    break
                }
            }
        }
        
        // Remove common prefixes
        cleaned = cleaned.replacingOccurrences(of: "Watch ", with: "")
        
        // Don't use NLP to shorten — return the full cleaned title
        // NLP extraction tends to crop titles too aggressively
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private func looksLikeSiteName(_ text: String) -> Bool {
        let siteIndicators: Set<String> = [
            "imdb", "rotten tomatoes", "metacritic", "wikipedia", "youtube",
            "reddit", "twitter", "facebook", "instagram", "tiktok",
            "review", "news", "blog", "official", "site", "wiki",
            "amazon", "google", "apple", "microsoft",
            "tv", "streaming", "guide", "online", "database",
            "tmdb", "letterboxd", "justwatch", "trakt"
        ]
        
        let lower = text.lowercased()
        
        // Short text after separator is likely a site name (e.g., "IMDb", "BBC")
        if text.count <= 20 { return true }
        
        // Contains known site indicators
        for indicator in siteIndicators {
            if lower.contains(indicator) { return true }
        }
        
        return false
    }
    
    // MARK: - URL Slug Extraction
    
    private func extractTitleFromURLSlug(_ url: URL) -> String? {
        let path = url.path
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        let genericSegments: Set<String> = [
            "movie", "movies", "tv", "show", "shows", "series", "title",
            "watch", "video", "film", "films", "episode", "season"
        ]
        
        // Look for the most title-like component (contains dashes, not just numbers)
        for component in components.reversed() {
            if component.count <= 2 { continue }
            if component.allSatisfy({ $0.isNumber }) { continue }
            
            if component.contains("-") || component.contains("_") {
                // Convert slug to title
                let title = component
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                
                // Title-case the result
                let words = title.split(separator: " ").map { word -> String in
                    guard let first = word.first else { return String(word) }
                    return String(first).uppercased() + word.dropFirst().lowercased()
                }
                
                let result = words.joined(separator: " ")
                
                // Skip generic path segments
                if genericSegments.contains(result.lowercased()) { continue }
                
                return result
            }
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
            var results = response.results.filter { $0.mediaType != "person" }
            
            // Progressive search: if no results, try progressively shorter queries
            if results.isEmpty {
                let words = query.split(separator: " ")
                if words.count > 1 {
                    // Try removing one word at a time from the end
                    for i in stride(from: words.count - 1, through: 1, by: -1) {
                        let shorterQuery = words[0..<i].joined(separator: " ")
                        NSLog("[ShareExtension] No results, trying progressive search: \(shorterQuery)")
                        let shorterResponse = try await TMDBService.search(query: shorterQuery)
                        results = shorterResponse.results.filter { $0.mediaType != "person" }
                        if !results.isEmpty {
                            // Update search text to show what actually matched
                            await MainActor.run {
                                self.searchText = shorterQuery
                            }
                            break
                        }
                    }
                }
            }
            
            searchResults = results
            isLoading = false
        } catch {
            NSLog("[ShareExtension] Search error: \(error)")
            errorMessage = "Search failed: \(error.localizedDescription)"
            isLoading = false
        }
        
        isSearching = false
    }
    
    private func addToWatchlist(_ result: TMDBSearchResult) async {
        let context = modelContainer.mainContext
        
        // Check for duplicates
        let descriptor = FetchDescriptor<WatchlistItem>(
            predicate: #Predicate { $0.tmdbId == result.id }
        )
        
        do {
            let existingItems = try context.fetch(descriptor)
            
            if !existingItems.isEmpty {
                NSLog("[ShareExtension] Duplicate found: \(result.displayTitle)")
                await MainActor.run {
                    errorMessage = "Already in your watchlist"
                }
                return
            }
            
            let item = WatchlistItem(from: result, sourceUrl: sharedURL)
            context.insert(item)
            
            // Fetch additional data in a single structured task
            do {
                // Fetch TV details if needed
                if result.mediaType == "tv" {
                    let tvDetails = try await TMDBService.getTVShowDetails(tvId: result.id)
                    NSLog("[ShareExtension] Fetched TV details for \(item.title), \(tvDetails.seasons.count) seasons")
                    item.seasonsList = tvDetails.seasons.map { Season(from: $0) }
                    item.imdbId = tvDetails.imdbId
                    item.runtime = tvDetails.episodeRunTime?.first
                } else {
                    // Fetch movie details for IMDB ID and runtime
                    let movieDetails = try await TMDBService.getMovieDetails(movieId: result.id)
                    NSLog("[ShareExtension] Fetched movie details for \(item.title)")
                    item.imdbId = movieDetails.imdbId
                    item.runtime = movieDetails.runtime
                }
                
                // Fetch credits
                let credits: TMDBCredits
                if result.mediaType == "tv" {
                    credits = try await TMDBService.getTVCredits(tvId: result.id)
                } else {
                    credits = try await TMDBService.getMovieCredits(movieId: result.id)
                }
                
                NSLog("[ShareExtension] Fetched \(credits.cast.count) cast members for \(item.title)")
                item.castList = credits.cast.map { CastMember(from: $0) }
                item.crewList = credits.crew.map { CrewMember(from: $0) }
                
                // Fetch watch providers
                let region = Locale.current.region?.identifier ?? "US"
                let watchProviders: TMDBWatchProviders
                if result.mediaType == "tv" {
                    watchProviders = try await TMDBService.getTVWatchProviders(tvId: result.id)
                } else {
                    watchProviders = try await TMDBService.getMovieWatchProviders(movieId: result.id)
                }
                
                NSLog("[ShareExtension] Fetched watch providers for \(item.title)")
                
                // Save watch providers
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
                
                try context.save()
                addedItemIds.insert(result.id)
                NSLog("[ShareExtension] Added: \(result.displayTitle)")
            } catch {
                NSLog("[ShareExtension] Error fetching data: \(error.localizedDescription)")
                // Still save the item even if additional data fails
                try context.save()
                addedItemIds.insert(result.id)
            }
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WatchlistItem.self, configurations: config)
    
    ShareSheetView(
        sharedURL: URL(string: "https://www.netflix.com/title/81920687")!,
        initialSearchText: nil,
        modelContainer: container,
        onComplete: {},
        onCancel: {}
    )
}
