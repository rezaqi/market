import 'package:flutter/material.dart';
import 'package:market/core/db_helper/db_helper.dart';

class ChangeAdminInfoPage extends StatefulWidget {
  @override
  _ChangeAdminInfoPageState createState() => _ChangeAdminInfoPageState();
}

class _ChangeAdminInfoPageState extends State<ChangeAdminInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final FocusNode _oldPassFocus = FocusNode();

  final FocusNode _passFocus = FocusNode();

  final FocusNode _nameFocus = FocusNode();
  final DBHelper db = DBHelper();
  bool _saving = false;
  bool isShowPass = true;

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final oldPassword = _oldPasswordController.text.trim();
    if (oldPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ يجب إدخال كلمة السر القديمة")));
      return;
    }

    // التحقق من كلمة السر القديمة صحيحة
    final currentAdmin = await db.getAdminInfo();
    if (currentAdmin['password'] != oldPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ كلمة السر القديمة غير صحيحة")));
      return;
    }

    setState(() => _saving = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // إذا لم يدخل اسم المستخدم أو كلمة السر الجديدة، لا تحدث القيمة
    final newUsername = username.isNotEmpty
        ? username
        : currentAdmin['username'];
    final newPassword = password.isNotEmpty
        ? password
        : currentAdmin['password'];

    await db.updateAdminInfo(username: newUsername, password: newPassword);

    setState(() => _saving = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ تم تحديث بيانات الأدمن بنجاح")));

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تغيير بيانات الأدمن")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // كلمة السر القديمة
              TextFormField(
                focusNode: _oldPassFocus,
                controller: _oldPasswordController,
                decoration: InputDecoration(
                  labelText: "كلمة السر القديمة",
                  suffixIcon: InkWell(
                    onTap: () {
                      isShowPass = !isShowPass;
                      setState(() {});
                    },
                    child: Icon(
                      isShowPass
                          ? Icons.remove_red_eye
                          : Icons.remove_red_eye_outlined,
                    ),
                  ),
                ),
                obscureText: isShowPass,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_nameFocus);
                },
              ),
              SizedBox(height: 16),

              // اسم المستخدم الجديد
              TextFormField(
                focusNode: _nameFocus,
                controller: _usernameController,
                decoration: InputDecoration(labelText: "اسم المستخدم الجديد"),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) => null, // مش إجباري
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passFocus);
                },
              ),
              SizedBox(height: 16),

              // كلمة المرور الجديدة
              TextFormField(
                focusNode: _passFocus,
                controller: _passwordController,
                decoration: InputDecoration(labelText: "كلمة المرور الجديدة"),
                obscureText: isShowPass,
                validator: (value) {
                  if (value == null || value.isEmpty) return null; // مش إجباري
                  if (value.length < 6)
                    return "❌ كلمة السر يجب أن تكون 6 أحرف على الأقل";
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveChanges(),
              ),
              SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saving ? null : _saveChanges,
                child: _saving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("💾 حفظ التغييرات"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
