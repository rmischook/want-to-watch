//
//  ContentView.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var items: [WatchlistItem]
    
    @State private var showingSearch = false
    @State private var searchText = ""
    
    // Filter states
    @State private var filterStatus: WatchStatus?
    @State private var filterMediaType: MediaType?
    
    var filteredItems: [WatchlistItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText)
            let matchesStatus = filterStatus == nil || item.watchStatus == filterStatus
            let matchesMediaType = filterMediaType == nil || item.mediaType == filterMediaType
            return matchesSearch && matchesStatus && matchesMediaType
        }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                watchlistGrid
            }
            .navigationTitle("Want to Watch")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                SearchView()
            }
            .overlay {
                if items.isEmpty {
                    emptyState
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search your watchlist")
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack(spacing: 12) {
            // Status filter
            Picker("Status", selection: $filterStatus) {
                Text("All Statuses").tag(nil as WatchStatus?)
                ForEach(WatchStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status as WatchStatus?)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(20)
            
            // Media type filter
            Picker("Type", selection: $filterMediaType) {
                Text("All Types").tag(nil as MediaType?)
                ForEach(MediaType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type as MediaType?)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Watchlist Grid
    
    private var watchlistGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredItems) { item in
                    WatchlistItemCard(item: item)
                        .contextMenu {
                            statusMenu(for: item)
                            Divider()
                            deleteButton(for: item)
                        }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Items Yet", systemImage: "film.stack")
        } description: {
            Text("Tap + to search for movies and TV shows to add to your watchlist")
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func statusMenu(for item: WatchlistItem) -> some View {
        Menu {
            ForEach(WatchStatus.allCases, id: \.self) { status in
                Button {
                    item.watchStatus = status
                } label: {
                    HStack {
                        Text(status.displayName)
                        if item.watchStatus == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Change Status", systemImage: "bookmark")
        }
    }
    
    private func deleteButton(for item: WatchlistItem) -> some View {
        Button(role: .destructive) {
            modelContext.delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Watchlist Item Card

struct WatchlistItemCard: View {
    let item: WatchlistItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            posterImage
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    if item.voteAverage > 0 {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", item.voteAverage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(item.mediaType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var posterImage: some View {
        AsyncImage(url: item.posterURL) { phase in
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
        .frame(height: 180)
        .clipped()
        .cornerRadius(8)
    }
    
    private var placeholderPoster: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
