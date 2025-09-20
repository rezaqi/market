import 'package:flutter/material.dart';
import 'package:market/feature_admin/home/data/source/dh_helper.dart';
import 'package:market/rout.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize ffi for desktop
  sqfliteFfiInit();
  // If you want to use databaseFactoryFfi globally you can set it here
  databaseFactory = databaseFactoryFfi;
  DBHelperAdmin().printDbPath();
  runApp(Directionality(textDirection: TextDirection.rtl, child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ام النور',

      routes: routs,
    );
  }
}
