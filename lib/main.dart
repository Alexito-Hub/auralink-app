import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_manager.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AuraLinkApp());
}

class AuraLinkApp extends StatefulWidget {
  const AuraLinkApp({super.key});

  @override
  State<AuraLinkApp> createState() => _AuraLinkAppState();
}

class _AuraLinkAppState extends State<AuraLinkApp> {
  @override
  void initState() {
    super.initState();
    ThemeManager.instance.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager.instance;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeManager.isDarkMode
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: themeManager.isDarkMode
            ? const Color(0xFF000000)
            : const Color(0xFFF8F9FA),
      ),
    );
    return MaterialApp(
      title: 'AuraLink Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeManager.themeMode,
      home: const SplashScreen(),
    );
  }
}
