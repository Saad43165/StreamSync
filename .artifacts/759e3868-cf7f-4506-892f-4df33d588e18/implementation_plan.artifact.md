# Implementation Plan - Advanced Media Player & Premium UI Redesign

This plan focuses on enhancing the media player's interactivity, providing a top-tier cinematic experience in the UI, and implementing aggressive popup blocking for a smoother streaming experience.

## User Review Required

> [!IMPORTANT]
> **Ad/Popup Blocking**: I will implement both domain-based blocking and JavaScript injection to disable `window.open`. This will significantly reduce popups, but some highly aggressive ad scripts might still find ways to trigger redirects.
> [!TIP]
> **Performance**: The new UI will use more `BackdropFilter` and `Glassmorphism`. I will ensure these are optimized to maintain 60FPS on most devices.

## Proposed Changes

### 1. Advanced Player Gestures & Ad Blocking
- **[MODIFY] [stream_player_screen.dart](file:///C:/Users/PC/.gemini/antigravity/scratch/streamsync/lib/screens/stream_player_screen.dart)**:
    - **Gestures**: Add a `GestureDetector` overlay.
        - Single Tap: Toggle `_showControls` (with 3s auto-hide timer).
        - Double Tap: Detect side (Left/Right) and seek ±10s via JS injection.
    - **Control Visibility**: UI elements will fade in/out based on `_showControls`.
    - **Ad Blocking**:
        - Enhance `shouldOverrideUrlLoading` with a massive list of ad domains.
        - Add `initialUserScripts` to inject JS that overrides `window.open = function() { return null; };` and `window.alert = function() {};`.
        - Disable `javaScriptCanOpenWindowsAutomatically`.

### 2. Details Screen: Cinematic Redesign
- **[MODIFY] [details_screen.dart](file:///C:/Users/PC/.gemini/antigravity/scratch/streamsync/lib/screens/details_screen.dart)**:
    - **Watch Now Hub**: Create a floating glassmorphic "Action Center" at the bottom of the hero section.
    - **Visual Polish**: Add a subtle "glow" effect to the primary play button.
    - **Info Grid**: Redesign the release date and rating as "Quick Info Chips" with better icons.
    - **Trailer**: Framed within a "Theater Mode" container with rounded edges and ambient shadow.

### 3. Portrait Player: Modern Control Center
- **[MODIFY] [stream_player_screen.dart](file:///C:/Users/PC/.gemini/antigravity/scratch/streamsync/lib/screens/stream_player_screen.dart)**:
    - **Mirror Dock**: Replace the vertical list with a sleek, horizontal "Streaming Dock" for mirror sources.
    - **Episode Selector**: For series, use a modern grid-based selector with better visual hierarchy for "Current Episode".
    - **Ambient Theme**: The background will use a deeper, more cohesive dark theme with subtle primary color accents.

## Verification Plan

### Manual Verification
1.  **Gesture Test**: Verify single tap awakes controls and double tap seeks 10s with visual feedback.
2.  **Popup Test**: Visit a known "pop-heavy" mirror (like Mirror 2) and verify if popups are suppressed.
3.  **UI Verification**: Ensure the new `DetailsScreen` and `Portrait Player` feel significantly more "premium" and user-friendly.
