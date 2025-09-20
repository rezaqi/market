import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelper {
  static Database? _db;

  DBHelper() {
    sqfliteFfiInit();
  }

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  initDb() async {
    String dbPath = await databaseFactoryFfi.getDatabasesPath();
    String path = join(dbPath, 'users.db');

    // ✨ لا تمسح القاعدة هنا
    // await databaseFactoryFfi.deleteDatabase(path);

    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            password TEXT
          )
        ''');
          await db.insert("users", {"username": "admin", "password": "123456"});
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    var dbClient = await db;
    return await dbClient.query("users");
  }

  Future<int> updateAdminInfo({
    required String username,
    required String password,
  }) async {
    final dbClient = await db;
    return await dbClient.update(
      "users",
      {"username": username, "password": password},
      where: "id = ?",
      whereArgs: [1],
    );
  }

  Future<Map<String, dynamic>> getAdminInfo() async {
    final dbClient = await db;
    final result = await dbClient.query(
      "users",
      where: "id = ?",
      whereArgs: [1], // نفترض أن الأدمن دائمًا له ID = 1
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first; // يحتوي على 'username' و 'password'
    } else {
      // لو مفيش بيانات أدمن، ممكن ترجع قيم افتراضية
      return {"username": "admin", "password": "1234"};
    }
  }
}
