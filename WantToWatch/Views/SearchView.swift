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
    @State private var selectedPerson: TMDBSearchResult?
    @FocusState private var isSearchFieldFocused: Bool
    
    @Query private var existingItems: [WatchlistItem]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search movies, TV shows, people...", text: $searchText)
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
                        Text("No movies, TV shows, or people found for \"\(searchText)\"")
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
                        Text("Search for movies, TV shows, or people")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                                SearchResultRow(result: result, isAdded: isItemInWatchlist(result.id)) {
                                    if result.isPerson {
                                        selectedPerson = result
                                    } else {
                                        addToWatchlist(result)
                                    }
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
            .sheet(item: $selectedPerson) { person in
                PersonDetailView(
                    personId: person.id,
                    personName: person.displayTitle,
                    profileImageURL: person.profileImageURL
                )
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
                
                await MainActor.run {
                    self.searchResults = response.results
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
                
                await MainActor.run {
                    self.searchResults.append(contentsOf: response.results)
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
        
        // Fetch additional data in a single structured task
        Task {
            do {
                // Fetch TV details if needed
                if result.mediaType == "tv" {
                    let tvDetails = try await TMDBService.getTVShowDetails(tvId: result.id)
                    print("[TMDB] Fetched TV details for \(item.title), \(tvDetails.seasons.count) seasons")
                    
                    await MainActor.run {
                        item.seasonsList = tvDetails.seasons.map { Season(from: $0) }
                        item.imdbId = tvDetails.imdbId
                        item.runtime = tvDetails.episodeRunTime?.first
                    }
                } else {
                    // Fetch movie details for IMDB ID and runtime
                    let movieDetails = try await TMDBService.getMovieDetails(movieId: result.id)
                    print("[TMDB] Fetched movie details for \(item.title)")
                    
                    await MainActor.run {
                        item.imdbId = movieDetails.imdbId
                        item.runtime = movieDetails.runtime
                    }
                }
                
                // Fetch credits for both movies and TV shows
                let credits: TMDBCredits
                if result.mediaType == "tv" {
                    credits = try await TMDBService.getTVCredits(tvId: result.id)
                } else {
                    credits = try await TMDBService.getMovieCredits(movieId: result.id)
                }
                
                print("[TMDB] Fetched \(credits.cast.count) cast members for \(item.title)")
                
                // Fetch watch providers
                let region = Locale.current.region?.identifier ?? "US"
                let watchProviders: TMDBWatchProviders
                if result.mediaType == "tv" {
                    watchProviders = try await TMDBService.getTVWatchProviders(tvId: result.id)
                } else {
                    watchProviders = try await TMDBService.getMovieWatchProviders(movieId: result.id)
                }
                
                print("[TMDB] Fetched watch providers for \(item.title)")
                
                await MainActor.run {
                    item.castList = credits.cast.map { CastMember(from: $0) }
                    item.crewList = credits.crew.map { CrewMember(from: $0) }
                    
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
                    
                    do {
                        try modelContext.save()
                    } catch {
                        print("[CloudKit] ❌ Error saving: \(error)")
                    }
                }
            } catch {
                print("[TMDB] ❌ Error fetching data: \(error.localizedDescription)")
                // Still save the item even if additional data fails
                await MainActor.run {
                    do {
                        try modelContext.save()
                    } catch {
                        print("[CloudKit] ❌ Save error: \(error)")
                    }
                }
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
            if result.isPerson {
                personImage
            } else {
                posterImage
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if !result.isPerson, let year = result.year {
                        Text(year)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if result.isPerson {
                        Text(result.knownForDepartment ?? "Person")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    } else {
                        Text(result.mediaType == "tv" ? "TV" : "Movie")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    if !result.isPerson, let voteAverage = result.voteAverage, voteAverage > 0 {
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
            if result.isPerson {
                // For people, show a chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else if isAdded {
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
        .onTapGesture {
            if result.isPerson {
                onAdd()
            }
        }
    }
    
    private var posterImage: some View {
        AsyncImage(url: result.thumbnailPosterURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            default:
                posterPlaceholder
            }
        }
        .frame(width: 78, height: 117)
        .cornerRadius(6)
        .clipped()
    }
    
    private var personImage: some View {
        AsyncImage(url: result.profileImageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            default:
                personPlaceholder
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(Circle())
    }
    
    private var posterPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "film")
                    .foregroundColor(.gray)
            }
    }
    
    private var personPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
