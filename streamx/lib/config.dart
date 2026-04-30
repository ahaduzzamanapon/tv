// config.dart — API Configuration
// এখানে API URL এবং Key দিন

class AppConfig {
  // ──────────────────────────────────────────
  //  API Settings
  // ──────────────────────────────────────────
  static const String baseUrl  = 'https://tv.ehealthfinder.com';
  static const String apiKey   = 'mhub_f41025f6bfe776741e8e19ef315ac15fae9b6f5a6b9bb7c7';
  static const String appVersion = '1.0.0'; // current app version

  // ──────────────────────────────────────────
  //  App Info
  // ──────────────────────────────────────────
  static const String appName  = 'StreamX';
  static const String tagLine  = 'Movies · Live · TV';

  // ──────────────────────────────────────────
  //  Endpoints
  // ──────────────────────────────────────────
  static String get versionUrl  => '$baseUrl/api/v1/app/version?v=$appVersion';
  static String get liveUrl     => '$baseUrl/api/v1/live';
  static String get moviesUrl   => '$baseUrl/api/v1/movies';
  static String get channelsUrl => '$baseUrl/api/v1/channels';

  // ──────────────────────────────────────────
  //  Default Pagination
  // ──────────────────────────────────────────
  static const int defaultLimit = 20;

  // ──────────────────────────────────────────
  //  Theme Colors (reference)
  // ──────────────────────────────────────────
  static const int primaryRed  = 0xFFE63946;
  static const int bgDark      = 0xFF070B14;
  static const int bgCard      = 0xFF0D1525;
  static const int bgCard2     = 0xFF111C30;
}
