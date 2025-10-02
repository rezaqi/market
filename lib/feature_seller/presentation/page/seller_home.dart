import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:market/core/class/app_color.dart';
import 'package:market/feature_admin/home/data/model/product_model.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';

class CashierPage extends StatefulWidget {
  @override
  _CashierPageState createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  final DBHelperAdmin db = DBHelperAdmin();
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  // Controllers
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController customerPaidController = TextEditingController();
  final TextEditingController cashierReturnController = TextEditingController();

  // FocusNodes
  final FocusNode barcodeFocusNode = FocusNode();

  final FocusNode returnCashFocus = FocusNode();
  final FocusNode discountFocusNode = FocusNode();
  final FocusNode customerPaidFocusNode = FocusNode();
  final List<FocusNode> qtyFocusNodes = [];

  Timer? _debounce;
  List<Map<String, dynamic>> cart = [];

  @override
  void dispose() {
    _debounce?.cancel();
    barcodeController.dispose();
    discountController.dispose();
    customerPaidController.dispose();
    cashierReturnController.dispose();
    qtyFocusNodes.forEach((fn) => fn.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(barcodeFocusNode);
    });

    customerPaidController.addListener(() {
      double value = double.tryParse(customerPaidController.text.trim()) ?? 0.0;
      if (value < 0) {
        customerPaidController.text = "0";
        customerPaidController.selection = TextSelection.fromPosition(
          TextPosition(offset: customerPaidController.text.length),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ المبلغ المدفوع لا يمكن أن يكون بالسالب")),
        );
        value = 0;
      }
      setState(() {
        cashierReturnController.text = formatNumber(cashierReturn);
      });
    });

    discountController.addListener(() {
      double value = double.tryParse(discountController.text.trim()) ?? 0.0;
      if (value < 0) {
        discountController.text = "0";
        discountController.selection = TextSelection.fromPosition(
          TextPosition(offset: discountController.text.length),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ الخصم لا يمكن أن يكون بالسالب")),
        );
        value = 0;
      }
      setState(() {
        cashierReturnController.text = formatNumber(cashierReturn);
      });
      if (value > totalPrice) {
        final cappedValue = totalPrice.toDouble();
        discountController.text = formatNumber(cappedValue);
        discountController.selection = TextSelection.fromPosition(
          TextPosition(offset: discountController.text.length),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ الخصم لا يمكن أن يتجاوز المبلغ الإجمالي")),
        );
        value = cappedValue;
      }
      setState(() {
        cashierReturnController.text = formatNumber(cashierReturn);
      });
    });
  }

  Future<void> _addProductByBarcode(String input) async {
    input = input.trim(); // يشيل أي مسافات أو new lines
    if (input.isEmpty) return;

    final now = DateTime.now();

    // 🟢 تجاهل لو نفس الكود اتكرر بسرعة (مثلاً في أقل من ثانية)
    if (_lastScannedCode == input &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < Duration(seconds: 1)) {
      return;
    }

    _lastScannedCode = input;
    _lastScanTime = now;

    final product = await db.getProduct(input, byBarcode: true);
    if (product == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⚠️ المنتج غير موجود")));
      _resetBarcodeField();
      return;
    }

    if (_isProductExpired(product)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⚠️ المنتج منتهي الصلاحية")));
      _resetBarcodeField();
      return;
    }

    final existing = cart.indexWhere(
      (item) => item['product'].id == product.id,
    );

    if (existing != -1) {
      bool reachedLimit = false;
      setState(() {
        if (cart[existing]['qty'] < product.quantity) {
          cart[existing]['qty'] += 1;
          cart[existing]['controller'].text = cart[existing]['qty'].toString();
        } else {
          reachedLimit = true;
        }
        // انقل العنصر (حتى لو كان موجود مسبقاً) إلى أعلى القائمة
        final item = cart.removeAt(existing);
        cart.insert(0, item);
      });
      if (reachedLimit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ لا يمكن تجاوز الكمية المتاحة (${product.quantity})",
            ),
          ),
        );
      }
    } else {
      if (product.quantity > 0) {
        final fn = FocusNode();
        qtyFocusNodes.add(fn);
        setState(() {
          cart.insert(0, {
            'product': product,
            'qty': 1,
            'controller': TextEditingController(text: "1"),
            'focusNode': fn,
          });
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ المنتج غير متوفر في المخزن")));
      }
    }

    setState(() {
      cashierReturnController.text = formatNumber(cashierReturn);
    });
    _resetBarcodeField();
  }

  void _resetBarcodeField() {
    barcodeController.clear();
    FocusScope.of(context).requestFocus(barcodeFocusNode);
  }

  bool _isProductExpired(Product p) {
    if (p.expire == null) return false;
    final now = DateTime.now();
    return p.expire!.isBefore(now);
  }

  num get totalPrice => cart.fold(0, (sum, item) {
    final p = item['product'] as Product;
    final qty = item['qty'] as int;
    final total = p.price * qty;

    // لو الناتج عدد صحيح، ارجعه int
    if (total == total.roundToDouble()) return sum + total.toInt();
    return sum + total;
  });

  String formatNumber(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  double get discount => double.tryParse(discountController.text.trim()) ?? 0.0;

  num get finalTotal {
    final total = totalPrice - discount;
    return total < 0 ? 0 : total;
  }

  double get customerPaid =>
      double.tryParse(customerPaidController.text.trim()) ?? -1;

  num get cashierReturn {
    final returnAmount = customerPaid - finalTotal;
    return returnAmount < 0 ? 0 : returnAmount;
  }

  Future<void> _completeSale() async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ لا توجد منتجات")));
      return;
    }
    if (discount > totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ الخصم أكبر من المبلغ الإجمالي")),
      );
      return;
    }
    if (discount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ الخصم لا يمكن أن يكون بالسالب")),
      );
      return;
    }
    if (customerPaid < finalTotal && customerPaid > -1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ المبلغ المدفوع أقل من الصافي")));
      return;
    }

    try {
      for (var item in cart) {
        final p = item['product'] as Product;
        final qty = item['qty'] as int;
        final newQty = p.quantity - qty;
        if (newQty < 0) continue;
        final newTotalOriginalPrice = p.originalPrice * newQty;

        final updated = Product(
          originalPrice: p.originalPrice,
          id: p.id,
          name: p.name,
          price: p.price,
          quantity: newQty,
          barcode: p.barcode,
          expire: p.expire,
          totalOriginalPrice: newTotalOriginalPrice, // ✅
          allProductsOriginalTotal: 0, // مؤقت، هنحسبه بعدين
        );
        await db.updateProduct(updated);
      }
      final allProducts = await db.getAllProducts();
      double allProductsOriginalTotal = 0;
      for (var prod in allProducts) {
        allProductsOriginalTotal += prod.totalOriginalPrice;
      }
      // ✅ حدث كل المنتجات بالإجمالي الكلي الجديد
      for (var prod in allProducts) {
        final updated = prod.copyWith(
          allProductsOriginalTotal: allProductsOriginalTotal,
        );
        await db.updateProduct(updated);
      }

      await db.insertInvoice({
        "date": DateTime.now().toIso8601String(),
        "total": totalPrice,
        "discount": discount,
        "finalTotal": finalTotal,
        "customerPaid": customerPaid,
        "cashierReturn": cashierReturn,
        "items": cart.map((e) {
          final p = e['product'] as Product;
          return {
            "id": p.id,
            "name": p.name,
            "price": p.price,
            "qty": e['qty'],
            "subtotal": p.price * e['qty'],
            "barcode": p.barcode, // ✅ هنا ضيفنا الباركود
          };
        }).toList(),
      });

      await db.addSaleToShift(finalTotal);

      setState(() {
        cart.clear();
        qtyFocusNodes.clear();
        discountController.clear();
        customerPaidController.clear();
        cashierReturnController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ تمت عملية البيع وتخزين الفاتورة")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ حدث خطأ أثناء إتمام البيع: \$e")),
      );
    }
  }

  // String formatNumber(num value) {
  //   if (value is int || value == value.roundToDouble())
  //     return value.toInt().toString();
  //   return value.toString();
  // }

  void _handleEnterFocus(
    BuildContext context,
    FocusNode current,
    FocusNode? next, {
    bool isPaidField = false,
  }) {
    current.unfocus();
    if (isPaidField) {
      _completeSale();
    } else if (next != null) {
      FocusScope.of(context).requestFocus(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () {
            Navigator.of(context).pop(true);
          },
          child: Icon(Icons.arrow_back),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("الكاشير"),
            Container(
              padding: EdgeInsets.all(5),
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
            SizedBox(),
          ],
        ),
        actions: [
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
                onPressed: () async {
                  if (isOpen) {
                    await db.closeShift(current["id"]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("✅ تم إغلاق الوردية")),
                    );
                  } else {
                    await db.openShift();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("✅ تم فتح وردية جديدة")),
                    );
                  }
                  setState(() {});
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: barcodeController,
              focusNode: barcodeFocusNode,
              decoration: InputDecoration(
                labelText: "ادخل الباركود أو امسح بالماسح",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(Duration(milliseconds: 300), () {
                  if (value.length > 5) {
                    _addProductByBarcode(value.trim());
                    cashierReturnController.text = formatNumber(cashierReturn);
                    setState(() {});
                  }
                });
              },
              onSubmitted: (value) {
                if (value.trim().isEmpty) {
                  // 🟢 لو الباركود فاضي انقل مباشرة لحقل الخصم
                  FocusScope.of(context).requestFocus(discountFocusNode);
                } else {
                  _addProductByBarcode(value.trim());
                  cashierReturnController.text = formatNumber(cashierReturn);
                  setState(() {});
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: discountController,
              focusNode: discountFocusNode,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                NoLeadingZeroFormatter(),
              ],
              decoration: InputDecoration(
                labelText: "الخصم",
                suffixText: "جنيه",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _handleEnterFocus(
                context,
                discountFocusNode,
                customerPaidFocusNode,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: customerPaidController,
              focusNode: customerPaidFocusNode,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                NoLeadingZeroFormatter(),
              ],
              decoration: InputDecoration(
                labelText: "المبلغ المدفوع من العميل",
                suffixText: "جنيه",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _handleEnterFocus(
                context,
                customerPaidFocusNode,
                null,
                isPaidField: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              focusNode: returnCashFocus,
              controller: cashierReturnController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "الباقي للعميل",
                suffixText: "جنيه",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _handleEnterFocus(
                context,
                returnCashFocus,
                null,
                isPaidField: true,
              ),
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Text(
                      "🛒 السلة فارغة",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (context, i) {
                      final p = cart[i]['product'] as Product;
                      final controller =
                          cart[i]['controller'] as TextEditingController;
                      final qty = cart[i]['qty'] as int;
                      final focusNode = cart[i]['focusNode'] as FocusNode;
                      final subtotal = p.price * qty;

                      return Card(
                        margin: EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            spacing: 20,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // اسم المنتج
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              //      SizedBox(width: 8),

                              // السعر
                              Text(
                                "السعر: ${formatNumber(p.price)}",
                                style: TextStyle(fontSize: 18),
                              ),

                              SizedBox(width: 8),

                              // أدوات التحكم في الكمية
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove),
                                    onPressed: () {
                                      if (qty > 1) {
                                        setState(() {
                                          cart[i]['qty'] -= 1;
                                          controller.text = cart[i]['qty']
                                              .toString();
                                          cashierReturnController.text =
                                              formatNumber(cashierReturn);
                                        });
                                      }
                                    },
                                  ),
                                  Container(
                                    width: 50,
                                    height: 40,
                                    child: TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        if (value.isEmpty) {
                                          Future.microtask(() {
                                            setState(() {
                                              cart[i]['qty'] = 1;
                                              controller.text = "1";
                                              cashierReturnController.text =
                                                  formatNumber(cashierReturn);
                                            });
                                          });
                                          return;
                                        }
                                        int newQty = int.tryParse(value) ?? 1;
                                        if (newQty <= 0) newQty = 1;
                                        if (newQty > p.quantity) {
                                          newQty = p.quantity;
                                          Future.microtask(() {
                                            controller.text = newQty.toString();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "❌ لا يمكن تجاوز الكمية المتاحة (${p.quantity})",
                                                ),
                                              ),
                                            );
                                            cashierReturnController.text =
                                                formatNumber(cashierReturn);
                                          });
                                        }
                                        setState(() {
                                          cart[i]['qty'] = newQty;
                                          cashierReturnController.text =
                                              formatNumber(cashierReturn);
                                        });
                                      },
                                      onSubmitted: (_) {
                                        if (i + 1 < cart.length) {
                                          FocusScope.of(context).requestFocus(
                                            cart[i + 1]['focusNode'],
                                          );
                                        } else {
                                          _completeSale();
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add),
                                    onPressed: () {
                                      if (qty < p.quantity) {
                                        setState(() {
                                          cart[i]['qty'] += 1;
                                          controller.text = cart[i]['qty']
                                              .toString();
                                          cashierReturnController.text =
                                              formatNumber(cashierReturn);
                                        });
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "❌ لا يمكن تجاوز الكمية المتاحة (${p.quantity})",
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),

                              SizedBox(width: 8),

                              // المجموع
                              Expanded(
                                child: Text(
                                  "المجموع: ${formatNumber(subtotal)}",
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),

                              // زر الحذف
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() => cart.removeAt(i));
                                  cashierReturnController.text = formatNumber(
                                    cashierReturn,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: Colors.grey[200],
            padding: EdgeInsets.all(12),
            child: Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "الإجمالي:  ${formatNumber(totalPrice)}",
                      style: TextStyle(fontSize: 18),
                    ),
                    Text("الخصم:  ${formatNumber(discount)}"),
                    Text(
                      "الصافي:  ${formatNumber(finalTotal)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.check),
                    label: Text(
                      "إتمام البيع",
                      style: TextStyle(color: AppColors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                    ),
                    onPressed: cart.isEmpty ? null : _completeSale,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    if (text == "0") return newValue;
    text = text.replaceFirst(RegExp(r'^0+'), '');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
