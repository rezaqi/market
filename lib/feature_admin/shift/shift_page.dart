import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({Key? key}) : super(key: key);

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  final db = DBHelperAdmin();
  List<Map<String, dynamic>> shifts = [];
  Duration? autoDeleteDuration;
  String? autoDeleteLabel;

  @override
  void initState() {
    super.initState();
    loadSettings(); // 🆕 تحميل المدة المحفوظة
    loadShifts();
  }

  Future<void> loadSettings() async {
    final setting = await db.getAutoDeleteSetting();
    if (setting != null) {
      setState(() {
        autoDeleteLabel = setting["label"];
        autoDeleteDuration = Duration(days: setting["days"]);
      });
    }
  }

  Future<void> loadShifts() async {
    final database = await db.database;

    if (autoDeleteDuration != null && autoDeleteDuration != Duration.zero) {
      final cutoffDate = DateTime.now().subtract(autoDeleteDuration!);
      await database.delete(
        "shifts",
        where: "endTime IS NOT NULL AND datetime(endTime) < ?",
        whereArgs: [DateFormat("yyyy-MM-dd HH:mm:ss").format(cutoffDate)],
      );
    }

    final data = await database.query("shifts", orderBy: "id DESC");

    setState(() {
      shifts = data;
    });
  }

  String formatDate(String? date) {
    if (date == null) return "-";
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    return DateFormat("yyyy/MM/dd HH:mm").format(d);
  }

  Future<void> closeShift(int id) async {
    final database = await db.database;
    final endTime = DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now());

    final rows = await database.update(
      "shifts",
      {"endTime": endTime},
      where: "id = ?",
      whereArgs: [id],
    );

    if (rows > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("✅ تم إغلاق الوردية بنجاح")));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ فشل في إغلاق الوردية")));
    }

    loadShifts();
  }

  Future<void> deleteShift(int id, bool isOpen) async {
    if (isOpen) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ لا يمكن حذف وردية مفتوحة")));
      return;
    }
    final database = await db.database;
    await database.delete("shifts", where: "id = ?", whereArgs: [id]);
    loadShifts();
  }

  Future<void> deleteAllShifts() async {
    final database = await db.database;
    await database.delete("shifts", where: "endTime IS NOT NULL");
    loadShifts();
  }

  void chooseAutoDeleteDuration() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("⏳ اختر مدة الحذف التلقائي"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _durationOption("عدم الحذف مطلقًا", Duration.zero), // ✅ خيار جديد
              _durationOption("يوم", Duration(days: 1)),
              _durationOption("أسبوع", Duration(days: 7)),
              _durationOption("شهر", Duration(days: 30)),
              _durationOption("شهرين", Duration(days: 60)),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        autoDeleteDuration = result["duration"];
        autoDeleteLabel = result["label"];
      });

      // 🆕 حفظ المدة في قاعدة البيانات
      await db.saveAutoDeleteSetting(
        result["label"],
        result["duration"].inDays,
      );

      loadShifts();
    }
  }

  Widget _durationOption(String label, Duration duration) {
    return ListTile(
      title: Text(label),
      onTap: () =>
          Navigator.pop(context, {"label": label, "duration": duration}),
    );
  }

  String formatNumber(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("📊 قائمة الورديات"),
        actions: [
          InkWell(
            onTap: chooseAutoDeleteDuration,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    autoDeleteLabel == null
                        ? "تحديد الحذف التلقائى"
                        : "الحذف: $autoDeleteLabel",
                  ),
                  Icon(Icons.delete_forever),
                ],
              ),
            ),
          ),
          SizedBox(width: 10),
          InkWell(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("⚠️ تأكيد الحذف"),
                  content: Text("هل تريد حذف جميع الورديات المغلقة فقط؟"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("إلغاء"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text("نعم"),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                deleteAllShifts();
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [Text("حذف الكل"), Icon(Icons.delete_sweep)],
              ),
            ),
          ),
        ],
      ),
      body: shifts.isEmpty
          ? Center(child: Text("لا توجد ورديات بعد"))
          : ListView.builder(
              itemCount: shifts.length,
              itemBuilder: (context, index) {
                final shift = shifts[index];
                final isOpen = shift["endTime"] == null;

                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(
                      isOpen ? Icons.lock_open : Icons.lock,
                      color: isOpen ? Colors.green : Colors.red,
                    ),
                    // title: Text(
                    //   "👤 الكاشير: ${shift["cashierName"] ?? "غير معروف"}",
                    // ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🕒 البداية: ${formatDate(shift["startTime"])}",
                          style: TextStyle(fontSize: 18),
                        ),
                        Text(
                          "🕒 النهاية: ${formatDate(shift["endTime"])}",
                          style: TextStyle(fontSize: 18),
                        ),
                        Text(
                          "💰 المبيعات: ${formatNumber(shift["totalSales"] ?? 0)} جنيه",
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      tooltip: "حذف هذه الوردية",
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("⚠️ تأكيد الحذف"),
                            content: Text("هل تريد حذف هذه الوردية؟"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text("إلغاء"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text("نعم"),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          deleteShift(shift["id"], isOpen);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
