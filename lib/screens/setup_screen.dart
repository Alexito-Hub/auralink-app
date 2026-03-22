import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/wol_service.dart';
import '../services/terminal_messenger.dart';
import '../core/theme/app_colors.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _macController = TextEditingController();
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ApiService.instance.loadSavedConfig();
    _ipController.text = ApiService.instance.ip ?? '';
    _portController.text = ApiService.instance.port ?? '8443';
    _macController.text = await WolService.getSavedMac() ?? '';
    setState(() {});
  }

  Future<void> _save() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8443;
    final mac = _macController.text.trim();
    if (ip.isEmpty) return;
    setState(() => _isTesting = true);
    await ApiService.instance.configure(ip, port);
    if (mac.isNotEmpty) await WolService.saveMacAddress(mac);
    final reachable = await ApiService.instance.isServerReachable();
    setState(() => _isTesting = false);
    if (mounted) {
      TerminalMessenger.show(
        context, 
        reachable ? 'CONNECTION_SUCCESS' : 'CONNECTION_FAILED',
        isSuccess: reachable,
        isError: !reachable,
      );
      if (reachable) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ENV_CONFIG'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(30),
        children: [
          _buildField(theme, 'SERVER_IP', _ipController, '192.168.1.100'),
          const SizedBox(height: 15),
          _buildField(theme, 'PORT', _portController, '8443'),
          const SizedBox(height: 15),
          _buildField(theme, 'DEVICE_MAC', _macController, 'AA:BB:CC:DD:EE:FF'),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: _isTesting ? null : _save,
            child: _isTesting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) 
              : const Text('apply_changes()'),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
            label: const Text('factory_reset()', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('RESET_ALL_CONFIG?', style: TextStyle(color: Colors.white, fontFamily: 'monospace')),
        content: const Text('This will delete all saved IP, Port and Device IDs from this app.', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await ApiService.instance.resetApp();
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
                TerminalMessenger.show(context, 'APP_CONFIG_CLEARED', isSuccess: true);
              }
            }, 
            child: const Text('RESET', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  Widget _buildField(ThemeData theme, String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
