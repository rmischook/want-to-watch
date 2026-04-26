//
//  TitlePreviewView.swift
//  WantToWatch
//
//  Created on 26/04/2026.
//

import SwiftUI
import SwiftData

struct TitlePreviewView: View {
    let tmdbId: Int
    let mediaType: String
    let title: String
    let posterURL: URL?
    let posterPath: String?  // raw TMDB path for WatchlistItem init
    let overview: String?
    let year: String?
    let voteAverage: Double?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var detailedOverview: String?
    @State private var runtime: Int?
    @State private var genres: [String] = []
    @State private var isLoading = false
    @State private var isAdded = false
    @State private var showDuplicateAlert = false
    
    @Query private var existingItems: [WatchlistItem]
    
    private var isInWatchlist: Bool {
        isAdded || existingItems.contains(where: { $0.tmdbId == tmdbId })
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Hero section
                    HStack(alignment: .top, spacing: 16) {
                        // Poster
                        AsyncImage(url: posterURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(2/3, contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay {
                                        Image(systemName: "film")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                    }
                            }
                        }
                        .frame(width: 120, height: 180)
                        .cornerRadius(8)
                        .clipped()
                        
                        // Title info
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .lineLimit(3)
                            
                            HStack(spacing: 8) {
                                if let year = year {
                                    Text(year)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(mediaType == "tv" ? "TV" : "Movie")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                            
                            if let runtime = runtime, runtime > 0 {
                                Text(displayRuntime(runtime))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let voteAverage = voteAverage, voteAverage > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", voteAverage))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .frame(maxHeight: 180)
                        
                        Spacer()
                    }
                    
                    // Genres
                    if !genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(genres, id: \.self) { genre in
                                    Text(genre)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.15))
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    
                    // Overview
                    if let overview = detailedOverview ?? overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Overview")
                                .font(.headline)
                            Text(overview)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Add to watchlist button
                    Button(action: addToWatchlist) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else if isInWatchlist {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("In Watchlist")
                                }
                                .font(.headline)
                                .foregroundColor(.green)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add to Watchlist")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(isInWatchlist ? Color.green.opacity(0.15) : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || isInWatchlist)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Already in Watchlist", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(title) is already in your watchlist.")
            }
            .task {
                await fetchDetails()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func displayRuntime(_ minutes: Int) -> String {
        if mediaType == "tv" {
            return "\(minutes) min/ep"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
    
    // MARK: - Data Fetching
    
    private func fetchDetails() async {
        do {
            if mediaType == "tv" {
                let details = try await TMDBService.getTVShowDetails(tvId: tmdbId)
                await MainActor.run {
                    self.detailedOverview = details.overview
                    self.runtime = details.episodeRunTime?.first
                }
            } else {
                let details = try await TMDBService.getMovieDetails(movieId: tmdbId)
                await MainActor.run {
                    self.detailedOverview = details.overview
                    self.runtime = details.runtime
                }
            }
        } catch {
            print("[PersonDetailView] Error fetching details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Add to Watchlist
    
    private func addToWatchlist() {
        // Check for duplicates
        if existingItems.contains(where: { $0.tmdbId == tmdbId }) {
            showDuplicateAlert = true
            return
        }
        
        isLoading = true
        
        // Create a search-result-like object for WatchlistItem init
        let result = TMDBSearchResult(
            id: tmdbId,
            title: mediaType == "tv" ? nil : title,
            name: mediaType == "tv" ? title : nil,
            originalTitle: nil,
            originalName: nil,
            overview: overview,
            posterPath: posterPath,
            backdropPath: nil,
            mediaType: mediaType,
            voteAverage: voteAverage,
            voteCount: nil,
            popularity: nil,
            releaseDate: mediaType == "movie" ? year.map { "\($0)-01-01" } : nil,
            firstAirDate: mediaType == "tv" ? year.map { "\($0)-01-01" } : nil,
            genreIds: nil,
            originalLanguage: nil
        )
        
        let item = WatchlistItem(from: result)
        modelContext.insert(item)
        
        Task {
            do {
                if mediaType == "tv" {
                    let tvDetails = try await TMDBService.getTVShowDetails(tvId: tmdbId)
                    let credits = try await TMDBService.getTVCredits(tvId: tmdbId)
                    let watchProviders = try await TMDBService.getTVWatchProviders(tvId: tmdbId)
                    
                    await MainActor.run {
                        item.seasonsList = tvDetails.seasons.map { Season(from: $0) }
                        item.imdbId = tvDetails.imdbId
                        item.runtime = tvDetails.episodeRunTime?.first
                        item.castList = credits.cast.map { CastMember(from: $0) }
                        item.crewList = credits.crew.map { CrewMember(from: $0) }
                        applyWatchProviders(watchProviders, to: item)
                        try? modelContext.save()
                        self.isAdded = true
                        self.isLoading = false
                    }
                } else {
                    let movieDetails = try await TMDBService.getMovieDetails(movieId: tmdbId)
                    let credits = try await TMDBService.getMovieCredits(movieId: tmdbId)
                    let watchProviders = try await TMDBService.getMovieWatchProviders(movieId: tmdbId)
                    
                    await MainActor.run {
                        item.imdbId = movieDetails.imdbId
                        item.runtime = movieDetails.runtime
                        item.castList = credits.cast.map { CastMember(from: $0) }
                        item.crewList = credits.crew.map { CrewMember(from: $0) }
                        applyWatchProviders(watchProviders, to: item)
                        try? modelContext.save()
                        self.isAdded = true
                        self.isLoading = false
                    }
                }
            } catch {
                print("[TitlePreviewView] Error fetching data: \(error.localizedDescription)")
                await MainActor.run {
                    try? modelContext.save()
                    self.isAdded = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func applyWatchProviders(_ watchProviders: TMDBWatchProviders, to item: WatchlistItem) {
        let region = Locale.current.region?.identifier ?? "US"
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
    }
}
