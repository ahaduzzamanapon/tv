// models/movie.dart
class Movie {
  final int    id;
  final String title;
  final String quality;
  final String streamUrl;
  final String posterUrl;
  final String groupName;
  final String language;
  final String source;
  final String addedAt;
  final String contentType;
  final int    totalSeasons;

  Movie({
    required this.id,
    required this.title,
    required this.quality,
    required this.streamUrl,
    required this.posterUrl,
    required this.groupName,
    required this.language,
    required this.source,
    required this.addedAt,
    this.contentType  = 'movie',
    this.totalSeasons = 0,
  });

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id           : j['id'] ?? 0,
        title        : j['title'] ?? '',
        quality      : j['quality'] ?? '',
        streamUrl    : j['stream_url'] ?? '',
        posterUrl    : j['poster_url'] ?? '',
        groupName    : j['group_name'] ?? '',
        language     : j['language'] ?? '',
        source       : j['source'] ?? '',
        addedAt      : j['added_at'] ?? '',
        contentType  : j['content_type'] ?? 'movie',
        totalSeasons : j['total_seasons'] ?? 0,
      );
}
