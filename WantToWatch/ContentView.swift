//
//  ContentView.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import SwiftUI
import SwiftData

// MARK: - Filter State (Persisted to iCloud)

struct FilterState: Codable, Equatable {
    var statusRaw: String?
    var mediaTypeRaw: String?
    var sortOptionRaw: String
    
    static let `default` = FilterState(
        statusRaw: nil,
        mediaTypeRaw: nil,
        sortOptionRaw: SortOption.dateAdded.rawValue
    )
    
    var status: WatchStatus? {
        get { statusRaw.flatMap { WatchStatus(rawValue: $0) } }
        set { statusRaw = newValue?.rawValue }
    }
    
    var mediaType: MediaType? {
        get { mediaTypeRaw.flatMap { MediaType(rawValue: $0) } }
        set { mediaTypeRaw = newValue?.rawValue }
    }
    
    var sortOption: SortOption {
        get { SortOption(rawValue: sortOptionRaw) ?? .dateAdded }
        set { sortOptionRaw = newValue.rawValue }
    }
}

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
    @State private var columnCount: Int = {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            return isLandscape ? 3 : 2
        } else {
            return 1
        }
        #else
        return 3
        #endif
    }()
    @State private var refreshID = UUID()
    
    // Filter state - synced via iCloud (NSUbiquitousKeyValueStore)
    @State private var filterState = FilterState.default
    
    // Computed accessors for cleaner code
    private var filterStatus: WatchStatus? {
        get { filterState.status }
        nonmutating set { 
            filterState.status = newValue
            saveFilterState()
        }
    }
    
    private var filterMediaType: MediaType? {
        get { filterState.mediaType }
        nonmutating set { 
            filterState.mediaType = newValue
            saveFilterState()
        }
    }
    
    private var sortOption: SortOption {
        get { filterState.sortOption }
        nonmutating set { 
            filterState.sortOption = newValue
            saveFilterState()
        }
    }
    
    private let filterStateKey = "FilterState"
    
    private func loadFilterState() {
        let store = NSUbiquitousKeyValueStore.default
        NSLog("[FilterState] Loading from iCloud store...")
        
        // Check iCloud availability
        if FileManager.default.ubiquityIdentityToken == nil {
            NSLog("[FilterState] ⚠️ iCloud not available - user may not be signed in")
        } else {
            NSLog("[FilterState] iCloud is available")
        }
        
        // Try iCloud first
        if let data = store.data(forKey: filterStateKey) {
            NSLog("[FilterState] Found iCloud data, size: \(data.count) bytes")
            if let state = try? JSONDecoder().decode(FilterState.self, from: data) {
                NSLog("[FilterState] Decoded from iCloud: status=\(state.statusRaw ?? "nil"), mediaType=\(state.mediaTypeRaw ?? "nil"), sort=\(state.sortOptionRaw)")
                filterState = state
                return
            } else {
                NSLog("[FilterState] ❌ Failed to decode iCloud data")
            }
        }
        
        // Fallback to UserDefaults
        NSLog("[FilterState] Trying UserDefaults fallback...")
        if let data = UserDefaults.standard.data(forKey: filterStateKey),
           let state = try? JSONDecoder().decode(FilterState.self, from: data) {
            NSLog("[FilterState] Decoded from UserDefaults: status=\(state.statusRaw ?? "nil"), mediaType=\(state.mediaTypeRaw ?? "nil"), sort=\(state.sortOptionRaw)")
            filterState = state
        } else {
            NSLog("[FilterState] No saved data found, using defaults")
        }
    }
    
    private func saveFilterState() {
        let store = NSUbiquitousKeyValueStore.default
        if let data = try? JSONEncoder().encode(filterState) {
            NSLog("[FilterState] Saving: status=\(filterState.statusRaw ?? "nil"), mediaType=\(filterState.mediaTypeRaw ?? "nil"), sort=\(filterState.sortOptionRaw)")
            
            // Save to iCloud
            store.set(data, forKey: filterStateKey)
            let iCloudResult = store.synchronize()
            NSLog("[FilterState] iCloud synchronize result: \(iCloudResult ? "success" : "queued/offline")")
            
            // Also save to UserDefaults as backup
            UserDefaults.standard.set(data, forKey: filterStateKey)
            NSLog("[FilterState] Saved to UserDefaults backup")
        } else {
            NSLog("[FilterState] ❌ Failed to encode state")
        }
    }
    
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
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateColumnCount(width: geometry.size.width, height: geometry.size.height)
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            updateColumnCount(width: newSize.width, height: newSize.height)
                        }
                }
            )
            .onAppear {
                loadFilterState()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { notification in
                loadFilterState()
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
        HStack(spacing: 12) {
            // Status filter
            Menu {
                Button("All") { filterStatus = nil }
                ForEach(WatchStatus.allCases, id: \.self) { status in
                    Button(status.filterDisplayName) { filterStatus = status }
                }
            } label: {
                HStack {
                    Text(filterStatus?.filterDisplayName ?? "All")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            
            // Media type filter
            Menu {
                Button("All") { filterMediaType = nil }
                ForEach(MediaType.allCases, id: \.self) { type in
                    Button(type.filterDisplayName) { filterMediaType = type }
                }
            } label: {
                HStack {
                    Text(filterMediaType?.filterDisplayName ?? "All")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
            
            // Sort options
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(option.displayName) { sortOption = option }
                }
            } label: {
                HStack {
                    Text(sortOption.displayName)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
            .id(refreshID)
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
            // Force view refresh to reload images
            refreshID = UUID()
        }
    }
    
    private var gridColumns: [GridItem] {
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }
    
    private func updateColumnCount(width: CGFloat, height: CGFloat) {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = width > height
            columnCount = isLandscape ? 3 : 2
        } else {
            columnCount = 1
        }
        #else
        columnCount = 3
        #endif
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
