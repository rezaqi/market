import 'package:flutter/material.dart';

class ButtonCustom extends StatelessWidget {
  final String title;
  final Color color;
  final FocusNode? focus;
  final void Function()? ontap;

  const ButtonCustom({
    super.key,
    required this.title,
    required this.color,
    this.ontap,
    this.focus,
  });

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double h = size.height;
    double w = size.width;
    return ElevatedButton(
      focusNode: focus,
      onPressed: ontap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        width: w,
        height: h * 0.1,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,

          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 30,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
