import 'dart:math';

String moviePickKey(Map<String, dynamic> movie) {
  final id = movie['tmdb_id'] ?? movie['id'] ?? movie['title'] ?? '';
  final mediaType = movie['media_type'] ?? 'movie';
  return '$mediaType:$id';
}

Map<String, dynamic>? pickRandomMovie(
  List<Map<String, dynamic>> movies,
  Random random, {
  String? lastKey,
}) {
  if (movies.isEmpty) return null;

  final candidates = lastKey == null || lastKey.isEmpty
      ? movies
      : movies.where((movie) => moviePickKey(movie) != lastKey).toList();
  final pool = candidates.isEmpty ? movies : candidates;
  return pool[random.nextInt(pool.length)];
}
