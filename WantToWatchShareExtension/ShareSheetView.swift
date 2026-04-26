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
    
    private func parseGenericTitle(from html: String) -> String? {
        // Try og:title first
        var rawTitle: String?
        if let ogTitle = extractMetaContent(html: html, property: "og:title") {
            rawTitle = ogTitle.trimmingCharacters(in: .whitespaces)
        } else if let title = extractTitleTag(html: html) {
            rawTitle = title.trimmingCharacters(in: .whitespaces)
        }
        
        guard let title = rawTitle else { return nil }
        
        // Use NLP to extract movie title from article headlines
        if let extracted = extractMovieTitleFromHeadline(title) {
            return extracted
        }
        
        return title
    }
    
    // MARK: - NLP Title Extraction
    
    /// Extracts potential movie/TV show titles from article headlines using NLP
    private func extractMovieTitleFromHeadline(_ headline: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = headline
        
        // Common words that aren't likely to be in titles
        let commonWords: Set<String> = [
            "the", "a", "an", "in", "on", "of", "for", "is", "and", "or",
            "to", "with", "by", "from", "about", "review", "trailer",
            "movie", "film", "tv", "show", "series", "season", "episode",
            "watch", "streaming", "years", "year", "making", "howl"
        ]
        
        // Publication names to exclude (often appear after em-dash)
        let publications: Set<String> = [
            "empire", "guardian", "bbc", "cnn", "variety", "hollywood reporter",
            "indiewire", "polygon", "ign", "rolling stone", "new york times",
            "washington post", "telegraph", "times", "sun"
        ]
        
        var candidates: [(text: String, score: Int)] = []
        var currentSequence = ""
        var wordCount = 0
        
        tagger.enumerateTags(in: headline.startIndex..<headline.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(headline[tokenRange])
            let lowerWord = word.lowercased()
            
            // Skip if after em-dash (usually publication name)
            if word == "—" || word == "–" || word == "-" {
                if !currentSequence.isEmpty {
                    candidates.append((currentSequence, wordCount))
                }
                currentSequence = ""
                wordCount = 0
                return true
            }
            
            // Check if capitalized and likely part of a title
            let isCapitalized = word.first?.isUppercase ?? false
            let isCommon = commonWords.contains(lowerWord)
            let isPublication = publications.contains(lowerWord)
            
            if isCapitalized && !isCommon && !isPublication && tag == .noun {
                if currentSequence.isEmpty {
                    currentSequence = word
                    wordCount = 1
                } else {
                    currentSequence += " " + word
                    wordCount += 1
                }
            } else {
                // End of sequence
                if !currentSequence.isEmpty && wordCount >= 1 {
                    candidates.append((currentSequence, wordCount))
                }
                currentSequence = ""
                wordCount = 0
            }
            
            return true
        }
        
        // Don't forget the last sequence
        if !currentSequence.isEmpty && wordCount >= 1 {
            candidates.append((currentSequence, wordCount))
        }
        
        // Return the best candidate (prefer 2-4 word sequences)
        let scoredCandidates = candidates.map { candidate -> (text: String, score: Int) in
            var score = candidate.score
            // Prefer 2-4 word titles
            if score >= 2 && score <= 4 {
                score += 10
            }
            return (candidate.text, score)
        }.sorted { $0.score > $1.score }
        
        if let best = scoredCandidates.first {
            NSLog("[ShareExtension] NLP extracted movie title: \(best.text) (score: \(best.score))")
            return best.text
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
                    item.seasons = tvDetails.seasons.map { StoredSeason(from: $0) }
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
                item.cast = credits.cast.map { StoredCastMember(from: $0) }
                
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
