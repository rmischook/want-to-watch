//
//  ItemDetailView.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var item: WatchlistItem
    @State private var isEditing = false
    @State private var expandedSeasons: Set<Int> = []
    @State private var isLoadingEpisodes: Set<Int> = []
    @State private var isLoadingSeasons = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with backdrop
                headerSection
                
                // Content
                VStack(alignment: .leading, spacing: 20) {
                    // Title and meta info
                    titleSection
                    
                    // Status and rating
                    statusSection
                    
                    // Overview
                    if let overview = item.overview, !overview.isEmpty {
                        overviewSection(overview)
                    }
                    
                    // Cast
                    if !item.cast.isEmpty {
                        castSection
                    }
                    
                    // Seasons (TV shows only)
                    if item.mediaType == .tv {
                        if isLoadingSeasons {
                            seasonsLoadingSection
                        } else if !item.seasons.isEmpty {
                            seasonsSection
                        }
                    }
                    
                    // Details
                    detailsSection
                    
                    // User notes
                    notesSection
                    
                    // Date added
                    dateAddedSection
                }
                .padding()
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        modelContext.delete(item)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditItemView(item: item)
        }
        .task {
            // Fetch season data for TV shows if not already loaded
            if item.mediaType == .tv && item.seasons.isEmpty && !isLoadingSeasons {
                await fetchSeasonData()
            }
            
            // Fetch credits if not already loaded
            if item.cast.isEmpty {
                await fetchCredits()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Backdrop image
                if let backdropURL = item.backdropURL {
                    AsyncImage(url: backdropURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fit)
                        default:
                            backdropPlaceholder(width: geometry.size.width)
                        }
                    }
                } else {
                    backdropPlaceholder(width: geometry.size.width)
                }
                
                // Gradient overlay
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color.clear, Color.primary.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                }
                
                // Poster thumbnail
                HStack(alignment: .bottom, spacing: 16) {
                    AsyncImage(url: item.posterURL) { phase in
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
                                        .foregroundColor(.gray)
                                }
                        }
                    }
                    .frame(width: 80, height: 120)
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .offset(y: 40)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .frame(height: backdropHeight)
    }
    
    private var backdropHeight: CGFloat {
        // Maintain 16:9 aspect ratio based on screen width
        #if os(iOS)
        return UIScreen.main.bounds.width / (16/9)
        #else
        return 400 // Fixed height for macOS
        #endif
    }
    
    private func backdropPlaceholder(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(16/9, contentMode: .fit)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 12) {
                // Year
                if let date = item.releaseDate {
                    Text(date.formatted(.dateTime.year()))
                        .foregroundColor(.secondary)
                }
                
                // Media type badge
                Text(item.mediaType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                
                // Rating
                if item.voteAverage > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", item.voteAverage))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 50) // Space for poster offset
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Array(WatchStatus.allCases.prefix(2)), id: \.self) { status in
                        statusButton(status)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(Array(WatchStatus.allCases.suffix(2)), id: \.self) { status in
                        statusButton(status)
                    }
                }
            }
        }
    }
    
    private func statusButton(_ status: WatchStatus) -> some View {
        Button {
            item.watchStatus = status
        } label: {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                Text(status.displayName)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(item.watchStatus == status ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(item.watchStatus == status ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Overview Section
    
    private func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)
            
            Text(overview)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
    }
    
    // MARK: - Cast Section
    
    private var castSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cast")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(item.cast) { member in
                        CastMemberCard(member: member)
                    }
                }
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            
            HStack(spacing: 32) {
                if let date = item.releaseDate {
                    detailItem(title: "Release Date", value: date.formatted(date: .long, time: .omitted))
                }
                
                if let language = item.originalLanguage {
                    detailItem(title: "Language", value: language.uppercased())
                }
                
                if item.voteCount > 0 {
                    detailItem(title: "Votes", value: "\(item.voteCount.formatted())")
                }
            }
        }
    }
    
    // MARK: - Seasons Section
    
    private var seasonsLoadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasons")
                .font(.headline)
            
            HStack {
                ProgressView()
                Text("Loading season data...")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasons")
                .font(.headline)
            
            ForEach(item.seasons.sorted(by: { $0.seasonNumber < $1.seasonNumber })) { season in
                SeasonAccordion(
                    season: season,
                    isExpanded: expandedSeasons.contains(season.seasonNumber),
                    isLoading: isLoadingEpisodes.contains(season.seasonNumber),
                    onToggle: {
                        toggleSeason(season)
                    }
                )
            }
        }
    }
    
    private func toggleSeason(_ season: StoredSeason) {
        if expandedSeasons.contains(season.seasonNumber) {
            expandedSeasons.remove(season.seasonNumber)
        } else {
            expandedSeasons.insert(season.seasonNumber)
            
            // Load episodes if not already loaded
            if season.episodes.isEmpty {
                loadEpisodes(for: season)
            }
        }
    }
    
    private func fetchSeasonData() async {
        isLoadingSeasons = true
        
        do {
            let tvDetails = try await TMDBService.getTVShowDetails(tvId: item.tmdbId)
            print("[TMDB] Fetched TV details for \(item.title), \(tvDetails.seasons.count) seasons")
            
            await MainActor.run {
                item.seasons = tvDetails.seasons.map { StoredSeason(from: $0) }
                isLoadingSeasons = false
                
                do {
                    try modelContext.save()
                } catch {
                    print("[CloudKit] ❌ Error saving seasons: \(error)")
                }
            }
        } catch {
            print("[TMDB] ❌ Error fetching TV details: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingSeasons = false
            }
        }
    }
    
    private func fetchCredits() async {
        do {
            let credits: TMDBCredits
            if item.mediaType == .tv {
                credits = try await TMDBService.getTVCredits(tvId: item.tmdbId)
            } else {
                credits = try await TMDBService.getMovieCredits(movieId: item.tmdbId)
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
    
    private func loadEpisodes(for season: StoredSeason) {
        isLoadingEpisodes.insert(season.seasonNumber)
        
        Task {
            do {
                let seasonDetails = try await TMDBService.getTVSeasonDetails(
                    tvId: item.tmdbId,
                    seasonNumber: season.seasonNumber
                )
                print("[TMDB] Loaded \(seasonDetails.episodes.count) episodes for season \(season.seasonNumber)")
                
                await MainActor.run {
                    // Update the season with episodes
                    var updatedSeasons = item.seasons
                    if let index = updatedSeasons.firstIndex(where: { $0.seasonNumber == season.seasonNumber }) {
                        updatedSeasons[index] = StoredSeason(from: seasonDetails)
                        item.seasons = updatedSeasons
                    }
                    isLoadingEpisodes.remove(season.seasonNumber)
                }
            } catch {
                print("[TMDB] ❌ Error loading episodes: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingEpisodes.remove(season.seasonNumber)
                }
            }
        }
    }
    
    private func detailItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button("Edit") {
                    isEditing = true
                }
                .font(.subheadline)
            }
            
            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .foregroundColor(.secondary)
            } else {
                Text("Add notes about this \(item.mediaType.displayName.lowercased())...")
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }
        }
    }
    
    // MARK: - Date Added Section
    
    private var dateAddedSection: some View {
        HStack {
            Text("Added \(item.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Edit Item View

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: WatchlistItem
    
    @State private var editedNotes: String
    @State private var editedUserRating: Double
    
    init(item: WatchlistItem) {
        self.item = item
        _editedNotes = State(initialValue: item.notes ?? "")
        _editedUserRating = State(initialValue: item.userRating ?? 0)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Your Rating") {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Slider(value: $editedUserRating, in: 0...10, step: 0.5)
                        Text(String(format: "%.1f", editedUserRating))
                            .frame(width: 40)
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $editedNotes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.notes = editedNotes.isEmpty ? nil : editedNotes
                        item.userRating = editedUserRating > 0 ? editedUserRating : nil
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Season Accordion

struct SeasonAccordion: View {
    let season: StoredSeason
    let isExpanded: Bool
    let isLoading: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    // Season poster or placeholder
                    if let posterURL = season.thumbnailPosterURL {
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
                                        Image(systemName: "tv")
                                            .foregroundColor(.gray)
                                    }
                            }
                        }
                        .frame(width: 50, height: 75)
                        .cornerRadius(4)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 75)
                            .cornerRadius(4)
                            .overlay {
                                Image(systemName: "tv")
                                    .foregroundColor(.gray)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(season.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            if let year = season.year {
                                Text(year)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("\(season.episodeCount) episodes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .padding(.trailing, 8)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(season.name), \(season.episodeCount) episodes\(season.year != nil ? ", \(season.year!)" : "")")
            .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand and view episodes")
            
            // Episodes (expanded)
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(season.episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber })) { episode in
                        EpisodeCard(episode: episode)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
            }
        }
        .cornerRadius(8)
    }
}

// MARK: - Episode Card

struct EpisodeCard: View {
    let episode: StoredEpisode
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Episode still image
            AsyncImage(url: episode.stillImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .foregroundColor(.gray)
                        }
                }
            }
            .frame(width: 120, height: 68)
            .cornerRadius(6)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("E\(episode.episodeNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(episode.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                if let airDate = episode.displayAirDate {
                    Text(airDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Episode \(episode.episodeNumber): \(episode.name)\(episode.displayAirDate != nil ? ", aired \(episode.displayAirDate!)" : "")")
    }
}

// MARK: - Cast Member Card

struct CastMemberCard: View {
    let member: StoredCastMember
    
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: member.profileImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            VStack(spacing: 2) {
                Text(member.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let character = member.character, !character.isEmpty {
                    Text(character)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 80)
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: {
            let item = WatchlistItem(from: TMDBSearchResult(
                id: 1,
                title: "The Godfather",
                name: nil,
                originalTitle: nil,
                originalName: nil,
                overview: "Spanning the years 1945 to 1955, a chronicle of the fictional Italian-American Corleone crime family. When organized crime family patriarch, Vito Corleone barely survives an attempt on his life, his youngest son, Michael steps in to take care of the would-be killers, launching a campaign of bloody revenge.",
                posterPath: "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
                backdropPath: "/tmU7GeKVybMWFButWEGl2M4GeiP.jpg",
                mediaType: "movie",
                voteAverage: 8.7,
                voteCount: 18000,
                popularity: 100.0,
                releaseDate: "1972-03-14",
                firstAirDate: nil,
                genreIds: [],
                originalLanguage: "en"
            ))
            return item
        }())
    }
    .modelContainer(for: WatchlistItem.self, inMemory: true)
}
