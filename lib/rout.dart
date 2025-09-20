import 'package:flutter/material.dart';
import 'package:market/core/class/routs_name.dart';
import 'package:market/feature_admin/change_acc/change_pass_user.dart';
import 'package:market/feature_admin/home/home_admin.dart';
import 'package:market/feature_admin/invoic/presentation/page/invoice_page.dart';
import 'package:market/feature_admin/shift/shift_page.dart';
import 'package:market/feature_seller/presentation/page/seller_home.dart';
import 'package:market/feture/auth/admin_auth.dart';
import 'package:market/feture/home/start_home.dart';

Map<String, Widget Function(BuildContext)> routs = {
  "/": (_) => StartPage(),
  AppRouts.adminLogIn: (_) => AdminAuth(),
  AppRouts.addAdmin: (_) => ProductListPage(),
  AppRouts.sellerHome: (_) => CashierPage(),
  AppRouts.invoice: (_) => InvoicesPage(),
  AppRouts.changePass: (_) => ChangeAdminInfoPage(),

  AppRouts.shiftsPage: (_) => ShiftsPage(),
};
