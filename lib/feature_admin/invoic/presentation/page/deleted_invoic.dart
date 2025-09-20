import 'package:flutter/material.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';

class DeletedInvoicesPage extends StatefulWidget {
  @override
  _DeletedInvoicesPageState createState() => _DeletedInvoicesPageState();
}

class _DeletedInvoicesPageState extends State<DeletedInvoicesPage> {
  final DBHelperAdmin db = DBHelperAdmin();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = db.getDeletedInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🗂️ الفواتير المحذوفة"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true); // ✅ يرجع true
          },
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (!s.hasData || s.data!.isEmpty)
            return Center(child: Text("لا توجد فواتير محذوفة"));
          final list = s.data!;
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final inv = list[i];
              return ListTile(
                title: Text("فاتورة #${inv['id']} - ${inv['date']}"),
                subtitle: Text("المبلغ: ${inv['finalTotal']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.restore, color: Colors.green),
                      onPressed: () async {
                        await db.database.then(
                          (d) => d.update(
                            'invoices',
                            {'isDeleted': 0},
                            where: 'id = ?',
                            whereArgs: [inv['id']],
                          ),
                        );
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("✅ تم استعادة الفاتورة")),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () async {
                        // نقل للأرشيف ثم حذف من invoices (archiveInvoice)
                        await db.archiveInvoice(inv['id'] as int);
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "🗑️ تم حذف الفاتورة نهائياً (نقلت للأرشيف)",
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  // ممكن تفتح تفاصيل لو حابب (مثل InvoiceDetailsPage)
                },
              );
            },
          );
        },
      ),
    );
  }
}
