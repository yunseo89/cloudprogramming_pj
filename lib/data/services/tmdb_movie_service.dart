import 'package:dio/dio.dart';

import '../models/tmdb_movie_dto.dart';

// MovieLog의 Dio 서비스 패턴과 한국어 queryParameters를 재사용했다.
class TmdbMovieService {
  TmdbMovieService(this._dio);
  final Dio _dio;

  static const token = String.fromEnvironment('TMDB_ACCESS_TOKEN');
  static bool get configured => token.trim().isNotEmpty;
  static TmdbMovieService configuredService() => TmdbMovieService(
    Dio(
      BaseOptions(
        baseUrl: 'https://api.themoviedb.org/3',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': 'application/json',
        },
      ),
    ),
  );

  Future<List<TmdbMovieDto>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final response = await _dio.get(
      '/search/movie',
      queryParameters: {
        'query': query.trim(),
        'language': 'ko-KR',
        'page': 1,
        'include_adult': false,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['results'] as List)
        .map((item) => TmdbMovieDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
