import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../core/theme/app_colors.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _displayText = '';
  final String _targetText = '_> auralink';
  
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    // 1. Animacion de escritura
    for (int i = 0; i <= _targetText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _displayText = _targetText.substring(0, i);
        });
      }
    }

    // 2. Carga de configuracion (simultanea o despues de la animacion)
    final hasConfig = await ApiService.instance.loadSavedConfig();
    final hasToken = ApiService.instance.hasToken;

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // 3. Navegacion segun estado
    Widget nextScreen;
    if (!hasConfig) {
      nextScreen = const LoginScreen(); // O SetupScreen si prefieres
    } else if (hasToken) {
      nextScreen = const DashboardScreen();
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          _displayText,
          style: const TextStyle(
            color: AppColors.keyword,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
