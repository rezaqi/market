import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TutorialService {
  static const String _tutorialShownKey = 'tutorial_shown';

  static Future<bool> isTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialShownKey) ?? false;
  }

  static Future<void> setTutorialShown(bool shown) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialShownKey, shown);
  }

  static void showTutorial(BuildContext context, List<TargetFocus> targets) {
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "تخطي",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        setTutorialShown(true);
      },
      onSkip: () {
        setTutorialShown(true);
        return true;
      },
    ).show(context: context);
  }
}
