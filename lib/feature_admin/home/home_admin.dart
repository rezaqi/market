import 'dart:async';

import 'package:flutter/material.dart';
import 'package:market/core/class/app_color.dart';
import 'package:market/core/class/routs_name.dart';
import 'package:market/feature_admin/add_product/add_product.dart';
import 'package:market/feature_admin/home/data/model/product_model.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';
import 'package:market/feature_admin/home/func/show_detils.dart';
import 'package:market/feature_admin/invoic/presentation/page/invoice_page.dart';
import 'package:market/feature_seller/presentation/page/seller_home.dart';

class ProductListPage extends StatefulWidget {
  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final DBHelperAdmin db = DBHelperAdmin();
  late Future<List<Product>> _productsFuture;

  bool isProcessingShift = false; // ✅ يمنع الضغط السريع

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocus = FocusNode();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  void _refreshProducts() {
    _productsFuture = db.getProducts().then((list) {
      _allProducts = list;
      _filteredProducts = list;
      return list;
    });
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts; // لو مفيش بحث رجع الكل
      } else {
        _filteredProducts = _allProducts.where((p) {
          return p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.barcode.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _openAddEdit([Product? product]) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditProductPage(product: product)),
    );
    if (result == true) {
      setState(() {
        _refreshProducts();
      });
    }
  }

  void _confirmDelete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل تريد حذف المنتج "${p.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await db.deleteProduct(p.id!);
      setState(() {
        _refreshProducts();
      });
    }
  }

  Widget _buildRow(Product p) {
    Color? cardColor;
    if (p.expire != null) {
      final now = DateTime.now();
      final diff = p.expire!.difference(now).inDays;
      if (diff < 0)
        cardColor = Colors.red[100];
      else if (diff <= 7)
        cardColor = Colors.orange[100];
    }

    return InkWell(
      onTap: () => showDetails(p, context),
      child: Card(
        color: cardColor,
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// النصوص
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'السعر: ${p.price % 1 == 0 ? p.price.toInt() : p.price.toStringAsFixed(2)}\n'
                      'الرصيد الموجود فى المخزن حاليا: ${p.quantity}\n'
                      'باركود: ${p.barcode}\n'
                      'تاريخ الانتهاء: ${p.expire != null ? p.expire!.toLocal().toString().split(' ')[0] : "-"}',

                      style: TextStyle(fontSize: 25),
                    ),
                  ],
                ),
              ),

              /// الأكشنات
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      Text("تعديل", style: TextStyle(fontSize: 12)),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _openAddEdit(p),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text("حذف", style: TextStyle(fontSize: 12)),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _confirmDelete(p),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<double>(
          future: db.getTotalOriginalStockValue(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text("لوحة تحكم الماركت ...");
            }
            if (snapshot.hasError) {
              return Text("خطأ في الحساب");
            }

            double total = snapshot.data ?? 0.0;

            // ✅ التنسيق حسب النوع
            String formattedValue = (total % 1 == 0)
                ? total.toInt().toString()
                : total.toStringAsFixed(2);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "لوحة تحكم الماركت",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  "إجمالي السعر الأصلي: $formattedValue ج.م",
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              ],
            );
          },
        ),
        centerTitle: false,

        actions: [
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CashierPage()),
              );

              // لو رجعت بحاجة → اعمل تحديث
              if (result == true) {
                setState(() {
                  // استدعاء الفانكشن اللي بتجيب الداتا من جديد
                  _refreshProducts();
                });
              }
            },

            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 144, 142, 142),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "الكاشير",
                style: TextStyle(fontSize: 25, color: AppColors.white),
              ),
            ),
          ),

          SizedBox(width: 10),
          InkWell(
            onTap: () {
              Navigator.pushNamed(context, AppRouts.changePass);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 144, 142, 142),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "اعدادات الخصوصية",
                style: TextStyle(fontSize: 25, color: AppColors.white),
              ),
            ),
          ),
          SizedBox(width: 10),

          Container(
            decoration: BoxDecoration(
              border: Border.all(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                FutureBuilder<Map<String, dynamic>?>(
                  future: db.getCurrentShift(),
                  builder: (context, snapshot) {
                    final current = snapshot.data;
                    final isOpen = current != null;

                    return TextButton.icon(
                      icon: Icon(
                        isOpen ? Icons.lock_open : Icons.lock,
                        color: isOpen ? Colors.green : Colors.red,
                      ),
                      label: Text(
                        isOpen ? "إغلاق الوردية" : "فتح وردية",
                        style: TextStyle(color: Colors.black),
                      ),
                      onPressed: isProcessingShift
                          ? null // ❌ يعطل الزر لو فيه عملية شغالة
                          : () async {
                              setState(() => isProcessingShift = true);

                              try {
                                if (isOpen) {
                                  await db.closeShift(current["id"]);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("✅ تم إغلاق الوردية"),
                                    ),
                                  );
                                } else {
                                  await db.openShift();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("✅ تم فتح وردية جديدة"),
                                    ),
                                  );
                                }
                                setState(() {});
                              } finally {
                                // ✅ نرجع السماح بالضغط بعد ما تخلص العملية
                                setState(() => isProcessingShift = false);
                              }
                            },
                    );
                  },
                ),
                InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, AppRouts.shiftsPage);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 144, 142, 142),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "الورديات",
                      style: TextStyle(fontSize: 25, color: AppColors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 10),
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InvoicesPage()),
              );
              // لو رجعت بحاجة → اعمل تحديث
              if (result == true) {
                setState(() {
                  // استدعاء الفانكشن اللي بتجيب الداتا من جديد
                  _refreshProducts();
                });
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 144, 142, 142),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "الفواتير",
                style: TextStyle(fontSize: 25, color: AppColors.white),
              ),
            ),
          ),
          SizedBox(width: 5),
          Container(
            padding: EdgeInsets.all(0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(),
            ),
            child: Text(
              textAlign: TextAlign.center,
              "للتواصل مع مهندس السيستم\n01212577699",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          /// ✅ البحث
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              focusNode: searchFocus,
              decoration: InputDecoration(
                labelText: "ابحث بالاسم أو الباركود",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterProducts,
              onSubmitted: _filterProducts, // يدعم الماسح
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator());
                if (!snap.hasData || snap.data!.isEmpty)
                  return Center(child: Text('لا يوجد منتجات بعد'));

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _refreshProducts());
                    await _productsFuture;
                  },
                  child: ListView.builder(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, i) =>
                        _buildRow(_filteredProducts[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEdit(),
        label: Text('أضف منتج'),
        icon: Icon(Icons.add_box),
      ),
    );
  }
}
