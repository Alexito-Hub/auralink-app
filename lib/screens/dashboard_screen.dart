import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/wol_service.dart';
import '../services/terminal_messenger.dart';
import '../core/theme/theme_manager.dart';
import '../core/theme/app_colors.dart';
import 'login_screen.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
    _scrollController.addListener(() {
      if (_scrollController.offset > 20 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 20 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('>_ auralink', 
          style: TextStyle(fontFamily: 'monospace', fontSize: 16, color: syntaxColor, fontWeight: FontWeight.bold)),
        backgroundColor: _isScrolled 
          ? theme.colorScheme.surface.withValues(alpha: 0.95) 
          : Colors.transparent,
        elevation: _isScrolled ? 4 : 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(themeManager.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 18),
            onPressed: () => themeManager.toggleTheme(!themeManager.isDarkMode),
          ),
          IconButton(onPressed: () {
            setState(() => _isLoading = true);
            _fetchData();
          }, icon: const Icon(Icons.refresh, size: 18)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout, size: 18)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: TerminalLoading())
        : _isOffline 
          ? _buildOfflineView(theme)
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
              children: [
                if (lidClosed) ...[
                  _buildLidWarning(theme),
                  const SizedBox(height: 10),
                ],
                _buildSectionTitle(theme, 'DEVICE_INFO'),
                const SizedBox(height: 10),
                _buildDeviceInfo(theme, isLaptop),
                const SizedBox(height: 25),
                _buildSectionTitle(theme, 'SYSTEM_RESOURCES'),
                const SizedBox(height: 10),
                _buildSystemGrid(theme),
                const SizedBox(height: 25),
                _buildSectionTitle(theme, 'BOOT_SELECT'),
                const SizedBox(height: 10),
                _buildBootSelection(theme),
                const SizedBox(height: 25),
                _buildSectionTitle(theme, 'AUDIO_CONFIG'),
                const SizedBox(height: 10),
                _buildVolumeControl(theme),
                const SizedBox(height: 20),
                _buildSectionTitle(theme, 'DISPLAY_CONFIG'),
                const SizedBox(height: 10),
                _buildBrightnessControl(theme),
                const SizedBox(height: 30),
                _buildPowerActions(theme),
                const SizedBox(height: 30),
                const Text('kernel-daemon v1.2.0', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.comment)),
              ],
            ),
    );
  }

  Widget _buildDeviceInfo(ThemeData theme, bool isLaptop) {
    final os = _sysInfo?['os'] ?? 'unknown';
    final mac = _sysInfo?['mac'] ?? '00:00:00:00:00:00';
    final uptime = _sysInfo?['uptime_seconds'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _infoRow('SYSTEM_OS', os.toString().toUpperCase(), icon: os == 'windows' ? Icons.window : Icons.terminal),
          const Divider(height: 15, thickness: 0.5),
          _infoRow('HARDWARE', isLaptop ? 'LAPTOP_UNIT' : 'DESKTOP_UNIT', icon: isLaptop ? Icons.laptop : Icons.desktop_windows),
          const Divider(height: 15, thickness: 0.5),
          _infoRow('NETWORK_MAC', mac, icon: Icons.lan),
          const Divider(height: 15, thickness: 0.5),
          _infoRow('UPTIME', '${(uptime / 3600).floor()}h ${((uptime % 3600) / 60).floor()}m', icon: Icons.timer_outlined),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) Icon(icon, size: 14, color: AppColors.comment),
        if (icon != null) const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.comment, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLidWarning(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TerminalMessenger.inlineBanner('LID_STATUS: CLOSED', 'Open lid to interact', isError: true),
    );
  }

  Widget _buildOfflineView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TerminalMessenger.inlineBanner('DAEMON_UNREACHABLE', 'System is offline or unreachable', isError: true),
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
                      TerminalMessenger.show(
                        context, 
                        result.message,
                        isSuccess: result.success,
                        isError: !result.success,
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
    return Row(
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
        const Expanded(child: Divider(indent: 10, thickness: 0.5, height: 1)),
      ],
    );
  }

  Widget _buildSystemGrid(ThemeData theme) {
    final cpu = _sysInfo?['cpu']?['percent'] ?? 0;
    final ram = _sysInfo?['ram']?['percent'] ?? 0;
    final bat = _sysInfo?['battery']?['percent'] ?? 0;
    final temp = _sysInfo?['temps']?['cpu'] ?? 0;
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
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
    return Row(
      children: [
        if (hasArch) _bootBtn(theme, 'arch_linux', 'arch', const Color(0xFF1793D1), currentOs == 'arch'),
        if (hasArch && hasWindows) const SizedBox(width: 10),
        if (hasWindows) _bootBtn(theme, 'windows_11', 'windows', Colors.blueAccent, currentOs == 'windows'),
      ],
    );
  }

  Widget _bootBtn(ThemeData theme, String label, String id, Color color, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onLongPress: isActive ? null : () async {
          HapticFeedback.heavyImpact();
          final res = await ApiService.instance.post('/boot/select', {'target': id});
          if (mounted) {
            TerminalMessenger.show(context, res.success ? 'BOOT_TARGET_SET: $id' : 'ERR: ${res.message}', isSuccess: res.success, isError: !res.success);
          }
        },
        child: OutlinedButton(
          onPressed: isActive ? null : () async {
            HapticFeedback.mediumImpact();
            TerminalMessenger.show(context, 'SWITCHING_OS: $id...', isSuccess: true);
            final res = await ApiService.instance.post('/boot/switch', {'target': id});
            if (mounted && !res.success) {
              TerminalMessenger.show(context, 'ERR: ${res.message}', isError: true);
            }
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

  Timer? _volumeDebounce;
  void _setVolume(double v) {
    setState(() => _volume = v);
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 300), () async {
      final res = await ApiService.instance.post('/system/volume', {'action': 'set', 'value': v.toInt()});
      if (!res.success && mounted) {
        TerminalMessenger.show(context, 'VOL_UPDATE_FAILED: ${res.message}', isError: true);
      }
    });
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
              onChanged: _setVolume,
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
          if (mac != null) {
            final res = await WolService.sendMagicPacket(mac);
            if (mounted) TerminalMessenger.show(context, res.message, isSuccess: res.success, isError: !res.success);
          } else {
            if (mounted) TerminalMessenger.show(context, 'ERR: NO_MAC_SAVED', isError: true);
          }
        }),
        _actionBtn(theme, 'sleepMode', Icons.bedtime_outlined, Colors.purpleAccent, () async {
          final res = await ApiService.instance.post('/system/sleep');
          if (mounted) TerminalMessenger.show(context, res.success ? 'SYSTEM_SLEEP_CMD_SENT' : 'ERR: ${res.message}', isSuccess: res.success, isError: !res.success);
        }),
        _actionBtn(theme, 'powerOff', Icons.power_settings_new, Colors.redAccent, () async {
          final res = await ApiService.instance.post('/system/shutdown');
          if (mounted) TerminalMessenger.show(context, res.success ? 'SYSTEM_SHUTDOWN_CMD_SENT' : 'ERR: ${res.message}', isSuccess: res.success, isError: !res.success);
        }),
        _actionBtn(theme, 'reboot', Icons.restart_alt, Colors.orangeAccent, () async {
          final res = await ApiService.instance.post('/system/reboot');
          if (mounted) TerminalMessenger.show(context, res.success ? 'SYSTEM_REBOOT_CMD_SENT' : 'ERR: ${res.message}', isSuccess: res.success, isError: !res.success);
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
