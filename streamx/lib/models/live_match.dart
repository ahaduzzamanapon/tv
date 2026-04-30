// models/live_match.dart
class LiveMatch {
  final int id;
  final String matchTitle;
  final String league;
  final String team1;
  final String team2;
  final String team1Logo;
  final String team2Logo;
  final List<dynamic> streamUrls;
  final String matchStatus;
  final String startTimeBd;
  final String posterUrl;
  final String source;

  LiveMatch({
    required this.id,
    required this.matchTitle,
    required this.league,
    required this.team1,
    required this.team2,
    required this.team1Logo,
    required this.team2Logo,
    required this.streamUrls,
    required this.matchStatus,
    required this.startTimeBd,
    required this.posterUrl,
    required this.source,
  });

  bool get isLive => matchStatus.toUpperCase() == 'LIVE';

  factory LiveMatch.fromJson(Map<String, dynamic> j) => LiveMatch(
        id           : j['id'] ?? 0,
        matchTitle   : j['match_title'] ?? '',
        league       : j['league'] ?? '',
        team1        : j['team1'] ?? '',
        team2        : j['team2'] ?? '',
        team1Logo    : j['team1_logo'] ?? '',
        team2Logo    : j['team2_logo'] ?? '',
        streamUrls   : j['stream_urls'] is List ? j['stream_urls'] : [],
        matchStatus  : j['match_status'] ?? 'Upcoming',
        startTimeBd  : j['start_time_bd'] ?? '',
        posterUrl    : j['poster_url'] ?? '',
        source       : j['source'] ?? '',
      );
}
