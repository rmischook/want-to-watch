# WantToWatch - Project Requirements

## Overview

**WantToWatch** is a SwiftUI-based iOS/macOS application for managing a personal watchlist of movies and TV shows. The app uses SwiftData for persistent local storage with iCloud sync.

## Technology Stack

- **Platform**: iOS 17.0+, macOS 14.0+ (iOS priority)
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData + CloudKit (iCloud sync)
- **External API**: TMDB (The Movie Database) - https://www.themoviedb.org
- **Architecture**: SwiftUI App lifecycle (MVVM pattern implicit in SwiftUI)
- **Testing**: Swift Testing (unit tests), XCTest (UI tests)

## Core Features

### 1. Share Extension
- Receive shared items from other apps (Netflix, Apple TV, Prime Video, websites)
- Parse shared content to identify movie/TV show
- Lookup item in TMDB API
- If TMDB finds a match, save item with full metadata
- If TMDB doesn't find a match, allow manual search within share sheet (aspiration)

### 2. TMDB Integration
- API Key: (to be provided)
- Fetch all available TMDB data for each item
- Store original URL source from share

### 3. Watchlist Display
- Grid layout (poster-focused)
- Show poster art, title, rating for each item
- Filter by type (Movie/TV Show), watch status, etc.
- Sort by date added, rating, release year, title
- Search within the app

### 4. Watch Status Tracking
- Want to Watch
- Watching
- Watched

### 5. iCloud Sync
- Sync watchlist across all user devices via CloudKit

## Data Model

### WatchlistItem Entity

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| tmdbId | Int | TMDB identifier |
| title | String | Movie/TV show title |
| originalTitle | String | Original title |
| overview | String | Description/summary |
| posterPath | String? | Poster image path |
| backdropPath | String? | Backdrop image path |
| releaseDate | Date? | Release date (movies) |
| firstAirDate | Date? | First air date (TV shows) |
| voteAverage | Double | TMDB rating (0-10) |
| voteCount | Int | Number of TMDB votes |
| popularity | Double | TMDB popularity score |
| genres | [String] | List of genres |
| runtime | Int? | Runtime in minutes |
| originalLanguage | String | Original language code |
| mediaType | MediaType | movie or tv |
| watchStatus | WatchStatus | Want to Watch / Watching / Watched |
| sourceUrl | URL? | Original URL where item was shared from |
| dateAdded | Date | When added to watchlist |
| userRating | Double? | User's personal rating |
| notes | String? | User's notes/comments |

### Enums

```
enum MediaType: String, Codable {
    case movie
    case tv
}

enum WatchStatus: String, Codable {
    case wantToWatch = "Want to Watch"
    case watching = "Watching"
    case watched = "Watched"
}
```

## UI/UX Requirements

### Main Screen (Grid)
- Grid of poster thumbnails with title and rating overlay
- Filter bar (type, status)
- Sort options
- Search bar
- Tap item to see details

### Detail View
- Full poster/backdrop
- Title, release year, runtime
- Overview/description
- Genres
- TMDB rating
- Watch status selector
- Personal rating input
- Notes field
- Link to original source URL

### Share Extension Flow
1. User shares from another app
2. Extension attempts to identify content
3. Query TMDB API for matches
4. If found: show confirmation with poster/title, save on confirm
5. If not found: show search interface to manually find item (aspiration)

## Platform Considerations

- **iOS**: Primary platform, share extension focus
- **macOS**: Supported but secondary priority
- **NavigationSplitView** for adaptive layout on iPad/Mac

## Testing Requirements

### Unit Tests
- Model validation
- Data operations (CRUD)
- TMDB API integration
- Watch status transitions

### UI Tests
- App launch performance
- Add item via share extension
- View item details
- Update watch status
- Search/filter functionality

## Build Configuration

- **Bundle Identifier**: com.example.WantToWatch (TBD)
- **Deployment Target**: iOS 17.0, macOS 14.0
- **Swift Version**: 5.9+

---

## Preferred LLM Models for Use

| Model | Description |
|-------|-------------|
| (openrouter) minimax/minimax-m2.5:free | Use for brainstorming |
| (openrouter) z-ai/glm-5 | Inexpensive coding model $0.72/M input $2.30/M output |
