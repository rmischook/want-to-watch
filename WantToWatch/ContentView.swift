//
//  ContentView.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 21/04/2026.
//

import SwiftUI
import SwiftData
import PDFKit

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
    @State private var showingExport = false
    @State private var isGeneratingPDF = false
    @State private var pdfData: Data?
    
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
    
    
    // MARK: - PDF Export (iOS only)
    
    #if os(iOS)
    private func generatePDF() async {
        isGeneratingPDF = true
        
        // Capture filter state for background work
        let items = filteredItems
        let status = filterStatus
        let mediaType = filterMediaType
        
        // Generate PDF on background thread
        let result = await Task.detached {
            let pageWidth: CGFloat = 612
            let pageHeight: CGFloat = 792
            let margin: CGFloat = 36
            let itemHeight: CGFloat = 140
            let itemsPerPage = 4
            
            let pages = stride(from: 0, to: items.count, by: itemsPerPage).map { start in
                Array(items[start..<min(start + itemsPerPage, items.count)])
            }
            
            var allPagesData: [Data] = []
            
            for (pageIndex, pageItems) in pages.enumerated() {
                let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
                
                let data = renderer.pdfData { context in
                    context.beginPage()
                    let cgContext = context.cgContext
                    
                    // Header
                    let headerFont = UIFont.systemFont(ofSize: 18, weight: .bold)
                    let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont]
                    ("Want to Watch" as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: headerAttrs)
                    
                    // Date
                    let dateFont = UIFont.systemFont(ofSize: 10)
                    let dateAttrs: [NSAttributedString.Key: Any] = [.font: dateFont, .foregroundColor: UIColor.secondaryLabel]
                    let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none) ?? ""
                    let dateSize = dateStr.size(withAttributes: dateAttrs)
                    (dateStr as NSString).draw(at: CGPoint(x: pageWidth - margin - dateSize.width, y: margin + 4), withAttributes: dateAttrs)
                    
                    // Divider line under header
                    UIColor.separator.setStroke()
                    cgContext.move(to: CGPoint(x: margin, y: margin + 42))
                    cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: margin + 42))
                    cgContext.setStrokeColor(UIColor.separator.cgColor)
                    cgContext.setLineWidth(0.5)
                    cgContext.strokePath()
                    
                    // Filter info
                    var filterParts: [String] = []
                    if let status = status {
                        filterParts.append(status.filterDisplayName)
                    }
                    if let mediaType = mediaType {
                        filterParts.append(mediaType == .movie ? "Movies" : "TV Shows")
                    }
                    if !filterParts.isEmpty {
                        let filterStr = "Filtered by: " + filterParts.joined(separator: " • ")
                        (filterStr as NSString).draw(at: CGPoint(x: margin, y: margin + 48), withAttributes: dateAttrs)
                    }
                    
                    // Items
                    var y = margin + 68
                    for item in pageItems {
                        drawPDFItemBackground(item, at: CGPoint(x: margin, y: y), width: pageWidth - margin * 2, context: cgContext)
                        y += itemHeight + 8
                    }
                    
                    // Footer
                    let footerStr = "Page \(pageIndex + 1) of \(pages.count)"
                    let footerSize = (footerStr as NSString).size(withAttributes: dateAttrs)
                    (footerStr as NSString).draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - 36), withAttributes: dateAttrs)
                }
                
                allPagesData.append(data)
            }
            
            // Combine into single PDF
            let pdfDocument = PDFDocument()
            for data in allPagesData {
                if let doc = PDFDocument(data: data), let page = doc.page(at: 0) {
                    pdfDocument.insert(page, at: pdfDocument.pageCount)
                }
            }
            
            return pdfDocument.dataRepresentation()
        }.value
        
        pdfData = result
        isGeneratingPDF = false
        showingExport = true
    }
    
    private func drawPDFItemBackground(_ item: WatchlistItem, at point: CGPoint, width: CGFloat, context: CGContext) {
        let posterWidth: CGFloat = 60
        let posterHeight: CGFloat = 90
        let spacing: CGFloat = 12
        
        // Poster
        let posterRect = CGRect(x: point.x, y: point.y, width: posterWidth, height: posterHeight)
        
        // Try to load poster image
        if let posterPath = item.posterPath,
           let url = URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            UIGraphicsPushContext(context)
            image.draw(in: posterRect)
            UIGraphicsPopContext()
        } else {
            // Placeholder
            UIGraphicsPushContext(context)
            UIColor.systemGray4.setFill()
            context.fill(posterRect)
            if let icon = UIImage(systemName: "film")?.withTintColor(.gray, renderingMode: .alwaysOriginal) {
                icon.draw(in: CGRect(x: posterRect.midX - 15, y: posterRect.midY - 15, width: 30, height: 30))
            }
            UIGraphicsPopContext()
        }
        
        // Text content
        let textX = point.x + posterWidth + spacing
        var textY = point.y
        
        UIGraphicsPushContext(context)
        
        // Title
        let titleFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
        item.title.draw(at: CGPoint(x: textX, y: textY), withAttributes: titleAttrs)
        textY += 20
        
        // Meta: type, year, rating
        let metaFont = UIFont.systemFont(ofSize: 10)
        let metaAttrs: [NSAttributedString.Key: Any] = [.font: metaFont, .foregroundColor: UIColor.secondaryLabel]
        var metaParts: [String] = [item.mediaType == .movie ? "Movie" : "TV Show"]
        if let releaseDate = item.releaseDate {
            metaParts.append(String(Calendar.current.component(.year, from: releaseDate)))
        }
        if item.voteAverage > 0 {
            metaParts.append("★ " + String(format: "%.1f", item.voteAverage))
        }
        metaParts.joined(separator: " • ").draw(at: CGPoint(x: textX, y: textY), withAttributes: metaAttrs)
        textY += 16
        
        // Status badge
        let statusFont = UIFont.systemFont(ofSize: 9, weight: .medium)
        let statusText = item.watchStatus.filterDisplayName as NSString
        let statusSize = statusText.size(withAttributes: [.font: statusFont])
        let statusBgColor: UIColor
        switch item.watchStatus {
        case .wantToWatch: statusBgColor = .systemBlue
        case .watching: statusBgColor = .systemOrange
        case .watched: statusBgColor = .systemGreen
        case .waiting: statusBgColor = .systemPurple
        }
        
        let statusRect = CGRect(x: textX, y: textY, width: statusSize.width + 12, height: statusSize.height + 6)
        statusBgColor.setFill()
        let statusPath = UIBezierPath(roundedRect: statusRect, cornerRadius: 4)
        statusPath.fill()
        
        let statusAttrs: [NSAttributedString.Key: Any] = [.font: statusFont, .foregroundColor: UIColor.white]
        statusText.draw(at: CGPoint(x: textX + 6, y: textY + 3), withAttributes: statusAttrs)
        textY += 20
        
        // Overview
        if let overview = item.overview, !overview.isEmpty {
            let overviewFont = UIFont.systemFont(ofSize: 9)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.alignment = .left
            let maxWidth = width - posterWidth - spacing
            let attributedString = NSAttributedString(string: overview, attributes: [
                .font: overviewFont,
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ])
            let overviewRect = CGRect(x: textX, y: textY, width: maxWidth, height: 200)
            attributedString.draw(in: overviewRect)
        }
        
        UIGraphicsPopContext()
    }
    #endif
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
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await generatePDF()
                        }
                    } label: {
                        if isGeneratingPDF {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(filteredItems.isEmpty || isGeneratingPDF)
                }
                #endif
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
            #if os(iOS)
            .sheet(isPresented: $showingExport) {
                if let data = pdfData {
                    ShareView(data: data, filename: "WantToWatch_Export.pdf")
                }
            }
            .overlay {
                if isGeneratingPDF {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Generating PDF...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(32)
                        .background(.regularMaterial)
                        .cornerRadius(12)
                    }
                }
            }
            #endif
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
                
                // Watch provider pills
                if !item.watchProviders.isEmpty {
                    watchProviderPills
                }
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
    
    // MARK: - Watch Provider Pills
    
    private var watchProviderPills: some View {
        HStack(spacing: 6) {
            // Show up to 4 providers
            ForEach(item.watchProviders.prefix(4)) { provider in
                providerPill(provider)
            }
            
            // Show count if more than 4
            if item.watchProviders.count > 4 {
                Text("+\(item.watchProviders.count - 4)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
            }
        }
    }
    
    private func providerPill(_ provider: StoredWatchProvider) -> some View {
        AsyncImage(url: provider.logoURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            default:
                // Fallback: show first letter of provider name
                Text(provider.name.prefix(1))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray)
            }
        }
        .frame(width: 28, height: 28)
        .cornerRadius(6)
        .clipped()
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

// MARK: - PDF Export Share View

#if os(iOS)
struct ShareView: UIViewControllerRepresentable {
    let data: Data
    let filename: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        
        let controller = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: tempURL)
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
