import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:market/feature_admin/home/data/model/product_model.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';

class AddEditProductPage extends StatefulWidget {
  final Product? product;

  const AddEditProductPage({Key? key, this.product}) : super(key: key);

  @override
  _AddEditProductPageState createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _originalPriceController = TextEditingController();
  final _originalPriceFocus = FocusNode();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _quantityController = TextEditingController();

  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _quantityFocus = FocusNode();
  final _barcodeFocus = FocusNode();
  final _saveButtonFocus = FocusNode();

  DateTime? _expireDate;

  final DBHelperAdmin db = DBHelperAdmin();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _originalPriceController.text = widget.product!.originalPrice % 1 == 0
          ? widget.product!.originalPrice.toInt().toString()
          : widget.product!.originalPrice.toString();

      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price % 1 == 0
          ? widget.product!.price.toInt().toString()
          : widget.product!.price.toString();
      _quantityController.text = widget.product!.quantity.toString();
      _barcodeController.text = widget.product!.barcode;
      _expireDate = widget.product!.expire;
    }
  }

  @override
  void dispose() {
    _originalPriceController.dispose();
    _originalPriceFocus.dispose();

    _nameController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();

    _nameFocus.dispose();
    _priceFocus.dispose();
    _quantityFocus.dispose();
    _barcodeFocus.dispose();
    _saveButtonFocus.dispose();

    super.dispose();
  }

  String formatNumber(num value) {
    if (value > 0) {
      if (value is int || value == value.roundToDouble()) {
        return value.toInt().toString(); // int
      }
      return value.toStringAsFixed(2); // double بعشريتين
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ قيمة($value). يجب ان تكون صحيحة"),
        backgroundColor: Colors.redAccent,
      ),
    );
    return "";
  }

  Future<void> _pickExpireDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expireDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _expireDate = picked;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _saving = true);

      final rawPrice = _priceController.text.trim();
      final price = rawPrice.contains('.')
          ? double.parse(rawPrice)
          : int.parse(rawPrice).toDouble();

      final rawOriginalPrice = _originalPriceController.text.trim();
      final originalPrice = rawOriginalPrice.contains('.')
          ? double.parse(rawOriginalPrice)
          : int.parse(rawOriginalPrice).toDouble();

      // ✅ تحقق: السعر الأصلي لا يكون أكبر من السعر
      if (originalPrice > price) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ السعر الأصلي لا يمكن أن يكون أكبر من السعر"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return; // منع الحفظ
      }

      final quantity = int.parse(_quantityController.text.trim());
      final barcode = _barcodeController.text.trim();
      final name = _nameController.text.trim();
      final totalOriginalPrice = originalPrice * quantity;
      final allProducts = await db.getAllProducts();
      double allProductsOriginalTotal = totalOriginalPrice;
      for (var p in allProducts) {
        allProductsOriginalTotal += p.totalOriginalPrice;
      }
      final product = Product(
        originalPrice: originalPrice,
        id: widget.product?.id,
        name: name,
        price: price,
        quantity: quantity,
        barcode: barcode,
        expire: _expireDate,
        totalOriginalPrice: totalOriginalPrice, // ✅
        allProductsOriginalTotal: allProductsOriginalTotal, // ✅
      );

      // تحقق من وجود باركود بنفس القيمة في أي منتج آخر
      final existingBarcode = await db.getProductByBarcode(product.barcode);
      if (existingBarcode != null && existingBarcode.id != widget.product?.id) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ هذا الباركود مرتبط بمنتج آخر (${existingBarcode.name}). غير مسموح بتغييره.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return; // يمنع الحفظ
      }

      // تحقق من وجود اسم مشابه لمنتج آخر
      final existingName = await db.getProductByName(product.name);
      if (existingName != null && existingName.id != widget.product?.id) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ هذا الاسم مرتبط بمنتج آخر (${existingName.name}). غير مسموح بإعادة استخدامه.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return; // يمنع الحفظ
      }

      // إذا الباركود والاسم جديد أو يخص نفس المنتج، يسمح بالحفظ
      if (widget.product != null) {
        await db.updateProduct(product);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ تم تحديث المنتج بنجاح")));
      } else {
        await db.insertProduct(product);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ تم إضافة المنتج الجديد")));
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ خطأ أثناء الحفظ: $e")));

        print(e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل المنتج' : 'إضافة منتج')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  decoration: InputDecoration(labelText: 'اسم المنتج'),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_originalPriceFocus);
                  },
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'اكتب اسم المنتج'
                      : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _originalPriceController,
                  focusNode: _originalPriceFocus,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(
                        r'^(0|[1-9]\d*)(\.\d{0,2})?$',
                      ), // يقبل 0 أو أرقام صحيحة + عشريتين
                    ),
                  ],
                  decoration: InputDecoration(labelText: 'السعر الأصلي'),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_priceFocus);
                  },
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'اكتب السعر الأصلي';
                    final val = double.tryParse(v);
                    if (val == null) return 'السعر الأصلي غير صالح';
                    if (val < 0) return 'السعر الأصلي لا يمكن أن يكون سالب';
                    return null;
                  },
                ),
                SizedBox(height: 12),

                TextFormField(
                  controller: _priceController,
                  focusNode: _priceFocus,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    // يسمح بالأرقام والنقطة العشرية فقط، ويمنع أي حرف آخر مباشرة
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^[1-9]\d*(\.\d{0,2})?$'),
                    ),
                  ],
                  decoration: InputDecoration(labelText: 'السعر'),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_quantityFocus);
                  },
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'اكتب السعر';
                    final val = double.tryParse(v);
                    if (val == null) return 'السعر غير صالح';
                    if (val < 0) return 'السعر لا يمكن أن يكون سالب';
                    if (val == 0) return "السعر لا يجب ان يكون 0";
                    return null;
                  },
                ),
                SizedBox(height: 12),

                TextFormField(
                  controller: _quantityController,
                  focusNode: _quantityFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[1-9]\d*$')),
                  ],
                  decoration: InputDecoration(labelText: 'الكمية'),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_barcodeFocus);
                  },

                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'اكتب الكمية';
                    final val = int.tryParse(v);
                    if (val == null) return 'الكمية غير صالحة';
                    if (val < 0) return 'الكمية لا يمكن أن تكون سالبة';
                    if (val == 0) return "الكمية لا يجب ان يكون 0";
                    return null;
                  },
                ),
                SizedBox(height: 12),

                TextFormField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocus,
                  decoration: InputDecoration(
                    labelText: 'الباركود',
                    hintText: 'امسح الباركود بجهاز USB أو اكتبها يدويًا',
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_saveButtonFocus);
                  },
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'اكتب الباركود' : null,
                ),
                SizedBox(height: 12),

                ListTile(
                  title: Text(
                    _expireDate != null
                        ? "تاريخ الانتهاء: ${DateFormat('yyyy-MM-dd').format(_expireDate!)}"
                        : "اختر تاريخ الانتهاء",
                  ),
                  trailing: Icon(Icons.calendar_today),
                  onTap: _pickExpireDate,
                ),
                SizedBox(height: 20),

                ElevatedButton(
                  focusNode: _saveButtonFocus,
                  onPressed: _saving ? null : _saveProduct,
                  child: _saving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(isEdit ? 'تحديث' : 'حفظ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
