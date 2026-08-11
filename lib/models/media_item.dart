/// A lightweight model representing a movie or TV show item from TMDB.
class MediaItem {
  final int id;
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? overview;
  final String? releaseDate; // for movies
  final String? firstAirDate; // for TV

  const MediaItem({
    required this.id,
    required this.title,
    required this.mediaType,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0.0,
    this.overview,
    this.releaseDate,
    this.firstAirDate,
  });

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    final mediaType = map['media_type'] as String? ??
        (map.containsKey('first_air_date') ? 'tv' : 'movie');
    return MediaItem(
      id: map['id'] as int,
      title: (map['title'] ?? map['name'] ?? '') as String,
      mediaType: mediaType,
      posterPath: map['poster_path'] as String?,
      backdropPath: map['backdrop_path'] as String?,
      voteAverage: ((map['vote_average'] as num?) ?? 0).toDouble(),
      overview: map['overview'] as String?,
      releaseDate: map['release_date'] as String?,
      firstAirDate: map['first_air_date'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'media_type': mediaType,
        if (posterPath != null) 'poster_path': posterPath,
        if (backdropPath != null) 'backdrop_path': backdropPath,
        'vote_average': voteAverage,
        if (overview != null) 'overview': overview,
        if (releaseDate != null) 'release_date': releaseDate,
        if (firstAirDate != null) 'first_air_date': firstAirDate,
      };

  String get displayDate => releaseDate ?? firstAirDate ?? '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem && other.id == id && other.mediaType == mediaType;

  @override
  int get hashCode => Object.hash(id, mediaType);
}
