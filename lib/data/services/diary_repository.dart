import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_entry.dart';

abstract interface class DiaryRepository {
  Future<List<DiaryEntry>> load();
  Future<void> save(List<DiaryEntry> entries);
}

class LocalDiaryRepository implements DiaryRepository {
  LocalDiaryRepository(this.preferences);
  final SharedPreferences preferences;
  static const storageKey = 'movielog.diary.v1';

  @override
  Future<List<DiaryEntry>> load() async {
    await preferences.reload();
    final raw = preferences.getString(storageKey);
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1) throw const FormatException('Unknown version');
      final entries = (data['entries'] as List)
          .map((item) => DiaryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      if (entries.map((e) => e.id).toSet().length != entries.length) {
        throw const FormatException('Duplicate id');
      }
      final movieIds = entries.map((e) => e.tmdbId).whereType<int>().toList();
      if (movieIds.toSet().length != movieIds.length) {
        throw const FormatException('Duplicate movie');
      }
      return entries;
    } catch (_) {
      // 손상된 원본을 빈 목록으로 덮어쓰지 않는다.
      throw const FormatException('저장된 기록을 읽을 수 없습니다. 원본 데이터는 유지됩니다.');
    }
  }

  @override
  Future<void> save(List<DiaryEntry> entries) async {
    final saved = await preferences.setString(
      storageKey,
      jsonEncode({
        'version': 1,
        'entries': entries.map((e) => e.toJson()).toList(),
      }),
    );
    if (!saved) throw StateError('기기 저장 공간에 기록하지 못했습니다.');
  }
}
