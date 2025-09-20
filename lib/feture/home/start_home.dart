import 'package:flutter/material.dart';
import 'package:market/core/class/app_color.dart';
import 'package:market/core/class/routs_name.dart';
import 'package:market/feture/home/widget/button_custom.dart';
import 'package:market/feture/home/widget/text_title.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double h = size.height;
    double w = size.width;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 20, // المسافة من الأعلى
            left: 20, // المسافة من الشمال
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(),
                color: AppColors.thi,
              ),
              child: Text(
                textAlign: TextAlign.center,
                "للتواصل مع مهندس السيستم\n01212577699",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          Column(
            spacing: 10,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GlowingTitle(),
              SizedBox(height: 30),
              ButtonCustom(
                ontap: () {
                  Navigator.of(context).pushNamed(AppRouts.adminLogIn);
                },
                title: "المسؤل",
                color: Colors.redAccent,
              ),
              ButtonCustom(
                ontap: () {
                  Navigator.pushNamed(context, AppRouts.sellerHome);
                },
                title: "البائع",
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
