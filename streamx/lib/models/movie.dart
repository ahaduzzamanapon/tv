// models/movie.dart
class Movie {
  final int id;
  final String title;
  final String quality;
  final String streamUrl;
  final String posterUrl;
  final String groupName;
  final String language;
  final String source;
  final String addedAt;

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
  });

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id        : j['id'] ?? 0,
        title     : j['title'] ?? '',
        quality   : j['quality'] ?? '',
        streamUrl : j['stream_url'] ?? '',
        posterUrl : j['poster_url'] ?? '',
        groupName : j['group_name'] ?? '',
        language  : j['language'] ?? '',
        source    : j['source'] ?? '',
        addedAt   : j['added_at'] ?? '',
      );
}
