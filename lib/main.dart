import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/app/erd_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } on PlatformException catch (error, stackTrace) {
    // A hot restart can keep a pre-plugin macOS engine alive. The app still
    // opens with defaults; a full run reconnects the plugin and restores data.
    debugPrint('Preferences unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(ErdApp(preferences: preferences));
}
