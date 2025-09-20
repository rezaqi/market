import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';

class ReturnsPage extends StatefulWidget {
  @override
  _ReturnsPageState createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  final DBHelperAdmin db = DBHelperAdmin();
  late Future<List<Map<String, dynamic>>> _future;
  // 🟢 متغير لتخزين الحالة الحالية
  String _deleteStatus = "لا يوجد حذف";

  @override
  void initState() {
    super.initState();
    _load();
    _loadDeleteStatus();
  }

  void _load() {
    setState(() {
      _future = db.getReturns();
    });
  }

  String formatNumber(num? value) {
    if (value == null) return "0";
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Future<void> _loadDeleteStatus() async {
    final option = await db.getDeletePolicy(); // اقرأ الخيار المحفوظ

    if (option == null) {
      setState(() {
        _deleteStatus = "لا يوجد حذف";
      });
      return;
    }

    setState(() {
      _deleteStatus = _getStatusText(option); // حول الخيار لنص ظاهر
    });
  }

  String _getStatusText(String? option) {
    switch (option) {
      case "all":
        return "تم اختيار: حذف الكل";
      case "day":
        return "تم اختيار: حذف يومي";
      case "week":
        return "تم اختيار: حذف أسبوعي";
      case "month":
        return "تم اختيار: حذف شهري";
      case "2months":
        return "تم اختيار: حذف شهرين";
      default:
        return "لا يوجد حذف";
    }
  }

  void _showDeleteOptions() async {
    final option = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text("اختر نوع الحذف"),
        children: [
          SimpleDialogOption(
            child: Text("❌ عدم الحذف"),
            onPressed: () => Navigator.pop(context, "none"),
          ),

          // SimpleDialogOption(
          //   child: Text("🗑️ حذف الكل"),
          //   onPressed: () => Navigator.pop(context, "all"),
          // ),
          SimpleDialogOption(
            child: Text("🗓️ حذف يومي"),
            onPressed: () => Navigator.pop(context, "day"),
          ),
          SimpleDialogOption(
            child: Text("🗓️ حذف أسبوعي"),
            onPressed: () => Navigator.pop(context, "week"),
          ),
          SimpleDialogOption(
            child: Text("🗓️ حذف شهري"),
            onPressed: () => Navigator.pop(context, "month"),
          ),
          SimpleDialogOption(
            child: Text("🗓️ حذف شهرين"),
            onPressed: () => Navigator.pop(context, "2months"),
          ),
        ],
      ),
    );

    if (option == null || option == "none") return;

    DateTime now = DateTime.now();
    DateTime? deleteAfter;

    switch (option) {
      // case "all":
      //   await db.deleteAllReturns(); // حذف كل المرتجعات نهائياً
      //   _deleteStatus = "تم اختيار: حذف الكل";
      //   break;
      case "day":
        deleteAfter = now.add(Duration(days: 1));
        _deleteStatus = "تم اختيار: حذف يومي";
        break;
      case "week":
        deleteAfter = now.add(Duration(days: 7));
        _deleteStatus = "تم اختيار: حذف أسبوعي";
        break;
      case "month":
        deleteAfter = DateTime(now.year, now.month + 1, now.day);
        _deleteStatus = "تم اختيار: حذف شهري";
        break;
      case "2months":
        deleteAfter = DateTime(now.year, now.month + 2, now.day);
        _deleteStatus = "تم اختيار: حذف شهرين";
        break;
    }

    setState(() {
      _deleteStatus = _deleteStatus;
    }); // لتحديث AppBar

    await db.updateDeletePolicy(option);

    // 🟢 حفظ deleteAfter فقط إذا ليس "all"
    if (deleteAfter != null) {
      await db.updateDeleteAfterForAllReturns(deleteAfter.toIso8601String());
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ تم تعيين سياسة الحذف")));
  }

  // دالة تلقائية لتفريغ المرتجعات عند مرور الوقت
  Future<void> autoDeleteReturns() async {
    DateTime now = DateTime.now();
    await db.deleteReturnsBefore(now.toIso8601String());
  }

  void _showReturnItems(Map<String, dynamic> r) {
    final items = (jsonDecode(r['items']) as List<dynamic>);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("تفاصيل المرتجع #${r['id']}"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final total = (item['price'] ?? 0) * (item['qty'] ?? 0);
              return ListTile(
                title: Text(item['name'] ?? ''),
                subtitle: Text("سعر الوحدة: ${formatNumber(item['price'])}"),
                trailing: Text(
                  "الكمية: ${item['qty']} - المجموع: ${formatNumber(total)}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text("إغلاق"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReturns(DateTime? cutoff) async {
    if (cutoff == null) {
      await db.deleteAllReturns();
    } else {
      await db.deleteReturnsBefore(cutoff.toIso8601String());
    }
    _load();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ تم حذف السجلات المحددة")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("↩️ المرتجعات "), // 🟢 هنا يظهر الحالة
        actions: [
          Text("($_deleteStatus)"),
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: "حذف الكل",
            onPressed: () async {
              await db.deleteAllReturns(); // حذف كل المرتجعات
              _load(); // إعادة تحميل البيانات بعد الحذف
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("✅ تم حذف كل المرتجعات")));
            },
          ),

          IconButton(
            icon: Icon(Icons.auto_delete),
            tooltip: "خيارات الحذف",
            onPressed: _showDeleteOptions,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (!s.hasData || s.data!.isEmpty)
            return Center(child: Text("لا توجد مرتجعات"));

          final list = s.data!;
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final r = list[i];

              final rawItems = r['items'];
              final List<dynamic> items;

              if (rawItems is String) {
                items = jsonDecode(rawItems) as List<dynamic>;
              } else if (rawItems is List) {
                items = rawItems;
              } else {
                items = [];
              }

              return Card(
                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: ExpansionTile(
                  title: Text("مرتجع ", style: TextStyle(fontSize: 18)),
                  subtitle: Text(
                    "قيمة المرتجع: ${formatNumber(r['refundedAmount'])} - ${r['date']}",
                    style: TextStyle(fontSize: 18),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () async {
                      await db.deleteReturn(r['id'] as int);
                      _load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("✅ تم حذف سجل المرتجع نهائياً")),
                      );
                    },
                  ),
                  children: items.map((item) {
                    final total = (item['price'] ?? 0) * (item['qty'] ?? 0);
                    return ListTile(
                      title: Text(
                        item['name'] ?? '',
                        style: TextStyle(fontSize: 18),
                      ),
                      subtitle: Text(
                        "سعر الوحدة: ${formatNumber(item['price'])}",
                        style: TextStyle(fontSize: 18),
                      ),
                      trailing: Text(
                        "الكمية: ${item['qty']} - المجموع: ${formatNumber(total)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
