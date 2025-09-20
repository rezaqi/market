import 'dart:convert';
import 'dart:io';

import 'package:market/feature_admin/home/data/model/product_model.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelperAdmin {
  static final DBHelperAdmin _instance = DBHelperAdmin._internal();
  factory DBHelperAdmin() => _instance;
  DBHelperAdmin._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<List<Map<String, dynamic>>> searchInvoicesByNameOrBarcode(
    String query,
  ) async {
    final allInvoices = await getInvoices(); // جلب كل الفواتير
    final filtered = allInvoices.where((invoice) {
      final items = invoice["items"] as List<dynamic>? ?? [];
      return items.any((item) {
        final name = (item["name"]?.toString() ?? "").toLowerCase();
        final barcode = (item["barcode"]?.toString() ?? "").toLowerCase();
        return name.contains(query) || barcode.contains(query);
      });
    }).toList();
    return filtered;
  }

  // ✅ زيادة المخزون عند المرتجع
  Future<void> increaseStock(int productId, int qty) async {
    final db = await database;
    final result = await db.query(
      "products",
      where: "id = ?",
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      final currentQty = result.first["quantity"] as int? ?? 0;
      final newQty = currentQty + qty;

      await db.update(
        "products",
        {"quantity": newQty},
        where: "id = ?",
        whereArgs: [productId],
      );
    }
  }

  // ✅ تعديل الفاتورة بعد المرتجع
  Future<void> updateInvoice(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      "invoices",
      {
        "total": data["total"],
        "discount": data["discount"],
        "finalTotal": data["finalTotal"],
        "customerPaid": data["customerPaid"],
        "cashierReturn": data["cashierReturn"],
        "items": jsonEncode(data["items"]),
      },
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<void> printDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'win_market_admin.db');

    // اطبع المسار في الكونسول
    print("📂 Database path: $path");

    // تحقق إذا الملف موجود فعلاً
    final file = File(path);
    if (await file.exists()) {
      print("✅ Database file exists");
    } else {
      print("❌ Database file not found yet");
    }
  }

  Future<String> _getDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'win_market_admin.db');
    return path;
  }

  Future<void> saveAutoDeleteSetting(String label, int days) async {
    final dbClient = await database;
    await dbClient.insert("settings", {
      "key": "autoDelete",
      "label": label,
      "days": days,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getAutoDeleteSetting() async {
    final dbClient = await database;
    final result = await dbClient.query(
      "settings",
      where: "key = ?",
      whereArgs: ["autoDelete"],
      limit: 1,
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'TRIM(barcode) = ?',
      whereArgs: [barcode.trim()],
      limit: 1,
    );
    print("📦 نتائج البحث: $maps");
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<Database> _initDb() async {
    final path = await _getDbPath();

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5, // <- رفع إلى 5
        onCreate: (db, version) async {
          // (حافظ على جداولك القديمة كما هي...)
          await db.execute('''CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            total REAL,
            discount REAL,
            finalTotal REAL,
            customerPaid REAL,
            cashierReturn REAL,
            items TEXT,
            isDeleted INTEGER DEFAULT 0
          )''');

          await db.execute('''CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            barcode TEXT,
            price REAL,
            quantity INTEGER DEFAULT 0,
            category TEXT,
            expire TEXT
          )''');

          await db.execute('''CREATE TABLE shifts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cashierName TEXT,
            startTime TEXT,
            endTime TEXT,
            totalSales REAL DEFAULT 0
          )''');

          await db.execute('''CREATE TABLE settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE,
            label TEXT,
            days INTEGER
          )''');

          // جدول الأرشيف للفواتير المحذوفة نهائياً (نحتفظ بنسخة لإحصاءات المبيعات)
          await db.execute('''CREATE TABLE archived_invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            originalId INTEGER,
            date TEXT,
            total REAL,
            discount REAL,
            finalTotal REAL,
            customerPaid REAL,
            cashierReturn REAL,
            items TEXT,
            deletedAt TEXT
          )''');

          // جدول المرتجعات
          await db.execute('''CREATE TABLE returns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoiceId INTEGER,
  date TEXT,
  items TEXT,
  refundedAmount REAL,
  note TEXT,
  isDeleted INTEGER DEFAULT 0,
  deleteAfter TEXT  -- 🟢 إضافة العمود هنا
)''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE invoices ADD COLUMN isDeleted INTEGER DEFAULT 0',
            );
          }
          if (oldVersion < 4) {
            await db.execute('ALTER TABLE products ADD COLUMN expire TEXT');
          }
          if (oldVersion < 5) {
            // لو حد مثبت نسخة قديمة، ننشئ الجداول الجديدة
            await db.execute('''CREATE TABLE IF NOT EXISTS archived_invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            originalId INTEGER,
            date TEXT,
            total REAL,
            discount REAL,
            finalTotal REAL,
            customerPaid REAL,
            cashierReturn REAL,
            items TEXT,
            deletedAt TEXT
          )''');

            await db.execute('''CREATE TABLE IF NOT EXISTS returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoiceId INTEGER,
            date TEXT,
            items TEXT,
            refundedAmount REAL,
            note TEXT,
            isDeleted INTEGER DEFAULT 0
          )''');
          }
          if (oldVersion < 6) {
            // لو العمود deleteAfter غير موجود، نضيفه
            await db.execute('ALTER TABLE returns ADD COLUMN deleteAfter TEXT');
          }
        },
      ),
    );
  }

  // فتح وردية جديدة
  Future<int> openShift() async {
    final db = await database;
    return await db.insert("shifts", {
      //"cashierName": cashierName,
      "startTime": DateTime.now().toIso8601String(),
      "endTime": null,
      "totalSales": 0,
    });
  }

  // تحديث إجمالي المبيعات أثناء الوردية
  Future<void> addSaleToShift(num saleAmount) async {
    final db = await database;
    final openShifts = await db.query(
      "shifts",
      where: "endTime IS NULL",
      orderBy: "id DESC",
      limit: 1,
    );
    if (openShifts.isNotEmpty) {
      final shift = openShifts.first;
      final newTotal = (shift["totalSales"] as double) + saleAmount;
      await db.update(
        "shifts",
        {"totalSales": newTotal},
        where: "id = ?",
        whereArgs: [shift["id"]],
      );
    }
  }

  // قفل وردية
  Future<void> closeShift(int shiftId) async {
    final db = await database;
    await db.update(
      "shifts",
      {"endTime": DateTime.now().toIso8601String()},
      where: "id = ?",
      whereArgs: [shiftId],
    );
  }

  // جلب الوردية الحالية
  Future<Map<String, dynamic>?> getCurrentShift() async {
    final db = await database;
    final result = await db.query(
      "shifts",
      where: "endTime IS NULL",
      orderBy: "id DESC",
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertInvoice(Map<String, dynamic> invoice) async {
    final db = await database;
    return await db.insert('invoices', {
      "date": invoice["date"],
      "total": invoice["total"],
      "discount": invoice["discount"],
      "finalTotal": invoice["finalTotal"],
      "customerPaid": invoice["customerPaid"], // ✅
      "cashierReturn": invoice["cashierReturn"], // ✅
      "items": jsonEncode(invoice["items"]),
    });
  }

  // Future<double> getInvoicesTotal({DateTime? from, DateTime? to}) async {
  //   final db = await database;
  //   String where = "";
  //   List whereArgs = [];

  //   if (from != null && to != null) {
  //     where = "date BETWEEN ? AND ?";
  //     whereArgs = [from.toIso8601String(), to.toIso8601String()];
  //   }

  //   final result = await db.rawQuery(
  //     "SELECT SUM(finalTotal) as total FROM invoices ${where.isNotEmpty ? "WHERE $where" : ""}",
  //     whereArgs,
  //   );

  //   final total = result.first["total"] as num?;
  //   return total?.toDouble() ?? 0.0;
  // }

  // ===== getInvoices: الآن يعرض فقط الفواتير غير المحذوفة (isDeleted = 0)
  Future<List<Map<String, dynamic>>> getInvoices({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    String where = "isDeleted = 0";
    List whereArgs = [];

    if (from != null && to != null) {
      where += " AND date BETWEEN ? AND ?";
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    }

    final res = await db.query(
      "invoices",
      where: where,
      whereArgs: whereArgs,
      orderBy: "date DESC",
    );

    return res.map((row) {
      return {
        "id": row["id"],
        "date": row["date"],
        "total": row["total"],
        "discount": row["discount"],
        "finalTotal": row["finalTotal"],
        "customerPaid": row["customerPaid"] ?? 0,
        "cashierReturn": row["cashierReturn"] ?? 0,
        "items": jsonDecode(row["items"] as String),
      };
    }).toList();
  }

  // ===== getInvoicesTotal: يحسب مجموع finalTotal من invoices + archived_invoices
  Future<double> getInvoicesTotal({DateTime? from, DateTime? to}) async {
    final db = await database;
    String where = "";
    List whereArgs = [];

    if (from != null && to != null) {
      where = "date BETWEEN ? AND ?";
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    }

    final r1 = await db.rawQuery(
      "SELECT SUM(finalTotal) as total FROM invoices ${where.isNotEmpty ? "WHERE $where" : ""}",
      whereArgs,
    );
    final num t1 = r1.first["total"] as num? ?? 0;

    final r2 = await db.rawQuery(
      "SELECT SUM(finalTotal) as total FROM archived_invoices ${where.isNotEmpty ? "WHERE $where" : ""}",
      whereArgs,
    );
    final num t2 = r2.first["total"] as num? ?? 0;

    return (t1.toDouble() + t2.toDouble());
  }

  // ===== جلب الفواتير المحذوفة (isDeleted = 1)
  Future<List<Map<String, dynamic>>> getDeletedInvoices({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    String where = "isDeleted = 1";
    List whereArgs = [];

    if (from != null && to != null) {
      where += " AND date BETWEEN ? AND ?";
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    }

    final res = await db.query(
      "invoices",
      where: where,
      whereArgs: whereArgs,
      orderBy: "date DESC",
    );

    return res.map((row) {
      return {
        "id": row["id"],
        "date": row["date"],
        "total": row["total"],
        "discount": row["discount"],
        "finalTotal": row["finalTotal"],
        "customerPaid": row["customerPaid"] ?? 0,
        "cashierReturn": row["cashierReturn"] ?? 0,
        "items": jsonDecode(row["items"] as String),
      };
    }).toList();
  }

  // ===== أرشفة فاتورة (نقل لجدول archived_invoices ثم حذفها من invoices)
  Future<int> archiveInvoice(int id) async {
    final db = await database;
    final rows = await db.query(
      "invoices",
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    final row = rows.first;
    await db.insert('archived_invoices', {
      "originalId": row['id'],
      "date": row['date'],
      "total": row['total'],
      "discount": row['discount'],
      "finalTotal": row['finalTotal'],
      "customerPaid": row['customerPaid'],
      "cashierReturn": row['cashierReturn'],
      "items": row['items'],
      "deletedAt": DateTime.now().toIso8601String(),
    });
    return await db.delete('invoices', where: "id = ?", whereArgs: [id]);
  }

  // ===== جلب الأرشيف (الفواتير المؤرشفة نهائياً)
  Future<List<Map<String, dynamic>>> getArchivedInvoices({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    String where = "";
    List whereArgs = [];
    if (from != null && to != null) {
      where = "date BETWEEN ? AND ?";
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    }
    final res = await db.query(
      'archived_invoices',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return res.map((row) {
      return {
        "id": row["id"],
        "originalId": row["originalId"],
        "date": row["date"],
        "total": row["total"],
        "discount": row["discount"],
        "finalTotal": row["finalTotal"],
        "customerPaid": row["customerPaid"],
        "cashierReturn": row["cashierReturn"],
        "items": jsonDecode(row["items"] as String),
        "deletedAt": row["deletedAt"],
      };
    }).toList();
  }

  // ===== حذف نهائي من الأرشيف (مسح تام)
  Future<int> deleteArchivedInvoice(int id) async {
    final db = await database;
    return await db.delete(
      'archived_invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===== تعديل deleteInvoicesBefore: بدلاً من حذف نهائي، ننقلها للأرشيف
  Future<int> deleteInvoicesBefore(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      'invoices',
      where: 'date < ?',
      whereArgs: [date.toIso8601String()],
    );
    for (var row in rows) {
      await db.insert('archived_invoices', {
        "originalId": row['id'],
        "date": row['date'],
        "total": row['total'],
        "discount": row['discount'],
        "finalTotal": row['finalTotal'],
        "customerPaid": row['customerPaid'],
        "cashierReturn": row['cashierReturn'],
        "items": row['items'],
        "deletedAt": DateTime.now().toIso8601String(),
      });
      await db.delete('invoices', where: 'id = ?', whereArgs: [row['id']]);
    }
    return rows.length;
  }

  Future<List<Map<String, dynamic>>> getReturns({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    String where = "";
    List whereArgs = [];
    if (from != null && to != null) {
      where = "date BETWEEN ? AND ?";
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    }
    final res = await db.query(
      'returns',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return res.map((r) {
      return {
        "id": r['id'],
        "invoiceId": r['invoiceId'],
        "date": r['date'],
        "items": jsonDecode(r['items'] as String),
        "refundedAmount": r['refundedAmount'],
        "note": r['note'],
      };
    }).toList();
  }

  // ===== حذف نهائي سجل من المرتجعات
  Future<int> deleteReturn(int id) async {
    final db = await database;
    return await db.delete('returns', where: 'id = ?', whereArgs: [id]);
  }

  // Future<List<Map<String, dynamic>>> getInvoices({
  //   DateTime? from,
  //   DateTime? to,
  // }) async {
  //   final db = await database;
  //   String where = "";
  //   List whereArgs = [];

  //   if (from != null && to != null) {
  //     where = "date BETWEEN ? AND ?";
  //     whereArgs = [from.toIso8601String(), to.toIso8601String()];
  //   }

  //   final res = await db.query(
  //     "invoices",
  //     where: where.isNotEmpty ? where : null,
  //     whereArgs: whereArgs,
  //     orderBy: "date DESC",
  //   );

  //   return res.map((row) {
  //     return {
  //       "id": row["id"],
  //       "date": row["date"],
  //       "total": row["total"],
  //       "discount": row["discount"],
  //       "finalTotal": row["finalTotal"],
  //       "customerPaid": row["customerPaid"] ?? 0, // ✅
  //       "cashierReturn": row["cashierReturn"] ?? 0, // ✅
  //       "items": jsonDecode(row["items"] as String),
  //     };
  //   }).toList();
  // }

  // Future<int> deleteInvoicesBefore(DateTime date) async {
  //   final db = await database;
  //   return await db.delete(
  //     'invoices',
  //     where: 'date < ?',
  //     whereArgs: [date.toIso8601String()],
  //   );
  // }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> softDeleteInvoice(int id) async {
    final db = await database;
    return await db.update(
      'invoices',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> getSetting(String key) async {
    final dbClient = await database;
    final result = await dbClient.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isNotEmpty) return result.first['label'] as String?;
    return null;
  }

  // داخل DBHelperAdmin
  Future<Product?> getProductByName(String name) async {
    final dbClient = await database; // قاعدة البيانات
    final result = await dbClient.query(
      'products',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null;
  }

  Future<void> setSetting(String key, String label, [int? days]) async {
    final dbClient = await database;
    await dbClient.insert('settings', {
      'key': key,
      'label': label,
      'days': days ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertProduct(Product p) async {
    final db = await database;
    return await db.insert('products', p.toMap());
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'id DESC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<int> updateProduct(Product p) async {
    final db = await database;
    return await db.update(
      'products',
      p.toMap(),
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<Product?> getProduct(String input, {bool byBarcode = true}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (byBarcode) {
      maps = await db.query(
        'products',
        where: 'TRIM(barcode) = ?',
        whereArgs: [input.trim()],
        limit: 1,
      );
    } else {
      maps = await db.query(
        'products',
        where: 'LOWER(TRIM(name)) LIKE ?',
        whereArgs: ['%${input.trim().toLowerCase()}%'],
        limit: 1,
      );
    }

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  // حذف كل المرتجعات
  Future<void> deleteAllReturns() async {
    final dbClient = await database;
    await dbClient.delete('returns');
  }

  Future<void> updateDeleteAfterForAllReturns(String deleteAfter) async {
    final dbClient = await database;
    await dbClient.update('returns', {'deleteAfter': deleteAfter});
  }

  Future<void> deleteReturnsBefore(String dateTime) async {
    final dbClient = await database;
    await dbClient.delete(
      'returns',
      where: 'deleteAfter <= ?',
      whereArgs: [dateTime],
    );
  }

  // داخل DBHelperAdmin

  // حفظ سياسة الحذف (all / day / week / month / 2months)
  Future<void> updateDeletePolicy(String option) async {
    final dbClient = await database;
    await dbClient.insert('settings', {
      'key': 'deletePolicy',
      'label': option,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // قراءة سياسة الحذف المخزنة
  Future<String?> getDeletePolicy() async {
    final dbClient = await database;
    final result = await dbClient.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['deletePolicy'],
      limit: 1,
    );
    if (result.isNotEmpty) return result.first['label'] as String?;
    return null;
  }

  // =================== حذف المرتجعات حسب السياسة ===================
  Future<void> applyDeletePolicy() async {
    final dbClient = await database;
    final policy = await getDeletePolicy();

    if (policy == null || policy == "all") {
      // حذف كل المرتجعات
      await deleteAllReturns();
      return;
    }

    // تحديد الفترة بناءً على الخيار
    int days = 0;
    switch (policy) {
      case "day":
        days = 1;
        break;
      case "week":
        days = 7;
        break;
      case "month":
        days = 30;
        break;
      case "2months":
        days = 60;
        break;
      default:
        days = 0;
    }

    if (days > 0) {
      final now = DateTime.now();
      final threshold = now.subtract(Duration(days: days)).toIso8601String();
      await deleteReturnsBefore(threshold);
    }
  }

  Future<int> insertReturn(Map<String, dynamic> ret) async {
    final db = await database;

    // تحديد deleteAfter بناءً على السياسة الحالية
    final policy = await getDeletePolicy();
    DateTime? deleteAfterDate;

    switch (policy) {
      case "day":
        deleteAfterDate = DateTime.now().add(Duration(days: 1));
        break;
      case "week":
        deleteAfterDate = DateTime.now().add(Duration(days: 7));
        break;
      case "month":
        deleteAfterDate = DateTime.now().add(Duration(days: 30));
        break;
      case "2months":
        deleteAfterDate = DateTime.now().add(Duration(days: 60));
        break;
      case "all":
      default:
        deleteAfterDate = null; // حذف يدوي أو عند اختيار "all"
    }

    return await db.insert('returns', {
      "invoiceId": ret['invoiceId'],
      "date": ret['date'] ?? DateTime.now().toIso8601String(),
      "items": jsonEncode(ret['items']),
      "refundedAmount": ret['refundedAmount'] ?? 0,
      "note": ret['note'] ?? '',
      "isDeleted": 0,
      "deleteAfter": deleteAfterDate?.toIso8601String(),
    });
  }

  Future<void> deleteAllDeletedInvoices() async {
    final dbClient = await database;
    // أولًا، ممكن تنقلها للأرشيف قبل الحذف إذا تحب
    final deletedInvoices = await getDeletedInvoices();
    for (var inv in deletedInvoices) {
      await archiveInvoice(inv['id'] as int);
    }
    // ثم حذفها من جدول الفواتير
    await dbClient.delete('invoices', where: 'isDeleted = ?', whereArgs: [1]);
  }

  // // حفظ إعداد الحذف التلقائي
  Future<void> setDeleteInvoicesOption(String option) async {
    final dbClient = await database;
    await dbClient.insert('settings', {
      'key': 'delete_invoices',
      'label': option, // بدل 'value'
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // الحصول على إعداد الحذف التلقائي
  Future<String?> getDeleteInvoicesOption() async {
    final dbClient = await database;
    final res = await dbClient.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['delete_invoices'],
    );
    if (res.isNotEmpty) return res.first['label'] as String?; // بدل 'value'
    return null;
  }

  Future<void> deleteAllProducts() async {
    final dbClient = await database;
    await dbClient.delete('products');
  }
}
