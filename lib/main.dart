import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/services/diary_repository.dart';
import 'diary_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final preferences = await SharedPreferences.getInstance();
    final controller = DiaryController(LocalDiaryRepository(preferences));
    runApp(MovieLogApp(controller: controller));
    await controller.load();
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('기기 저장소를 열지 못했습니다.'),
                TextButton(onPressed: main, child: const Text('다시 시도')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
