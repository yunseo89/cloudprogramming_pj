import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog_diary/app.dart';
import 'package:movielog_diary/diary_controller.dart';

import 'diary_test.dart' show MemoryRepository, entry;

void main() {
  Future<DiaryController> start(WidgetTester tester) async {
    final controller = DiaryController(MemoryRepository());
    await controller.load();
    await tester.pumpWidget(MovieLogApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, '영화 제목'), '인셉션');
    await tester.enterText(
      find.widgetWithText(TextFormField, '감상 (필수)'),
      '꿈과 현실이 겹치는 장면이 인상적이다.',
    );
    await tester.tap(find.byTooltip('4점'));
    await tester.pump();
  }

  testWidgets('T11 빈 입력 거절 → 등록 → 수정 → 삭제 취소 → 삭제', (tester) async {
    final controller = await start(tester);
    await tester.tap(find.text('직접 기록하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('제목을 입력해 주세요.'), findsOneWidget);
    expect(find.text('감상을 한 줄 이상 입력해 주세요.'), findsOneWidget);
    expect(controller.entries, isEmpty);
    await fill(tester);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(controller.entries.single.score, 4);
    expect(find.text('기록을 저장했습니다.'), findsOneWidget);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(find.text('꿈과 현실이 겹치는 장면이 인상적이다.'), findsWidgets);
    await tester.tap(find.byTooltip('5점'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(controller.entries.single.score, 5);
    expect(controller.entries.length, 1);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(controller.entries.length, 1);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제 확인'));
    await tester.pumpAndSettle();
    expect(controller.entries, isEmpty);
  });
  testWidgets('T12 별점 미선택 거절', (tester) async {
    final controller = await start(tester);
    await tester.tap(find.text('직접 기록하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '영화 제목'), '인셉션');
    await tester.enterText(find.widgetWithText(TextFormField, '감상 (필수)'), '감상');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(controller.entries, isEmpty);
    expect(find.text('별점을 선택해 주세요.'), findsWidgets);
  });
  testWidgets('T13 저장 실패 시 입력 유지, 재시도 성공', (tester) async {
    final controller = await start(tester);
    final repo = controller.repository as MemoryRepository;
    await tester.tap(find.text('직접 기록하기'));
    await tester.pumpAndSettle();
    await fill(tester);
    repo.fail = true;
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 못했습니다. 입력은 유지됩니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('인셉션'), findsOneWidget);
    expect(controller.entries, isEmpty);
    repo.fail = false;
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(controller.entries.length, 1);
  });
  testWidgets('T14 저장 중 취소·중복 저장 비활성', (tester) async {
    final controller = await start(tester);
    final repo = controller.repository as MemoryRepository;
    repo.pending = Completer<void>();
    await tester.tap(find.text('직접 기록하기'));
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '저장 중…'))
          .onPressed,
      isNull,
    );
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
  });
  testWidgets('T15 토큰 미설정 안내 후 직접 입력 가능', (tester) async {
    await start(tester);
    await tester.tap(find.text('영화 찾아 기록하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TMDB 토큰이 설정되지 않았습니다.'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 기록하기'));
    await tester.pumpAndSettle();
    expect(find.text('영화 기록 남기기'), findsOneWidget);
  });
  testWidgets('T16 360px 화면에서 목록·입력창 overflow 없음', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await start(tester);
    await controller.upsert(entry('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
