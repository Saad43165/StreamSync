# StreamSync 🎬

**Elevate Your Streaming Experience.**

StreamSync is a premium, modern streaming discovery and tracking application built with Flutter. It provides a seamless way to explore trending movies, TV shows, and platform-exclusive content from major streaming giants like Netflix, Amazon Prime Video, and Disney+.

![App Icon](assets/app_icon.jpg)

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
*   **Local Storage**: [Shared Preferences](https://pub.dev/packages/shared_preferences)
*   **WebView**: [Flutter InAppWebView](https://pub.dev/packages/flutter_inappwebview)
*   **Video Playback**: [YouTube Player Flutter](https://pub.dev/packages/youtube_player_flutter)

## 🚀 Getting Started

### Prerequisites

*   Flutter SDK (v3.11.5 or higher)
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

3.  **Configure API Key**:
    To unlock live data and search features, you need a free API key from TMDB.
    *   Go to `lib/config/config.dart`.
    *   Add your API key:
    ```dart
    static const String apiKey = 'YOUR_TMDB_API_KEY_HERE';
    ```

4.  **Run the app:**
    ```bash
    flutter run
    ```

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
