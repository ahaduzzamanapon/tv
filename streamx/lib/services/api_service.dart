// services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/live_match.dart';
import '../models/movie.dart';
import '../models/channel.dart';

class ApiService {
  static const _headers = {'Content-Type': 'application/json'};

  static Uri _buildUri(String base, [Map<String, String>? params]) {
    final all = <String, String>{'api_key': AppConfig.apiKey, ...?params};
    return Uri.parse(base).replace(queryParameters: all);
  }

  static Future<Map<String, dynamic>> _get(String baseUrl, [Map<String, String>? params]) async {
    final uri = _buildUri(baseUrl, params);
    debugPrint('[API] GET → $uri');
    try {
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      debugPrint('[API] STATUS ${res.statusCode} ← ${uri.path}');
      if (res.statusCode == 200) return json.decode(res.body);
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      debugPrint('[API] EXCEPTION: $e');
      rethrow;
    }
  }

  // ── Version Check ──
  static Future<Map<String, dynamic>> checkVersion() async {
    try {
      final res = await http.get(Uri.parse(AppConfig.versionUrl)).timeout(const Duration(seconds: 10));
      return json.decode(res.body);
    } catch (e) { rethrow; }
  }

  // ── Live Matches ──
  static Future<Map<String, dynamic>> getLive({String? league, String? status, String? search}) async {
    final params = <String, String>{};
    if (league != null && league.isNotEmpty) params['league'] = league;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final body = await _get(AppConfig.liveUrl, params);
    return {
      'matches'           : (body['data'] as List).map((e) => LiveMatch.fromJson(e)).toList(),
      'total'             : body['total'] ?? 0,
      'live_count'        : body['live_count'] ?? 0,
      'upcoming_count'    : body['upcoming_count'] ?? 0,
      'available_filters' : body['available_filters'] ?? {},
    };
  }

  // ── Movies ──
  static Future<Map<String, dynamic>> getMovies({
    int page = 1,
    int limit = AppConfig.defaultLimit,
    String? search,
    String? category,
    String? language,
    String? quality,
    String sort = 'newest',
    String contentType = 'movie',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'sort': sort,
      'content_type': contentType,
    };
    if (search   != null && search.isNotEmpty)   params['search']   = search;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (language != null && language.isNotEmpty) params['language'] = language;
    if (quality  != null && quality.isNotEmpty)  params['quality']  = quality;
    final body = await _get(AppConfig.moviesUrl, params);
    return {
      'movies'            : (body['data'] as List).map((e) => Movie.fromJson(e)).toList(),
      'total'             : body['total'] ?? 0,
      'page'              : body['page'] ?? 1,
      'total_pages'       : body['total_pages'] ?? 1,
      'available_filters' : body['available_filters'] ?? {},
    };
  }

  // ── Web Series ──
  static Future<Map<String, dynamic>> getSeries({
    int page = 1,
    int limit = AppConfig.defaultLimit,
    String? search,
    String? category,
    String? language,
    String sort = 'newest',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'sort': sort,
    };
    if (search   != null && search.isNotEmpty)   params['search']   = search;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (language != null && language.isNotEmpty) params['language'] = language;
    final body = await _get('${AppConfig.baseUrl}/api/v1/series', params);
    return {
      'series'            : (body['data'] as List).map((e) => Movie.fromJson(e)).toList(),
      'total'             : body['total'] ?? 0,
      'page'              : body['page'] ?? 1,
      'total_pages'       : body['total_pages'] ?? 1,
      'available_filters' : body['available_filters'] ?? {},
    };
  }

  // ── Series Episodes ──
  static Future<Map<String, dynamic>> getSeriesEpisodes(int seriesId, {int? season}) async {
    final params = <String, String>{};
    if (season != null) params['season'] = '$season';
    final body = await _get('${AppConfig.baseUrl}/api/v1/series/$seriesId/episodes', params);
    return {
      'episodes'          : body['data'] as List? ?? [],
      'series'            : body['series'] as Map<String, dynamic>? ?? {},
      'total_episodes'    : body['total_episodes'] ?? 0,
      'available_seasons' : body['available_seasons'] as List? ?? [],
      'current_season'    : body['current_season'] ?? 1,
    };
  }

  // ── TV Channels ──
  static Future<Map<String, dynamic>> getChannels({
    int page = 1,
    int limit = 50,
    String? group,
    String? search,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (group  != null && group.isNotEmpty)  params['group']  = group;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final body = await _get(AppConfig.channelsUrl, params);
    return {
      'channels'          : (body['data'] as List).map((e) => Channel.fromJson(e)).toList(),
      'total'             : body['total'] ?? 0,
      'total_pages'       : body['total_pages'] ?? 1,
      'available_filters' : body['available_filters'] ?? {},
    };
  }
}
