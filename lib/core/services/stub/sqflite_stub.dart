// Web stub for sqflite
// Dart 在 web 編譯時仍會檢查所有方法，因此需補齊所有用到的 API
// 實際執行時 kIsWeb == true，SQLite 路徑永遠不會被呼叫

class Database {
  Future<void> execute(String sql) async {}
  Future<List<Map<String, Object?>>> rawQuery(String sql) async => [];
  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async => [];
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async => 0;
  Batch batch() => Batch();
}

class Batch {
  void insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {}
  Future<List<Object?>> commit({bool? noResult}) async => [];
}

class ConflictAlgorithm {
  static const ignore = ConflictAlgorithm._('ignore');
  static const replace = ConflictAlgorithm._('replace');
  const ConflictAlgorithm._(String _);
}

class Sqflite {
  static int? firstIntValue(List<Map<String, Object?>> _) => null;
}

Future<String> getDatabasesPath() async => '';

Future<Database> openDatabase(
  String path, {
  int? version,
  dynamic onCreate,
  dynamic onUpgrade,
}) async => Database();
