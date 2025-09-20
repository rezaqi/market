import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';

class InvoiceDetailsPage extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final DBHelperAdmin db = DBHelperAdmin();

  InvoiceDetailsPage({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final items = invoice["items"] as List<dynamic>;
    final customerPaid = invoice["customerPaid"] ?? 0;
    final cashierReturn = invoice["cashierReturn"] ?? 0;

    String formatNumber(num? value) {
      if (value == null) return "0";
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toStringAsFixed(2);
    }

    Future<void> _returnItems(BuildContext context, {bool all = false}) async {
      List<dynamic> newItems = [];

      if (all) {
        // ✅ إرجاع كل المنتجات للمخزن
        for (var item in items) {
          await db.increaseStock(item["id"], item["qty"]);
        }

        // ✅ سجل المرتجع (إرجاع كامل)
        await db.insertReturn({
          "invoiceId": invoice["id"],
          "date": DateTime.now().toIso8601String(),
          "items": jsonEncode(items),
          "refundedAmount": invoice["finalTotal"],
          "note": "إرجاع كامل",
        });

        // ✅ حذف الفاتورة
        await db.deleteInvoice(invoice["id"]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🗑️ تم حذف الفاتورة لأنها فارغة")),
        );
        Navigator.pop(context, true);
        return;
      }

      // ✅ اختيار منتجات معينة مع كميات
      final selected = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (_) {
          List<Map<String, dynamic>> selectedItems = [];

          return AlertDialog(
            title: Text("اختيار منتجات للمرتجع"),
            content: SingleChildScrollView(
              child: Column(
                children: items.map((item) {
                  int returnQty = 0;

                  return StatefulBuilder(
                    builder: (context, innerSet) {
                      void updateSelected() {
                        selectedItems.removeWhere((e) => e["id"] == item["id"]);
                        if (returnQty > 0) {
                          selectedItems.add({
                            "id": item["id"],
                            "name": item["name"],
                            "price": item["price"],
                            "qty": returnQty,
                          });
                        }
                      }

                      return ListTile(
                        title: Text("${item["name"]} - ${item["qty"]}x"),
                        subtitle: Row(
                          children: [
                            Text("ترجيع: "),
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                if (returnQty > 0) {
                                  innerSet(() {
                                    returnQty--;
                                    updateSelected();
                                  });
                                }
                              },
                            ),
                            Text("$returnQty"),
                            IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                if (returnQty < item["qty"]) {
                                  innerSet(() {
                                    returnQty++;
                                    updateSelected();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        trailing: returnQty > 0
                            ? Icon(Icons.check, color: Colors.green)
                            : null,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selectedItems),
                child: Text("تأكيد"),
              ),
            ],
          );
        },
      );

      if (selected == null || selected.isEmpty) return;

      // ✅ إرجاع الكميات المختارة للمخزن
      for (var item in selected) {
        await db.increaseStock(item["id"], item["qty"]);
      }

      // ✅ تحديث الفاتورة (طرح الكميات المرتجعة)
      for (var item in items) {
        final sel = selected.firstWhere(
          (e) => e["id"] == item["id"],
          orElse: () => {},
        );

        if (sel.isEmpty) {
          newItems.add(item);
        } else {
          final returnQty = sel["qty"];
          if (returnQty < item["qty"]) {
            newItems.add({
              "id": item["id"],
              "name": item["name"],
              "price": item["price"],
              "qty": item["qty"] - returnQty,
            });
          }
        }
      }

      // ✅ لو الفاتورة فاضية نحذفها
      if (newItems.isEmpty) {
        // سجل المرتجع كإرجاع جزئي لكن أدى لإلغاء كامل
        final refundedAmount = selected.fold(
          0.0,
          (sum, e) => sum + (e["price"] * e["qty"]),
        );

        await db.insertReturn({
          "invoiceId": invoice["id"],
          "date": DateTime.now().toIso8601String(),
          "items": jsonEncode(selected),
          "refundedAmount": refundedAmount,
          "note": "إرجاع جزئي (ألغى الفاتورة)",
        });

        await db.deleteInvoice(invoice["id"]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🗑️ تم حذف الفاتورة لأنها فارغة")),
        );
        Navigator.pop(context, true);
        return;
      }

      // ✅ لسه فيها منتجات → نعدل الفاتورة
      double newTotal = newItems.fold(
        0,
        (sum, item) => sum + (item["price"] * item["qty"]),
      );

      final discount = invoice["discount"] ?? 0.0;
      final finalTotal = newTotal - discount;

      await db.updateInvoice(invoice["id"], {
        "items": newItems,
        "total": newTotal,
        "finalTotal": finalTotal,
        "customerPaid": customerPaid,
        "cashierReturn": customerPaid == -1 ? 0 : (customerPaid - finalTotal),
      });

      // ✅ سجل المرتجع (جزئي)
      final refundedAmount = selected.fold(
        0.0,
        (sum, e) => sum + (e["price"] * e["qty"]),
      );

      await db.insertReturn({
        "invoiceId": invoice["id"],
        "date": DateTime.now().toIso8601String(),
        "items": selected, // ❌ من غير jsonEncode
        "refundedAmount": refundedAmount,
        "note": "إرجاع جزئي",
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("✅ تم تعديل الفاتورة بالمرتجع")));
      Navigator.pop(context, true);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("تفاصيل فاتورة "),
        actions: [
          IconButton(
            icon: Icon(Icons.undo),
            tooltip: "إرجاع الكل",
            onPressed: () => _returnItems(context, all: true),
          ),
          IconButton(
            icon: Icon(Icons.assignment_return),
            tooltip: "إرجاع منتجات محددة",
            onPressed: () => _returnItems(context, all: false),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: "حذف الفاتورة",
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text("تأكيد الحذف"),
                  content: Text(
                    "هل أنت متأكد من حذف الفاتورة #${invoice["id"]}?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("إلغاء"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text("حذف"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await db.softDeleteInvoice(invoice["id"] as int);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ تم حذف الفاتورة بنجاح")),
                );
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: Text(
                    "📅 التاريخ: ${invoice["date"]}",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: Text(
                    "💰 الإجمالي: ${formatNumber(invoice["total"])}",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: Text(
                    "🎯 الخصم: ${formatNumber(invoice["discount"])}",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    "✅ الصافي: ${formatNumber(invoice["finalTotal"])}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: Text(
                    "💵 المدفوع: ${customerPaid == -1 ? formatNumber((invoice["total"] ?? 0) - (invoice["discount"] ?? 0)) : formatNumber(customerPaid)}",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                if (customerPaid != -1)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      "↩️ الباقي: ${formatNumber(cashierReturn)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
              ],
            ),
            Divider(thickness: 1.5, height: 16),
            Text(
              "🛒 المنتجات:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final qty = item["qty"] ?? 0;
                  final price = item["price"] ?? 0;
                  final subtotal = (qty * price);
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    margin: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item["name"].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "x${qty} : السعر ${formatNumber(price)}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Spacer(),
                        Text(
                          formatNumber(subtotal),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
