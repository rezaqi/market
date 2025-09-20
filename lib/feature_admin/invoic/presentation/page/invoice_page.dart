import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';
import 'package:market/feature_admin/invoic/presentation/page/deleted_invoic.dart';
import 'package:market/feature_admin/invoic/presentation/page/invoic_details.dart';
import 'package:market/feature_admin/invoic/presentation/page/return_page.dart';

class InvoicesPage extends StatefulWidget {
  @override
  _InvoicesPageState createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final DBHelperAdmin db = DBHelperAdmin();
  late Future<List<Map<String, dynamic>>> _invoicesFuture;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = "";
  DateTime? _fromDate;
  DateTime? _toDate;
  double _monthlyTotal = 0.0;
  double _filteredTotal = 0.0;
  String _autoDelete = "never";

  String formatNumber(num? value) {
    if (value == null) return "0";
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _loadAutoDeleteSetting();
    _loadInvoices();
    _calculateMonthlyTotal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAutoDeleteSetting() async {
    final setting = await db.getSetting("invoiceAutoDelete");
    setState(() {
      _autoDelete = setting ?? "never";
    });
    _applyAutoDelete();
  }

  Future<void> _saveAutoDeleteSetting(String value) async {
    await db.setSetting("invoiceAutoDelete", value);
    setState(() {
      _autoDelete = value;
    });
    _applyAutoDelete();
  }

  Future<void> _applyAutoDelete() async {
    DateTime now = DateTime.now();
    DateTime? limit;

    switch (_autoDelete) {
      case "daily":
        limit = now.subtract(Duration(days: 1));
        break;
      case "weekly":
        limit = now.subtract(Duration(days: 7));
        break;
      case "monthly":
        limit = DateTime(now.year, now.month - 1, now.day);
        break;
      case "twoMonths":
        limit = DateTime(now.year, now.month - 2, now.day);
        break;
      case "never":
      default:
        return;
    }

    await db.deleteInvoicesBefore(limit);
    _refreshAll();
  }

  void _loadInvoices() {
    setState(() {
      _invoicesFuture = db.getInvoices(from: _fromDate, to: _toDate);
    });
    _calculateFilteredTotal();
  }

  void _calculateMonthlyTotal() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final total = await db.getInvoicesTotal(from: startOfMonth, to: now);
    setState(() {
      _monthlyTotal = total;
    });
  }

  void _calculateFilteredTotal() async {
    if (_fromDate != null && _toDate != null) {
      final total = await db.getInvoicesTotal(from: _fromDate!, to: _toDate!);
      setState(() {
        _filteredTotal = total;
      });
    } else {
      setState(() {
        _filteredTotal = 0.0;
      });
    }
  }

  void _refreshAll() {
    _loadInvoices();
    _calculateMonthlyTotal();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      _loadInvoices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () {
            Navigator.pop(context, true);
          },
          child: Icon(Icons.arrow_back),
        ),
        title: Text("📑 الفواتير"),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            tooltip: "الفواتير المحذوفة",
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DeletedInvoicesPage()),
              );
              if (result == true) _refreshAll();
            },
          ),
          IconButton(
            icon: Icon(Icons.assignment_return),
            tooltip: "المرتجعات",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReturnsPage()),
            ),
          ),
          DropdownButton<String>(
            value: _autoDelete,
            items: const [
              DropdownMenuItem(value: "never", child: Text("❌ عدم الحذف")),
              DropdownMenuItem(value: "daily", child: Text("🗑️ حذف يومي")),
              DropdownMenuItem(value: "weekly", child: Text("🗑️ حذف أسبوعي")),
              DropdownMenuItem(value: "monthly", child: Text("🗑️ حذف شهري")),
              DropdownMenuItem(
                value: "twoMonths",
                child: Text("🗑️ حذف كل شهرين"),
              ),
            ],
            onChanged: (value) {
              if (value != null) _saveAutoDeleteSetting(value);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: EdgeInsets.all(12),
            color: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fromDate != null && _toDate != null
                        ? "إجمالي الفواتير في هذه المدة"
                        : "إجمالي مبيعات الشهر",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    _fromDate != null && _toDate != null
                        ? "${formatNumber(_filteredTotal)} ج.م"
                        : "${formatNumber(_monthlyTotal)} ج.م",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _pickDateRange,
              icon: Icon(Icons.date_range),
              label: Text(
                _fromDate != null && _toDate != null
                    ? "من ${DateFormat('yyyy-MM-dd').format(_fromDate!)} إلى ${DateFormat('yyyy-MM-dd').format(_toDate!)}"
                    : "اختر فترة زمنية",
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "ابحث بالاسم أو الباركود",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) async {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });

                if (_searchQuery.isNotEmpty) {
                  final result = await db.searchInvoicesByNameOrBarcode(
                    _searchQuery,
                  );
                  setState(() {
                    _invoicesFuture = Future.value(result);
                  });
                } else {
                  _loadInvoices();
                }
              },
              onSubmitted: (value) {
                _searchFocus.requestFocus();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _invoicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      "🚫 لا توجد فواتير",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                final invoices = snapshot.data!;
                final filtered = _searchQuery.isEmpty
                    ? invoices
                    : invoices.where((inv) {
                        final items = inv["items"] as List<dynamic>? ?? [];
                        return items.any((item) {
                          final name = (item["name"]?.toString() ?? "")
                              .toLowerCase();
                          final barcode = (item["barcode"]?.toString() ?? "")
                              .toLowerCase();
                          return name.contains(_searchQuery) ||
                              barcode.contains(_searchQuery);
                        });
                      }).toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final invoice = filtered[i];
                    final id = invoice["id"];
                    final date = invoice["date"];
                    final total = invoice["total"];
                    final discount = invoice["discount"] ?? 0;
                    final finalTotal = invoice["finalTotal"];
                    final items = (invoice["items"] as List<dynamic>? ?? []);
                    final List<String> matchedNames = _searchQuery.isEmpty
                        ? const <String>[]
                        : items
                              .where((it) {
                                final name =
                                    (it["name"]?.toString().toLowerCase() ??
                                    "");
                                final barcode =
                                    (it["barcode"]?.toString().toLowerCase() ??
                                    "");
                                return name.contains(_searchQuery) ||
                                    barcode.contains(_searchQuery);
                              })
                              .map<String>((it) => it["name"].toString())
                              .toList();

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "📅 التاريخ: $date",
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              "💰 الإجمالي: ${formatNumber(total)}",
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              "🎯 الخصم: ${formatNumber(discount)}",
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              "✅ بعد الخصم: ${formatNumber(finalTotal)}",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty &&
                                matchedNames.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "المنتجات المطابقة: ${matchedNames.join(", ")}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blueGrey[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await db.softDeleteInvoice(id);
                                _refreshAll();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("🗑️ تم حذف الفاتورة"),
                                  ),
                                );
                              },
                            ),
                            Icon(Icons.arrow_forward_ios, color: Colors.grey),
                          ],
                        ),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InvoiceDetailsPage(invoice: invoice),
                            ),
                          );
                          if (result == true) _refreshAll();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
