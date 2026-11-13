import 'package:flutter/foundation.dart';

import 'data/models/diary_entry.dart';
import 'data/services/diary_repository.dart';

enum DiarySort { newest, highest, title }

class DiaryController extends ChangeNotifier {
  DiaryController(this.repository);
  final DiaryRepository repository;
  List<DiaryEntry> _entries = [];
  bool loading = true;
  bool saving = false;
  String? loadError;
  DiarySort sort = DiarySort.newest;
  String query = '';

  List<DiaryEntry> get entries => List.unmodifiable(_entries);
  List<DiaryEntry> get visibleEntries {
    final result = _entries
        .where(
          (e) => e.title.toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toList();
    result.sort((a, b) {
      final order = switch (sort) {
        DiarySort.newest => b.createdAt.compareTo(a.createdAt),
        DiarySort.highest => b.score.compareTo(a.score),
        DiarySort.title => a.title.compareTo(b.title),
      };
      return order != 0 ? order : b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  double get average => _entries.isEmpty
      ? 0
      : _entries.fold<int>(0, (sum, e) => sum + e.score) / _entries.length;

  Future<void> load() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      _entries = await repository.load();
    } catch (_) {
      loadError = '기록을 읽지 못했습니다. 데이터를 지우지 않고 다시 시도해 주세요.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void filter(String value) {
    query = value;
    notifyListeners();
  }

  void orderBy(DiarySort value) {
    sort = value;
    notifyListeners();
  }

  Future<void> upsert(DiaryEntry entry) async {
    final next = [..._entries];
    if (entry.tmdbId != null &&
        next.any((e) => e.tmdbId == entry.tmdbId && e.id != entry.id)) {
      throw StateError('이미 기록한 영화입니다. 기존 기록을 수정해 주세요.');
    }
    final index = next.indexWhere((e) => e.id == entry.id);
    if (index < 0) {
      next.add(entry);
    } else {
      next[index] = entry;
    }
    await _commit(next);
  }

  Future<void> delete(String id) async =>
      _commit(_entries.where((e) => e.id != id).toList());

  Future<void> _commit(List<DiaryEntry> next) async {
    if (loading || loadError != null || saving) {
      throw StateError('현재 작업이 끝난 뒤 다시 시도해 주세요.');
    }
    saving = true;
    notifyListeners();
    try {
      await repository.save(next);
      // 저장이 성공한 경우에만 화면 상태를 바꾼다.
      _entries = next;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
