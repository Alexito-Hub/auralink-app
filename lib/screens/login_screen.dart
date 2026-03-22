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
    // Auto-focus para recibir eventos de teclado de inmediato
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
        Future.delayed(const Duration(milliseconds: 300), _attemptLogin);
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
      } else if (key.keyLabel.length == 1 && RegExp(r'[0-9]').hasMatch(key.keyLabel)) {
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
    if (_pin.length < 4) {
      TerminalMessenger.show(context, 'ERR: PIN_TOO_SHORT (min 4)', isError: true);
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final result = await ApiService.instance.login(_pin);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
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

    // Asegurarse de que el foco se mantenga al tocar cualquier parte de la pantalla
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
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
                  if (_isOffline && _savedMac != null) ...[
                    const SizedBox(height: 20),
                    TerminalMessenger.inlineBanner('SERVER_OFFLINE', 'Daemon unreachable at ${_ipControllerText()}'),
                  ],

                  const SizedBox(height: 40),
                  _buildPinDisplay(colorScheme),
                  const SizedBox(height: 50),
                  _buildKeypad(theme),
                  const Spacer(),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
                        icon: const Icon(Icons.settings_ethernet, size: 16),
                        label: const Text('configure_network()', style: TextStyle(fontSize: 12)),
                      ),
                      if (_savedMac != null)
                        TextButton.icon(
                          onPressed: _isLoading ? null : _sendWol,
                          icon: const Icon(Icons.power_settings_new, size: 16, color: Colors.orange),
                          label: const Text('wake_on_lan()', style: TextStyle(fontSize: 12, color: Colors.orange)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWolBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Text('SERVER_OFFLINE', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
        ],
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
