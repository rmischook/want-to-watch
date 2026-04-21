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
        .navigationBarTitleDisplayMode(.inline)
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
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image
            if let backdropURL = item.backdropURL {
                AsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        backdropPlaceholder
                    }
                }
                .frame(height: 200)
                .clipped()
            } else {
                backdropPlaceholder
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [Color.clear, Color.primary.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            
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
    
    private var backdropPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 200)
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
            
            HStack(spacing: 12) {
                ForEach(WatchStatus.allCases, id: \.self) { status in
                    Button {
                        item.watchStatus = status
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: status.icon)
                            Text(status.displayName)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(item.watchStatus == status ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(item.watchStatus == status ? .white : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
