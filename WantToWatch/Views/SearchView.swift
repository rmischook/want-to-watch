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
                            ForEach(searchResults) { result in
                                SearchResultRow(result: result, isAdded: addedItemIds.contains(result.id)) {
                                    addToWatchlist(result)
                                }
                                .padding(.horizontal)
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
        
        Task {
            do {
                let response = try await TMDBService.search(query: trimmedQuery)
                print("[TMDB] Total results: \(response.totalResults)")
                print("[TMDB] Results returned: \(response.results.count)")
                response.results.forEach { print("[TMDB] - \($0.displayTitle) (\($0.mediaType))") }
                
                // Filter to only movies and TV shows (not people)
                let filtered = response.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
                print("[TMDB] Filtered results: \(filtered.count)")
                
                await MainActor.run {
                    self.searchResults = filtered
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
                }
                
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
                
                if let overview = result.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Add button
            Button(action: onAdd) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(isAdded ? .green : .green)
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
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
