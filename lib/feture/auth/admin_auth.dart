import 'package:flutter/material.dart';
import 'package:market/core/class/app_color.dart';
import 'package:market/core/class/components.dart';
import 'package:market/core/class/routs_name.dart';
import 'package:market/core/db_helper/db_helper.dart';
import 'package:market/core/func/valedit.dart';
import 'package:market/feture/auth/admin_storage.dart';
import 'package:market/feture/home/widget/button_custom.dart';

class AdminAuth extends StatefulWidget {
  const AdminAuth({super.key});

  @override
  State<AdminAuth> createState() => _AdminAuthState();
}

class _AdminAuthState extends State<AdminAuth> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DBHelper();
  final _nameFocus = FocusNode();
  final _passFocus = FocusNode();
  final _authFocus = FocusNode();
  bool isShow = false;
  String message = "";

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passC = TextEditingController();

    AdminStorage.getUsername().then((username) {
      if (username != null) {
        emailController.text = username;
        setState(() {}); // لإظهار الحقل بدون تعديل الاسم
      }
    });
  }

  Future<String> _login(String username, String password) async {
    if (_formKey.currentState!.validate()) {
      var dbClient = await dbHelper.db;

      // الأول: هل المستخدم موجود؟
      var user = await dbClient.query(
        "users",
        where: "username = ?",
        whereArgs: [username],
      );

      if (user.isEmpty) {
        return "❌ لا يوجد مستخدم بهذا الاسم";
      }

      // لو المستخدم موجود: نتحقق من كلمة المرور
      var res = await dbClient.query(
        "users",
        where: "username = ? AND password = ?",
        whereArgs: [username, password],
      );

      if (res.isEmpty) {
        return "❌ كلمة المرور غير صحيحة";
      }
      await AdminStorage.saveUsername(emailController.text);

      Navigator.pushNamed(context, AppRouts.addAdmin);
      return "✅ تسجيل الدخول ناجح";
    }
    return "اكمل البيانات صحيح";
  }

  @override
  void dispose() {
    emailController.dispose();
    passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تسجيل الدخول المسؤل")),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              defaultFormField(
                controller: emailController,
                label: "اسم المستخدم",
                validate: validateAdmin,
                prefixIcon: Icons.person,
                focusNode: _nameFocus,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passFocus);
                },
              ),

              defaultFormField(
                suffix: InkWell(
                  onTap: () {
                    isShow = !isShow;
                    setState(() {});
                  },
                  child: Icon(
                    isShow
                        ? Icons.remove_red_eye
                        : Icons.remove_red_eye_outlined,
                  ),
                ),
                isPassword: isShow,
                controller: passC,
                label: "كلمة السر",
                validate: validatePassword,
                prefixIcon: Icons.lock,
                focusNode: _passFocus,
                onFieldSubmitted: (_) async {
                  String result = await _login(
                    emailController.text,
                    passC.text,
                  );
                  setState(() {
                    message = result;
                  });
                  print(result);
                },
              ),

              ButtonCustom(
                focus: _authFocus,
                ontap: () async {
                  String result = await _login(
                    emailController.text,
                    passC.text,
                  );
                  setState(() {
                    message = result;
                  });
                  print(result);
                },
                title: "تسجيل الدخول",
                color: AppColors.pri,
              ),
              if (message.isNotEmpty)
                Text(
                  message,
                  style: TextStyle(
                    color: message.contains("✅") ? Colors.green : Colors.red,
                    fontSize: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
