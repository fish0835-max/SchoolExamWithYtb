import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

// window_manager 僅在桌面平台使用
import 'package:window_manager/window_manager.dart'
    if (dart.library.html) 'core/services/stub/window_manager_stub.dart';

import 'app.dart';
import 'core/services/local_db_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 載入 .env（API keys）──
  // assets/.env 已加入 .gitignore，需手動建立：
  //   cp assets/.env.example assets/.env
  await dotenv.load(fileName: 'assets/.env');

  // ── 初始化 Firebase ──
  // lib/firebase_options.dart 已加入 .gitignore，需執行：
  //   flutterfire configure --project=schoolexam-b5cc7
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── 初始化本地 SQLite 離線題庫 ──
  await LocalDbService.instance.init();

  // ── 桌面視窗設定（web 跳過）──
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(400, 800),
      minimumSize: Size(360, 640),
      center: true,
      title: '康軒學習遊戲',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    const ProviderScope(
      child: SchoolExamApp(),
    ),
  );
}
