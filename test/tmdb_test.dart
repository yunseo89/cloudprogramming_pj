import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog_diary/app.dart';
import 'package:movielog_diary/data/models/tmdb_movie_dto.dart';
import 'package:movielog_diary/data/services/tmdb_movie_service.dart';

class StubAdapter implements HttpClientAdapter {
  RequestOptions? request;
  int status = 200;
  List<Map<String, dynamic>> results = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({'results': results}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class DeferredService extends TmdbMovieService {
  DeferredService() : super(Dio());
  final requests = <String, Completer<List<TmdbMovieDto>>>{};
  @override
  Future<List<TmdbMovieDto>> search(String query) =>
      (requests[query] = Completer<List<TmdbMovieDto>>()).future;
}

TmdbMovieDto movie(int id, String title) =>
    TmdbMovieDto.fromJson({'id': id, 'title': title});
void main() {
  test('T17 TMDB 검색 경로·한국어·ID·누락 포스터 계약', () async {
    final adapter = StubAdapter()
      ..results = [
        {'id': 27205, 'title': '인셉션', 'release_date': '2010-07-15'},
      ];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'))
      ..httpClientAdapter = adapter;
    final results = await TmdbMovieService(dio).search('  인셉션 ');
    expect(adapter.request!.path, '/search/movie');
    expect(adapter.request!.queryParameters['language'], 'ko-KR');
    expect(adapter.request!.queryParameters['query'], '인셉션');
    expect(adapter.request!.queryParameters['include_adult'], false);
    expect(results.single.id, 27205);
    expect(results.single.posterPath, isNull);
  });
  test('T18 TMDB 결과 없음·401·500 실패 구분', () async {
    final adapter = StubAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'))
      ..httpClientAdapter = adapter;
    final service = TmdbMovieService(dio);
    expect(await service.search('없는 영화'), isEmpty);
    for (final status in [401, 500]) {
      adapter.status = status;
      await expectLater(service.search('영화'), throwsA(isA<DioException>()));
    }
  });
  testWidgets('T19 늦게 온 검색 응답은 현재 결과를 덮어쓰지 않음', (tester) async {
    final service = DeferredService();
    await tester.pumpWidget(
      MaterialApp(home: MovieSearchDialog(service: service)),
    );
    await tester.enterText(find.byType(TextField), '과거');
    await tester.tap(find.byTooltip('검색'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '현재');
    await tester.tap(find.byTooltip('검색'));
    await tester.pump();
    service.requests['현재']!.complete([movie(2, '새 결과')]);
    await tester.pumpAndSettle();
    service.requests['과거']!.complete([movie(1, '오래된 결과')]);
    await tester.pumpAndSettle();
    expect(find.text('새 결과'), findsOneWidget);
    expect(find.text('오래된 결과'), findsNothing);
  });
  testWidgets('T20 검색 실패 후 재시도·빈 결과 안내', (tester) async {
    final service = DeferredService();
    await tester.pumpWidget(
      MaterialApp(home: MovieSearchDialog(service: service)),
    );
    await tester.enterText(find.byType(TextField), '인셉션');
    await tester.tap(find.byTooltip('검색'));
    await tester.pump();
    service.requests['인셉션']!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('영화를 불러오지 못했습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('검색'));
    await tester.pump();
    service.requests['인셉션']!.complete([]);
    await tester.pumpAndSettle();
    expect(find.textContaining('검색 결과가 없습니다.'), findsOneWidget);
  });
}
