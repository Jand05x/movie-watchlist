import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TmdbService {
  static final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';

  static const String _base = 'https://api.themoviedb.org/3';
  static const String imageBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/w1280';

  static Future<List<Map<String, dynamic>>> _getResults(
    String endpoint, {
    Map<String, String> queryParameters = const {},
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('TMDB_API_KEY is missing. Check your .env file.');
    }

    final uri = Uri.parse('$_base$endpoint').replace(
      queryParameters: {'api_key': _apiKey, ...queryParameters},
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('TMDB request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return List<Map<String, dynamic>>.from(data['results'] ?? []);
  }

  // Trending movies this week
  static Future<List<Map<String, dynamic>>> trendingMovies() {
    return _getResults('/trending/movie/week');
  }

  // Popular movies
  static Future<List<Map<String, dynamic>>> popularMovies() {
    return _getResults('/movie/popular');
  }

  // Top-rated movies
  static Future<List<Map<String, dynamic>>> topRatedMovies() {
    return _getResults('/movie/top_rated');
  }

  // Popular TV shows, normalized to work with your existing screens
  static Future<List<Map<String, dynamic>>> popularTvShows() async {
    final shows = await _getResults('/tv/popular');

    return shows.map((show) {
      return {
        ...show,
        'title': show['name'] ?? 'Untitled',
        'release_date': show['first_air_date'] ?? '',
        'media_type': 'tv',
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> discoverByGenre(int genreId) {
    return _getResults(
      '/discover/movie',
      queryParameters: {
        'with_genres': genreId.toString(),
        'sort_by': 'popularity.desc',
      },
    );
  }

  static Future<List<Map<String, dynamic>>> searchMovies(String query) {
    return _getResults(
      '/search/movie',
      queryParameters: {'query': query},
    );
  }

  // Movie details, including cast and crew
  static Future<Map<String, dynamic>?> getMovieDetails(int id) async {
    if (_apiKey.isEmpty) {
      throw Exception('TMDB_API_KEY is missing. Check your .env file.');
    }

    final uri = Uri.parse('$_base/movie/$id').replace(
      queryParameters: {'api_key': _apiKey, 'append_to_response': 'credits'},
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('TMDB details request failed: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>?> getTvDetails(int id) async {
    if (_apiKey.isEmpty) {
      throw Exception('TMDB_API_KEY is missing. Check your .env file.');
    }

    final uri = Uri.parse('$_base/tv/$id').replace(
      queryParameters: {'api_key': _apiKey, 'append_to_response': 'credits'},
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final details = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        ...details,
        'title': details['name'] ?? 'Untitled',
        'release_date': details['first_air_date'] ?? '',
        'media_type': 'tv',
      };
    }

    throw Exception('TMDB details request failed: ${response.statusCode}');
  }
}
