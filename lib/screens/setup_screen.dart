import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/wol_service.dart';
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
    _loadCurrent();
  }

  void _loadCurrent() async {
    await ApiService.instance.loadSavedConfig();
    _ipController.text = ApiService.instance.ip ?? '';
    _portController.text = ApiService.instance.port ?? '8443';
    final mac = await WolService.getSavedMac();
    if (mac != null) _macController.text = mac;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reachable ? 'SUCCESS' : 'ERR'),
          backgroundColor: reachable ? AppColors.success : AppColors.error,
        ),
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
