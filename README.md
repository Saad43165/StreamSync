# StreamSync 🎬

**Elevate Your Streaming Experience.**

StreamSync is a premium, modern streaming discovery and tracking application built with Flutter. It provides a seamless way to explore trending movies, TV shows, and platform-exclusive content from major streaming giants like Netflix, Amazon Prime Video, and Disney+.

![App Icon](assets/app_icon.png)

## ✨ Key Features

*   **🌍 Global Discovery**: Stay updated with real-time trending content worldwide, powered by the TMDB API.
*   **📡 Platform-Specific Hubs**: Dedicated sections for Netflix, Prime Video, and Disney+ to easily find where to watch.
*   **💎 Glassmorphic UI**: A stunning, modern interface with translucent elements, smooth gradients, and dark mode support.
*   **📋 Personalized Watchlist**: Save your favorite titles for later viewing with a single tap.
*   **⏱️ Continue Watching**: Keep track of your progress with an integrated watch history system.
*   **🚀 Smooth Performance**: Optimized with shimmer loading effects and efficient state management.
*   **📶 Offline Resilience**: Browse your watchlist even when you lose internet connectivity.
*   **🎭 Multi-Profile Support**: Switch between Personal, Family, and Kids profiles for a tailored experience.

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **State Management**: [Provider](https://pub.dev/packages/provider)
*   **Data Source**: [The Movie Database (TMDB) API](https://www.themoviedb.org/documentation/api)
*   **Local Storage**: [Shared Preferences](https://pub.dev/packages/shared_preferences) and [Hive](https://pub.dev/packages/hive) (TMDB response cache)
*   **WebView**: [Flutter InAppWebView](https://pub.dev/packages/flutter_inappwebview)
*   **Video Playback**: [YouTube Player Flutter](https://pub.dev/packages/youtube_player_flutter)

## 🚀 Getting Started

### Prerequisites

*   Flutter SDK 3.41 or higher (Dart 3.11.5+)
*   Dart SDK
*   Android Studio / VS Code with Flutter extension

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/Saad43165/StreamSync.git
    cd StreamSync
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app with your TMDB API key:**
    Get a free key from [themoviedb.org](https://www.themoviedb.org/settings/api) and pass it at build time, so it never lands in source control:
    ```bash
    flutter run --dart-define=TMDB_API_KEY=your_key_here
    ```
    The same flag works for `flutter build apk`. It is read in `lib/config/config.dart`.

4.  **Run the tests:**
    ```bash
    flutter test
    ```

### Release signing (Android)

Create `android/key.properties` (it is git-ignored) pointing at your upload keystore:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without it, release builds are signed with the debug key, which is fine for sideloading but can't be uploaded to a store.

## 📸 UI Showcase

*(Add your screenshots here to make it even more professional!)*

> [!TIP]
> Use the **Demo Mode** to explore the UI without an API key. A warning banner will guide you on how to enable live data.

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---
*Built with ❤️ by [Saad43165](https://github.com/Saad43165)*
