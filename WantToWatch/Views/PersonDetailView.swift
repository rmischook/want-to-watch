//
//  PersonDetailView.swift
//  WantToWatch
//
//  Created on 26/04/2026.
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    let personId: Int
    let personName: String
    let profileImageURL: URL?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var person: TMDBPerson?
    @State private var castCredits: [TMDBPersonCredit] = []
    @State private var crewCredits: [TMDBPersonCrewCredit] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedCredit: CreditItem?
    
    @Query private var existingItems: [WatchlistItem]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Person header
                    personHeader
                    
                    // Loading / Error
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        // Filmography sections
                        if !castCredits.isEmpty {
                            filmographySection(
                                title: "As Actor",
                                credits: castCredits.map { CreditItem(from: $0) }
                            )
                        }
                        
                        if !crewCredits.isEmpty {
                            filmographySection(
                                title: crewSectionTitle,
                                credits: crewCredits.map { CreditItem(from: $0) }
                            )
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle(personName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedCredit) { credit in
                TitlePreviewView(
                    tmdbId: credit.tmdbId,
                    mediaType: credit.mediaType,
                    title: credit.displayTitle,
                    posterURL: credit.posterURL,
                    posterPath: credit.posterPath,
                    overview: credit.overview,
                    year: credit.year,
                    voteAverage: credit.voteAverage
                )
            }
            .task {
                await fetchPersonData()
            }
        }
    }
    
    // MARK: - Person Header
    
    private var personHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // Profile image
            AsyncImage(url: person?.profileImageURL ?? profileImageURL) { phase in
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
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                }
            }
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(person?.name ?? personName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let department = person?.knownForDepartment {
                    Text(department)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let birthday = person?.birthday, !birthday.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(formatDate(birthday))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let birthplace = person?.placeOfBirth, !birthplace.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.circle")
                            .font(.caption)
                        Text(birthplace)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(maxHeight: 180)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Filmography Section
    
    private func filmographySection(title: String, credits: [CreditItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            let columns = [
                GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)
            ]
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(credits) { credit in
                    creditGridItem(credit)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func creditGridItem(_ credit: CreditItem) -> some View {
        Button {
            selectedCredit = credit
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // Poster
                AsyncImage(url: credit.thumbnailPosterURL) { phase in
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
                .aspectRatio(2/3, contentMode: .fit)
                .cornerRadius(6)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if isItemInWatchlist(credit.tmdbId) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .shadow(radius: 1)
                            .padding(4)
                    }
                }
                
                // Title
                Text(credit.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                // Year + role
                HStack(spacing: 4) {
                    if let year = credit.year {
                        Text(year)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let role = credit.role, !role.isEmpty {
                        Text(role)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private var crewSectionTitle: String {
        guard let crew = person?.knownForDepartment else { return "As Crew" }
        switch crew {
        case "Directing": return "As Director"
        case "Writing": return "As Writer"
        case "Production": return "As Producer"
        default: return "As \(crew)"
        }
    }
    
    private func isItemInWatchlist(_ tmdbId: Int) -> Bool {
        existingItems.contains(where: { $0.tmdbId == tmdbId })
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: String(dateString.prefix(10))) else {
            return dateString
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Failed to Load")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Data Fetching
    
    private func fetchPersonData() async {
        do {
            async let personDetails = TMDBService.getPersonDetails(personId: personId)
            async let credits = TMDBService.getPersonCombinedCredits(personId: personId)
            
            let (fetchedPerson, fetchedCredits) = try await (personDetails, credits)
            
            await MainActor.run {
                self.person = fetchedPerson
                // Sort cast by release date descending (most recent first)
                self.castCredits = (fetchedCredits.cast ?? [])
                    .filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
                    .sorted { ($0.displayDate ?? "") > ($1.displayDate ?? "") }
                // Sort crew by release date descending
                self.crewCredits = (fetchedCredits.crew ?? [])
                    .filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
                    .sorted { ($0.displayDate ?? "") > ($1.displayDate ?? "") }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Credit Item (unified for cast & crew grid display)

struct CreditItem: Identifiable {
    let id: String  // composite: "\(tmdbId)-\(mediaType)-\(role ?? "")"
    let tmdbId: Int
    let mediaType: String
    let displayTitle: String
    let posterURL: URL?
    let thumbnailPosterURL: URL?
    let overview: String?
    let year: String?
    let voteAverage: Double?
    let role: String?
    let posterPath: String?  // raw TMDB path for WatchlistItem init
    
    init(from credit: TMDBPersonCredit) {
        self.id = "\(credit.id)-\(credit.mediaType)-\(credit.character ?? "")"
        self.tmdbId = credit.id
        self.mediaType = credit.mediaType
        self.displayTitle = credit.displayTitle
        self.posterURL = credit.posterURL
        self.thumbnailPosterURL = credit.thumbnailPosterURL
        self.overview = credit.overview
        self.year = credit.year
        self.voteAverage = credit.voteAverage
        self.role = credit.character
        self.posterPath = credit.posterPath
    }
    
    init(from credit: TMDBPersonCrewCredit) {
        self.id = "\(credit.id)-\(credit.mediaType)-\(credit.job ?? "")"
        self.tmdbId = credit.id
        self.mediaType = credit.mediaType
        self.displayTitle = credit.displayTitle
        self.posterURL = credit.posterURL
        self.thumbnailPosterURL = credit.thumbnailPosterURL
        self.overview = credit.overview
        self.year = credit.year
        self.voteAverage = credit.voteAverage
        self.role = credit.job
        self.posterPath = credit.posterPath
    }
}
