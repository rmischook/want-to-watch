//
//  SearchView.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var addedItemIds: Set<Int> = []
    @State private var showDuplicateAlert = false
    @State private var duplicateItemTitle = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    @Query private var existingItems: [WatchlistItem]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search movies & TV shows...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button("Search") {
                        performSearch()
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
                .padding()
                
                // Results
                if isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Search Failed")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            performSearch()
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                } else if hasSearched && searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Results")
                            .font(.headline)
                        Text("No movies or TV shows found for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else if !hasSearched {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Search TMDB")
                            .font(.headline)
                        Text("Enter a movie or TV show name to search")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                                SearchResultRow(result: result, isAdded: isItemInWatchlist(result.id)) {
                                    addToWatchlist(result)
                                }
                                .padding(.horizontal)
                                .onAppear {
                                    // Load more when near the end
                                    if index == searchResults.count - 1 && currentPage < totalPages && !isLoadingMore {
                                        loadMoreResults()
                                    }
                                }
                            }
                            
                            // Loading indicator at bottom
                            if isLoadingMore {
                                ProgressView()
                                    .padding(.vertical)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Already in Watchlist", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("")
            }
        }
    }
    
    private func performSearch() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        hasSearched = true
        currentPage = 1
        searchResults = []
        
        Task {
            do {
                let response = try await TMDBService.search(query: trimmedQuery, page: 1)
                print("[TMDB] Total results: \(response.totalResults)")
                print("[TMDB] Results returned: \(response.results.count)")
                response.results.forEach { print("[TMDB] - \($0.displayTitle) (\($0.mediaType))") }
                
                // Filter to only movies and TV shows (not people)
                let filtered = response.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
                print("[TMDB] Filtered results: \(filtered.count)")
                
                await MainActor.run {
                    self.searchResults = filtered
                    self.totalPages = response.totalPages
                    self.isLoading = false
                    self.isSearchFieldFocused = false
                }
            } catch {
                print("[TMDB] Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.isSearchFieldFocused = false
                }
            }
        }
    }
    
    private func loadMoreResults() {
        guard currentPage < totalPages, !isLoadingMore else { return }
        
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        Task {
            do {
                let response = try await TMDBService.search(query: trimmedQuery, page: nextPage)
                print("[TMDB] Loading page \(nextPage), results: \(response.results.count)")
                
                // Filter to only movies and TV shows (not people)
                let filtered = response.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
                
                await MainActor.run {
                    self.searchResults.append(contentsOf: filtered)
                    self.currentPage = nextPage
                    self.isLoadingMore = false
                }
            } catch {
                print("[TMDB] Error loading more: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    private func isItemInWatchlist(_ tmdbId: Int) -> Bool {
        return addedItemIds.contains(tmdbId) || existingItems.contains(where: { $0.tmdbId == tmdbId })
    }
    
    private func addToWatchlist(_ result: TMDBSearchResult) {
        // Check for duplicates
        if existingItems.contains(where: { $0.tmdbId == result.id }) {
            duplicateItemTitle = result.displayTitle
            showDuplicateAlert = true
            return
        }
        
        let item = WatchlistItem(from: result)
        modelContext.insert(item)
        print("[CloudKit] Inserted item: \(item.title), id: \(item.id)")
        
        // Fetch TV show details if it's a TV show
        if result.mediaType == "tv" {
            Task {
                do {
                    let tvDetails = try await TMDBService.getTVShowDetails(tvId: result.id)
                    print("[TMDB] Fetched TV details for \(item.title), \(tvDetails.seasons.count) seasons")
                    
                    await MainActor.run {
                        item.seasons = tvDetails.seasons.map { StoredSeason(from: $0) }
                    }
                } catch {
                    print("[TMDB] ❌ Error fetching TV details: \(error.localizedDescription)")
                }
            }
        }
        
        // Fetch credits for both movies and TV shows
        Task {
            do {
                let credits: TMDBCredits
                if result.mediaType == "tv" {
                    credits = try await TMDBService.getTVCredits(tvId: result.id)
                } else {
                    credits = try await TMDBService.getMovieCredits(movieId: result.id)
                }
                
                print("[TMDB] Fetched \(credits.cast.count) cast members for \(item.title)")
                
                await MainActor.run {
                    item.cast = credits.cast.map { StoredCastMember(from: $0) }
                    do {
                        try modelContext.save()
                    } catch {
                        print("[CloudKit] ❌ Error saving cast: \(error)")
                    }
                }
            } catch {
                print("[TMDB] ❌ Error fetching credits: \(error.localizedDescription)")
            }
        }
        
        // Force save to trigger CloudKit sync
        do {
            try modelContext.save()
            print("[CloudKit] ✅ Saved to context")
        } catch {
            print("[CloudKit] ❌ Save error: \(error)")
        }
        
        addedItemIds.insert(result.id)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: TMDBSearchResult
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Poster
            AsyncImage(url: result.thumbnailPosterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                case .failure(_):
                    placeholderPoster
                default:
                    placeholderPoster
                }
            }
            .frame(width: 78, height: 117)
            .cornerRadius(6)
            .clipped()
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let year = result.year {
                        Text(year)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(result.mediaType == "tv" ? "TV" : "Movie")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    if let voteAverage = result.voteAverage, voteAverage > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", voteAverage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let overview = result.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Add button or "In Watchlist" badge
            if isAdded {
                Text("In Watchlist")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(20)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var placeholderPoster: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "film")
                    .foregroundColor(.gray)
            }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
