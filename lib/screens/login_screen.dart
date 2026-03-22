import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/wol_service.dart';
import '../services/terminal_messenger.dart';
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
  bool _isOffline = false;
  String? _savedMac;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkServerStatus() async {
    final mac = await WolService.getSavedMac();
    final isReachable = await ApiService.instance.isServerReachable();
    if (mounted) {
      setState(() {
        _savedMac = mac;
        _isOffline = !isReachable;
      });
    }
  }

  void _onNumberTap(int n) {
    if (_pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() => _pin += n.toString());
      if (_pin.length == 4) {
        _attemptLogin();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.backspace) {
        _onDelete();
      } else if (key == LogicalKeyboardKey.escape) {
        setState(() => _pin = '');
      } else if (key.keyLabel.length == 1 &&
          RegExp(r'[0-9]').hasMatch(key.keyLabel)) {
        _onNumberTap(int.parse(key.keyLabel));
      } else if (key == LogicalKeyboardKey.enter && _pin.length == 4) {
        _attemptLogin();
      }
    }
  }

  Future<void> _sendWol() async {
    if (_savedMac == null) return;
    setState(() => _isLoading = true);
    final result = await WolService.sendMagicPacket(_savedMac!);
    setState(() => _isLoading = false);

    if (mounted) {
      TerminalMessenger.show(
        context,
        result.success ? 'MAGIC_PACKET_SENT' : 'WOL_FAILED: ${result.message}',
        isSuccess: result.success,
        isError: !result.success,
      );
      Future.delayed(const Duration(seconds: 5), _checkServerStatus);
    }
  }

  Future<void> _attemptLogin() async {
    if (_pin.length < 4 || _isLoading) return;

    setState(() => _isLoading = true);
    final result = await ApiService.instance.login(_pin);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        HapticFeedback.vibrate();
        String errorMsg = result.message ?? 'UNKNOWN_ERROR';
        if (result.statusCode == 429) {
          errorMsg = 'TEMPORARY_LOCKOUT: $errorMsg';
        }

        TerminalMessenger.show(context, errorMsg, isError: true);
        setState(() => _pin = '');
      }
    }
  }

  String _ipControllerText() => ApiService.instance.ip ?? 'UNKNOWN_IP';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('AUTH_REQUIRED',
                        style: TextStyle(
                            color: AppColors.keyword,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    const SizedBox(height: 8),
                    Text('auralink_control login',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    if (_isOffline && _savedMac != null) ...[
                      const SizedBox(height: 15),
                      TerminalMessenger.inlineBanner('SERVER_OFFLINE',
                          'Daemon unreachable at ${_ipControllerText()}'),
                    ],
                    const SizedBox(height: 30),
                    _buildPinDisplay(colorScheme),
                    const SizedBox(height: 40),
                    _buildKeypad(theme),
                    const SizedBox(height: 30),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 15,
                      runSpacing: 10,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SetupScreen())),
                          icon: const Icon(Icons.settings_ethernet, size: 14),
                          label: const Text('configure_network()',
                              style: TextStyle(fontSize: 11)),
                        ),
                        if (_savedMac != null)
                          TextButton.icon(
                            onPressed: _isLoading ? null : _sendWol,
                            icon: const Icon(Icons.power_settings_new,
                                size: 14, color: Colors.orange),
                            label: const Text('wake_on_lan()',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
                color: filled
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.2)),
            color: filled
                ? colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(ThemeData theme) {
    return Column(
      children: [
        for (var row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9]
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row
                .map((n) => _keyBtn(theme, '[$n]', () => _onNumberTap(n)))
                .toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _keyBtn(theme, 'CLR', () => setState(() => _pin = ''),
                isSmall: true),
            _keyBtn(theme, '[0]', () => _onNumberTap(0)),
            _keyBtn(theme, 'BACK', _onDelete, isSmall: true),
          ],
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
      ],
    );
  }

  Widget _keyBtn(ThemeData theme, String text, VoidCallback onTap,
      {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 70,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: isSmall ? 12 : 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
