import 'package:flutter/material.dart';
import 'package:market/feature_admin/home/data/model/product_model.dart';

void showDetails(Product p, BuildContext context) {
  String formatNumber(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('تفاصيل المنتج'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اسم المنتج: ${p.name}',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'السعر: ${formatNumber(p.price)} ',
            style: TextStyle(fontSize: 30),
          ),
          SizedBox(height: 6),
          Text(
            'الرصيد الموجود فى المخزن حاليا: ${p.quantity}',
            style: TextStyle(fontSize: 30),
          ),
          SizedBox(height: 6),
          Text('الباركود: ${p.barcode}', style: TextStyle(fontSize: 30)),
          SizedBox(height: 6),
          Text(
            'تاريخ الانتهاء: ${p.expire != null ? p.expire!.toLocal().toString().split(' ')[0] : "-"}',
            style: TextStyle(fontSize: 30),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('قفل')),
      ],
    ),
  );
}
