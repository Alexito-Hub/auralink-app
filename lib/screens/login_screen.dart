import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'setup_screen.dart';
import '../core/theme/app_colors.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  bool _isLoading = false;
  void _onNumberTap(int n) {
    if (_pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() => _pin += n.toString());
    }
  }
  void _onDelete() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }
  Future<void> _attemptLogin() async {
    if (_pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ERR: PIN_TOO_SHORT (min 4)')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final result = await ApiService.instance.login(_pin);
    setState(() => _isLoading = false);
    if (result.success) {
      if (mounted) {
        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } else {
      HapticFeedback.vibrate();
      setState(() => _pin = '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ERR: ${result.message}')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('AUTH_REQUIRED', style: TextStyle(color: AppColors.keyword, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 10),
              Text('auralink_control login', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 40),
              _buildPinDisplay(colorScheme),
              const SizedBox(height: 50),
              _buildKeypad(theme),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
                icon: const Icon(Icons.settings_ethernet, size: 16),
                label: const Text('configure_network()', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildPinDisplay(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool filled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: filled ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.2)),
            color: filled ? colorScheme.primary.withValues(alpha: 0.5) : Colors.transparent,
          ),
        );
      }),
    );
  }
  Widget _buildKeypad(ThemeData theme) {
    return Column(
      children: [
        for (var row in [[1, 2, 3], [4, 5, 6], [7, 8, 9]])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((n) => _keyBtn(theme, '[$n]', () => _onNumberTap(n))).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _keyBtn(theme, 'CLR', () => setState(() => _pin = ''), isSmall: true),
            _keyBtn(theme, '[0]', () => _onNumberTap(0)),
            _keyBtn(theme, 'BACK', _onDelete, isSmall: true),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 220,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _attemptLogin,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            ),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('SUBMIT_CREDENTIALS()', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        )
      ],
    );
  }
  Widget _keyBtn(ThemeData theme, String text, VoidCallback onTap, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 70,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text, style: TextStyle(
            fontSize: isSmall ? 12 : 18, 
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.bold
          )),
        ),
      ),
    );
  }
}
