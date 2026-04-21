//
//  ContentView.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case dateAdded = "Added"
    case releaseDateAsc = "Oldest"
    case releaseDateDesc = "Newest"
    case rating = "Rating"
    case alphabetical = "A-Z"
    
    var displayName: String {
        rawValue
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var items: [WatchlistItem] {
        didSet {
            print("[CloudKit] Items changed, count: \(items.count)")
        }
    }
    
    @State private var showingSearch = false
    @State private var searchText = ""
    
    // Filter states
    @State private var filterStatus: WatchStatus?
    @State private var filterMediaType: MediaType?
    @State private var sortOption: SortOption = .dateAdded
    
    var filteredItems: [WatchlistItem] {
        let filtered = items.filter { item in
            let matchesSearch = searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText)
            let matchesStatus = filterStatus == nil || item.watchStatus == filterStatus
            let matchesMediaType = filterMediaType == nil || item.mediaType == filterMediaType
            return matchesSearch && matchesStatus && matchesMediaType
        }
        
        return sortItems(filtered)
    }
    
    private func sortItems(_ items: [WatchlistItem]) -> [WatchlistItem] {
        switch sortOption {
        case .dateAdded:
            return items.sorted { $0.dateAdded > $1.dateAdded }
        case .releaseDateAsc:
            return items.sorted { ($0.releaseDate ?? .distantPast) < ($1.releaseDate ?? .distantPast) }
        case .releaseDateDesc:
            return items.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
        case .rating:
            return items.sorted { $0.voteAverage > $1.voteAverage }
        case .alphabetical:
            return items.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                watchlistGrid
            }
            .navigationTitle("Want to Watch")
            .navigationDestination(for: WatchlistItem.self) { item in
                ItemDetailView(item: item)
            }
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
        .onAppear {
            print("[CloudKit] ContentView appeared, items count: \(items.count)")
            print("[CloudKit] ModelContext: \(modelContext)")
            print("[CloudKit] Has changes: \(modelContext.hasChanges)")
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
                
                // Sort options
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Watchlist Grid
    
    private var watchlistGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(filteredItems) { item in
                    NavigationLink(value: item) {
                        WatchlistItemCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        statusMenu(for: item)
                        Divider()
                        deleteButton(for: item)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            print("[CloudKit] Pull to refresh triggered")
            // Force save to trigger any pending sync
            do {
                try modelContext.save()
                print("[CloudKit] ✅ Refresh save completed")
            } catch {
                print("[CloudKit] ❌ Refresh save error: \(error)")
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        // iPad portrait: 2 columns, iPad landscape: 3 columns, iPhone: 1 column
        // macOS: 3 columns
        #if os(iOS)
        let columns: Int
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: check orientation - landscape has width > height
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            columns = isLandscape ? 3 : 2
        } else {
            columns = 1
        }
        #else
        let columns = 3
        #endif
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
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

// MARK: - Watchlist Item Card (for grid layout)

struct WatchlistItemCard: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Poster
            AsyncImage(url: item.thumbnailPosterURL) { phase in
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
            .frame(width: 160, height: 240)
            .clipped()
            .cornerRadius(8)
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let date = item.releaseDate {
                        Text(date.formatted(.dateTime.year()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(item.mediaType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    if item.voteAverage > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", item.voteAverage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font({
                            #if os(iOS)
                            return UIDevice.current.userInterfaceIdiom == .pad ? Font.body : Font.caption
                            #else
                            return Font.body
                            #endif
                        }())
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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

// MARK: - Watchlist Item Row (original single-column layout)

struct WatchlistItemRow: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Poster
            AsyncImage(url: item.thumbnailPosterURL) { phase in
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
            .frame(width: 160, height: 240)
            .clipped()
            .cornerRadius(8)
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let date = item.releaseDate {
                        Text(date.formatted(.dateTime.year()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(item.mediaType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    if item.voteAverage > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", item.voteAverage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
    ContentView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
