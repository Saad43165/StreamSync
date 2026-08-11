# Implementation Plan - Refactoring TMDBService

Refactor the `TMDBService` to improve type safety, reduce boilerplate, and follow clean architecture principles.

## User Review Required

> [!IMPORTANT]
> This refactoring introduces several new model files and significantly changes the internal structure of `TMDBService`. While the public API (getters like `trending`, `movies`, etc.) will be maintained for compatibility, the underlying types will change from `List<dynamic>` to `List<Media>`.

## Proposed Changes

### 1. Data Models
Create strongly-typed models to replace `dynamic` maps.

#### [NEW] [media.dart](file:///C:/Users/PC/.gemini/antigravity/scratch/streamsync/lib/models/media.dart)
- Define `Media` class for list items.
- Define `MediaDetails` class for full details.
- Include factory methods for JSON parsing.

### 2. Service Refactoring
Refactor `TMDBService` to use the new models and a more modular structure.

#### [MODIFY] [tmdb_service.dart](file:///C:/Users/PC/.gemini/antigravity/scratch/streamsync/lib/services/tmdb_service.dart)
- Replace individual `List<dynamic>` properties with a `Map<MediaCategory, List<Media>>`.
- Create a `fetchCategory` helper method to DRY the `fetchTrending` implementation.
- Move genre maps and base URLs to a separate constants file or class.
- Separate Mock data into a dedicated helper class `TMDBMockData`.

### 3. Networking & Caching
- Improve error handling with a custom `TMDBException`.
- Streamline the Hive caching logic.

## Verification Plan

### Automated Tests
- Since there are no existing tests, I will focus on manual verification.

### Manual Verification
1.  Launch the app and verify that the home screen categories (Trending, Movies, Series, etc.) load correctly.
2.  Verify that the search functionality still works and returns results.
3.  Check that clicking on a media item opens the details page with correct information (overview, trailer, providers).
4.  Verify that the app still works (loads mock data) when the API key is removed/invalid.
