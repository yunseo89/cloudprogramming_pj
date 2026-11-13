import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movielog_diary/data/models/diary_entry.dart';
import 'package:movielog_diary/data/services/diary_repository.dart';
import 'package:movielog_diary/diary_controller.dart';

DiaryEntry entry(
  String id, {
  String title = '인셉션',
  int score = 4,
  String comment = '다시 보고 싶은 영화',
  int? tmdbId,
  int day = 1,
}) => DiaryEntry(
  id: id,
  title: title,
  score: score,
  watchedOn: DateTime(2026, 1, day),
  comment: comment,
  createdAt: DateTime(2026, 1, day),
  tmdbId: tmdbId,
);

class MemoryRepository implements DiaryRepository {
  List<DiaryEntry> data = [];
  bool fail = false;
  Completer<void>? pending;
  int writes = 0;
  @override
  Future<List<DiaryEntry>> load() async {
    if (fail) throw StateError('read failed');
    return [...data];
  }

  @override
  Future<void> save(List<DiaryEntry> entries) async {
    writes++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('disk full');
    data = [...entries];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('T01 제목·별점·감상·관람일 경계 검증', () {
    expect(() => entry('1', title: '  '), throwsFormatException);
    expect(() => entry('1', title: '가' * 101), throwsFormatException);
    for (final score in [0, 6]) {
      expect(() => entry('1', score: score), throwsFormatException);
    }
    expect(() => entry('1', comment: '  '), throwsFormatException);
    expect(() => entry('1', comment: '가' * 501), throwsFormatException);
    expect(entry('1', title: ' 가 ', comment: ' 나 ').toJson()['title'], '가');
    expect(entry('1', score: 1, comment: '가' * 500).score, 1);
    expect(entry('1', score: 5).score, 5);
    expect(
      () => DiaryEntry(
        id: '1',
        title: '영화',
        score: 3,
        watchedOn: DateTime.now().add(const Duration(days: 1)),
        comment: '감상',
        createdAt: DateTime.now(),
      ),
      throwsFormatException,
    );
  });
  test('T02 JSON 왕복에서 필드 유지', () {
    final original = entry('1', tmdbId: 27205);
    expect(DiaryEntry.fromJson(original.toJson()).toJson(), original.toJson());
  });
  test('T03 기기 저장 후 새 저장소·컨트롤러에서 읽기', () async {
    SharedPreferences.setMockInitialValues({});
    final first = DiaryController(
      LocalDiaryRepository(await SharedPreferences.getInstance()),
    );
    await first.load();
    expect(first.entries, isEmpty);
    await first.upsert(entry('1'));
    final second = DiaryController(
      LocalDiaryRepository(await SharedPreferences.getInstance()),
    );
    await second.load();
    expect(second.entries.single.comment, '다시 보고 싶은 영화');
    expect(second.entries.single.score, 4);
  });
  test('T04 손상·버전 불일치·중복 저장은 읽기 거부, 원본 유지', () async {
    for (final raw in [
      '{broken',
      '{"version":2,"entries":[]}',
      jsonEncode({
        'version': 1,
        'entries': [entry('1').toJson(), entry('1').toJson()],
      }),
    ]) {
      SharedPreferences.setMockInitialValues({
        LocalDiaryRepository.storageKey: raw,
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = DiaryController(LocalDiaryRepository(prefs));
      await controller.load();
      expect(controller.loadError, isNotNull);
      await expectLater(controller.upsert(entry('2')), throwsStateError);
      expect(prefs.getString(LocalDiaryRepository.storageKey), raw);
    }
  });
  test('T05 CRUD: 수정은 같은 ID, 삭제는 대상만 제거', () async {
    final repo = MemoryRepository();
    final controller = DiaryController(repo);
    await controller.load();
    await controller.upsert(entry('1'));
    await controller.upsert(entry('2', title: '기생충'));
    await controller.upsert(entry('1', score: 5, comment: '수정한 감상'));
    expect(controller.entries.length, 2);
    expect(controller.entries.first.score, 5);
    await controller.delete('1');
    expect(controller.entries.single.id, '2');
    final second = DiaryController(repo);
    await second.load();
    expect(second.entries.single.id, '2');
  });
  test('T06 등록·수정·삭제 저장 실패 시 기존 상태 유지와 재시도', () async {
    final repo = MemoryRepository();
    final controller = DiaryController(repo);
    await controller.load();
    await controller.upsert(entry('1'));
    repo.fail = true;
    await expectLater(controller.upsert(entry('2')), throwsStateError);
    await expectLater(
      controller.upsert(entry('1', score: 1)),
      throwsStateError,
    );
    await expectLater(controller.delete('1'), throwsStateError);
    expect(controller.entries.single.score, 4);
    expect(controller.saving, false);
    repo.fail = false;
    await controller.upsert(entry('1', score: 5));
    expect(controller.entries.single.score, 5);
  });
  test('T07 중복 탭 방지: 저장 1회, 완료 전 목록 변경 없음', () async {
    final repo = MemoryRepository()..pending = Completer<void>();
    final controller = DiaryController(repo);
    await controller.load();
    final first = controller.upsert(entry('1'));
    expect(controller.saving, true);
    expect(controller.entries, isEmpty);
    await expectLater(controller.upsert(entry('2')), throwsStateError);
    repo.pending!.complete();
    await first;
    expect(repo.writes, 1);
    expect(controller.entries.length, 1);
  });
  test('T08 등록 최신순·평점순·제목순과 검색', () async {
    final controller = DiaryController(MemoryRepository());
    await controller.load();
    await controller.upsert(entry('1', title: 'B movie', score: 5, day: 1));
    await controller.upsert(entry('2', title: 'A movie', score: 3, day: 2));
    expect(controller.visibleEntries.first.id, '2');
    controller.orderBy(DiarySort.highest);
    expect(controller.visibleEntries.first.id, '1');
    controller.orderBy(DiarySort.title);
    expect(controller.visibleEntries.first.id, '2');
    controller.filter('  b MOVIE ');
    expect(controller.visibleEntries.single.id, '1');
    controller.filter('없는 영화');
    expect(controller.visibleEntries, isEmpty);
    expect(controller.entries.length, 2);
    expect(controller.average, 4);
  });
  test('T09 같은 TMDB 영화 중복 등록 거부', () async {
    final controller = DiaryController(MemoryRepository());
    await controller.load();
    await controller.upsert(entry('1', tmdbId: 27205));
    await expectLater(
      controller.upsert(entry('2', tmdbId: 27205)),
      throwsStateError,
    );
    expect(controller.entries.length, 1);
  });
  test('T10 읽기 실패 후 재시도 복구', () async {
    final repo = MemoryRepository()..fail = true;
    final controller = DiaryController(repo);
    await controller.load();
    expect(controller.loadError, isNotNull);
    repo.fail = false;
    repo.data = [entry('1')];
    await controller.load();
    expect(controller.loadError, isNull);
    expect(controller.entries.length, 1);
  });
}
