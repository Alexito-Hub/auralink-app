import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/wol_service.dart';
import '../core/theme/theme_manager.dart';
import '../core/theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _sysInfo;
  bool _isLoading = true;
  bool _isOffline = false;
  double _volume = 0;
  double _brightness = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final results = await Future.wait([
      ApiService.instance.get('/system/info'),
      ApiService.instance.get('/system/volume'),
      ApiService.instance.get('/system/brightness'),
      ApiService.instance.get('/boot/status'),
    ]);

    final info = results[0];
    final vol = results[1];
    final bri = results[2];
    final boot = results[3];
    
    if (mounted) {
      if (info.success) {
        setState(() {
          _sysInfo = info.data;
          if (boot.success) _sysInfo?['boot_data'] = boot.data;
          if (vol.success) {
            _volume = (vol.data['volume'] as int).toDouble();
          }
          if (bri.success) {
            _brightness = (bri.data['brightness'] as int).toDouble();
          }
          _isLoading = false;
          _isOffline = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = ThemeManager.instance;
    final syntaxColor = themeManager.isDarkMode ? AppColors.keyword : AppColors.primaryLight;
    final isLaptop = _sysInfo?['battery'] != null;
    final lidClosed = _sysInfo?['lid_closed'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('>_ auralink_control', style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: syntaxColor)),
            if (isLaptop)
              const Text('DEVICE_TYPE: LAPTOP', style: TextStyle(fontSize: 9, color: AppColors.comment, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(themeManager.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
            onPressed: () => themeManager.toggleTheme(!themeManager.isDarkMode),
          ),
          IconButton(onPressed: () {
            setState(() => _isLoading = true);
            _fetchData();
          }, icon: const Icon(Icons.refresh, size: 20)),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.logout, size: 20)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: TerminalLoading())
        : _isOffline 
          ? _buildOfflineView(theme)
          : Column(
              children: [
                if (lidClosed) _buildLidWarning(theme),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSectionTitle(theme, 'SYSTEM_RESOURCES'),
                      _buildSystemGrid(theme),
                      const SizedBox(height: 30),
                      _buildSectionTitle(theme, 'BOOT_SELECT'),
                      _buildBootSelection(theme),
                      const SizedBox(height: 30),
                      _buildSectionTitle(theme, 'AUDIO_CONFIG'),
                      _buildVolumeControl(theme),
                      const SizedBox(height: 20),
                      _buildSectionTitle(theme, 'DISPLAY_CONFIG'),
                      _buildBrightnessControl(theme),
                      const SizedBox(height: 30),
                      _buildPowerActions(theme),
                      const SizedBox(height: 20),
                      const Text('kernel-daemon v1.0.0', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.comment)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLidWarning(ThemeData theme) {
    return Container(
      width: double.infinity,
      color: AppColors.error.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LID_STATUS: CLOSED', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                Text('Open lid to interact', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: AppColors.error),
            const SizedBox(height: 20),
            const Text('DAEMON_UNREACHABLE', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
            const SizedBox(height: 10),
            const Text('System is offline', textAlign: TextAlign.center, style: TextStyle(color: AppColors.comment, fontSize: 12)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final mac = await WolService.getSavedMac();
                  if (mac != null && mac.isNotEmpty) {
                    final result = await WolService.sendMagicPacket(mac);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message), backgroundColor: result.success ? AppColors.success : AppColors.error),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.flash_on),
                label: const Text('WAKE_ON_LAN'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  side: const BorderSide(color: AppColors.string),
                  foregroundColor: AppColors.string,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchData();
              },
              child: const Text('retry_connection()'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessControl(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Text('BRI: ', style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 1,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Colors.orangeAccent,
              ),
              child: Slider(
                value: _brightness, min: 0, max: 100,
                onChanged: (v) => setState(() => _brightness = v),
                onChangeEnd: (v) => ApiService.instance.post('/system/brightness', {'value': v.toInt()}),
              ),
            ),
          ),
          Text('${_brightness.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    bool lidClosed = _sysInfo?['lid_closed'] ?? false;
    String os = _sysInfo?['os'] ?? 'unknown';
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Text('[ ', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13)),
          Text(' ]', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          if (title == 'SYSTEM_RESOURCES') ...[
            const SizedBox(width: 10),
            Icon(os == 'windows' ? Icons.window : Icons.terminal, size: 14, color: AppColors.comment),
            if (lidClosed) ...[
              const SizedBox(width: 5),
              const Icon(Icons.laptop, size: 14, color: AppColors.error),
            ],
          ],
          const Expanded(child: Divider(indent: 10, thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildSystemGrid(ThemeData theme) {
    final cpu = _sysInfo?['cpu']?['percent'] ?? 0;
    final ram = _sysInfo?['ram']?['percent'] ?? 0;
    final bat = _sysInfo?['battery']?['percent'] ?? 0;
    final temp = _sysInfo?['temps']?['cpu'] ?? 0;
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.8,
      children: [
        _statCard(theme, 'CPU', '$cpu%', cpu / 100, AppColors.function),
        _statCard(theme, 'RAM', '$ram%', ram / 100, AppColors.keyword),
        _statCard(theme, 'TEMP', '$temp°C', temp / 100, Colors.orangeAccent),
        _statCard(theme, 'BAT', '$bat%', bat / 100, AppColors.string),
      ],
    );
  }

  Widget _statCard(ThemeData theme, String label, String value, double progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          LinearProgressIndicator(value: progress, color: color, backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05), minHeight: 2),
        ],
      ),
    );
  }

  Widget _buildBootSelection(ThemeData theme) {
    final bootData = _sysInfo?['boot_data'];
    if (bootData == null || bootData['entries'] == null) {
      return const Text('NO_BOOT_DATA', style: TextStyle(color: AppColors.comment, fontSize: 11));
    }
    final String currentOs = bootData['current_os'] ?? 'unknown';
    final List<dynamic> entries = bootData['entries'];
    final hasArch = entries.any((e) => e['name'].toString().toLowerCase().contains('arch'));
    final hasWindows = entries.any((e) => e['name'].toString().toLowerCase().contains('windows'));
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        if (hasArch) _bootBtn(theme, 'arch_linux', 'arch', const Color(0xFF1793D1), currentOs == 'arch'),
        if (hasWindows) _bootBtn(theme, 'windows_11', 'windows', Colors.blueAccent, currentOs == 'windows'),
      ],
    );
  }

  Widget _bootBtn(ThemeData theme, String label, String id, Color color, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onLongPress: isActive ? null : () async {
          HapticFeedback.heavyImpact();
          await ApiService.instance.post('/boot/select', {'target': id});
        },
        child: OutlinedButton(
          onPressed: isActive ? null : () async {
            HapticFeedback.mediumImpact();
            await ApiService.instance.post('/boot/switch', {'target': id});
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: isActive ? AppColors.comment.withValues(alpha: 0.2) : color.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: isActive ? color.withValues(alpha: 0.05) : null,
          ),
          child: Column(
            children: [
              Text(isActive ? 'SYSTEM_ACTIVE' : label, style: TextStyle(color: isActive ? AppColors.comment : color, fontSize: 12, fontWeight: FontWeight.bold)),
              if (!isActive) const Text('(hold to set)', style: TextStyle(fontSize: 8, color: AppColors.comment)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControl(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Text('VOL: ', style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
          Expanded(
            child: Slider(
              value: _volume, min: 0, max: 100,
              onChanged: (v) => setState(() => _volume = v),
              onChangeEnd: (v) => ApiService.instance.post('/system/volume', {'action': 'set', 'value': v.toInt()}),
            ),
          ),
          Text('${_volume.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPowerActions(ThemeData theme) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly, runSpacing: 10,
      children: [
        _actionBtn(theme, 'powerOn', Icons.flash_on, AppColors.string, () async {
          final mac = await WolService.getSavedMac();
          if (mac != null) await WolService.sendMagicPacket(mac);
        }),
        _actionBtn(theme, 'sleepMode', Icons.bedtime_outlined, Colors.purpleAccent, () async {
          await ApiService.instance.post('/system/sleep');
        }),
        _actionBtn(theme, 'powerOff', Icons.power_settings_new, Colors.redAccent, () async {
          await ApiService.instance.post('/system/shutdown');
        }),
        _actionBtn(theme, 'reboot', Icons.restart_alt, Colors.orangeAccent, () async {
          await ApiService.instance.post('/system/reboot');
        }),
      ],
    );
  }

  Widget _actionBtn(ThemeData theme, String label, IconData icon, Color color, VoidCallback onTap) {
    return TextButton.icon(onPressed: onTap, icon: Icon(icon, size: 16, color: color), label: Text(label, style: TextStyle(fontSize: 11, color: color)));
  }
}

class TerminalLoading extends StatefulWidget {
  const TerminalLoading({super.key});
  @override
  State<TerminalLoading> createState() => _TerminalLoadingState();
}

class _TerminalLoadingState extends State<TerminalLoading> with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;
  String _text = '';
  final String _targetText = '_> auralink_control';
  int _charIndex = 0;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true);
    _typingTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_charIndex < _targetText.length) {
        setState(() {
          _text += _targetText[_charIndex];
          _charIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_text, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.keyword)),
            FadeTransition(opacity: _cursorController, child: Container(width: 8, height: 20, color: AppColors.keyword)),
          ],
        ),
        const SizedBox(height: 15),
        const Text('loading...', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.comment)),
      ],
    );
  }
}
