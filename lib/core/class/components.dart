import 'package:flutter/material.dart';
import 'package:market/core/class/app_color.dart';

Widget unDefineRoute() =>
    const Scaffold(body: Center(child: Text("UnDefine Route")));

Widget defaultFormField({
  required TextEditingController controller,
  required String label,
  required Function validate,
  required IconData prefixIcon,
  Widget? suffix,
  TextInputType? type = TextInputType.text,
  bool isPassword = false,
  final FocusNode? focusNode,
  void Function(String)? onFieldSubmitted,
  int minLines = 1, // أقل عدد أسطر
  int maxLines = 1, // أكبر عدد أسطر
}) => TextFormField(
  keyboardType: type,
  controller: controller,
  minLines: minLines,
  maxLines: maxLines,
  focusNode: focusNode,
  onFieldSubmitted: onFieldSubmitted,
  validator: (value) {
    return validate(value);
  },
  obscureText: isPassword,
  decoration: InputDecoration(
    prefixIcon: Icon(prefixIcon, color: AppColors.pri, size: 20),
    suffix: suffix,
    filled: true,
    fillColor: Colors.white,
    hintText: label,
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.transparent),
      borderRadius: BorderRadius.circular(12),
    ),
  ),
);
