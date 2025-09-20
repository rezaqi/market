String? validateAdmin(String? value) {
  if (value == null || value.isEmpty) {
    return "❌  اسم المستخدم مطلوب";
  }
  if (value.length < 3) {
    return "❌ اسم المستخدم غير صالح";
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return "❌ كلمة المرور مطلوبة";
  }
  if (value.length < 4) {
    return "❌ كلمة المرور يجب أن تكون 6 حروف على الأقل";
  }
  return null;
}
