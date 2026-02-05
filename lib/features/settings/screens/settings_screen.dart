// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/theme/theme_provider.dart';
import 'package:ironvault/features/settings/about_screen.dart';
import 'package:ironvault/features/settings/security_tips_screen.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/vault/screens/password_health_screen.dart';
import 'change_pin_screen.dart';
import 'package:ironvault/features/auth/screens/login_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ironvault/core/update/app_update_service.dart';
import 'package:ironvault/core/update/update_prompt.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
import 'package:ironvault/features/auth/screens/recovery_key_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const SettingsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _lockOnSwitch = true;
  bool _autofillEnabled = true;
  bool _hasRecoveryKey = true;
  late final String _securityTip;

  static const List<String> _securityTips = [
    'Use a unique master PIN and avoid easy patterns.',
    'Save your recovery key somewhere secure and offline.',
    'Enable biometrics for faster and safer unlocks.',
    'Review Password Health regularly to spot weak entries.',
    'Turn on autofill to avoid copying passwords manually.',
  ];

  @override
  void initState() {
    super.initState();
    _securityTip =
        _securityTips[DateTime.now().microsecondsSinceEpoch %
            _securityTips.length];
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(secureStorageProvider);

    _biometricEnabled =
        (await storage.readValue("biometrics_enabled") ?? "false") == "true";
    _lockOnSwitch =
        (await storage.readValue("auto_lock_on_switch") ?? "true") == "true";
    _autofillEnabled =
        (await storage.readValue("autofill_enabled") ?? "true") == "true";
    _hasRecoveryKey = (await storage.readRecoveryKeyHash()) != null;

    if (mounted) setState(() {});
  }

  Future<void> _toggleBiometrics(bool value) async {
    final storage = ref.read(secureStorageProvider);
    final auth = LocalAuthentication();

    if (value) {
      final ok = await auth.authenticate(
        localizedReason: "Enable biometrics for IronVault",
        biometricOnly: true,
      );
      if (!ok) return;
      await storage.writeValue("biometrics_enabled", "true");
    } else {
      await storage.writeValue("biometrics_enabled", "false");
    }

    if (mounted) setState(() => _biometricEnabled = value);
  }

  Future<void> _toggleTheme(bool value) async {
    await ref
        .read(themeModeProvider.notifier)
        .setTheme(value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _toggleLockOnSwitch(bool value) async {
    await ref.read(autoLockProvider.notifier).setLockOnSwitch(value);
    if (mounted) setState(() => _lockOnSwitch = value);
  }

  Future<void> _toggleAutofill(bool value) async {
    final storage = ref.read(secureStorageProvider);
    await storage.writeValue('autofill_enabled', value ? 'true' : 'false');
    if (mounted) setState(() => _autofillEnabled = value);

    try {
      const intent = MethodChannel('ironvault/autofill');
      await intent.invokeMethod('openAutofillSettings');
    } catch (_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Autofill settings'),
            content: const Text(
              'Please enable IronVault in Android Settings → Autofill.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _setupRecoveryKey() async {
    final storage = ref.read(secureStorageProvider);
    final key = RecoveryKeyUtil.generate();
    await storage.writeRecoveryKeyHash(RecoveryKeyUtil.hash(key));
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecoveryKeyScreen(
          recoveryKey: key,
          doneLabel: 'Done',
          onDone: () => Navigator.pop(context),
        ),
      ),
    );

    if (mounted) setState(() => _hasRecoveryKey = true);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkTheme = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text("Settings")) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 4),

          _settingsHeader(context),

          _sectionTitle("Security"),

          if (!_hasRecoveryKey)
            _settingsTile(
              context,
              icon: Icons.vpn_key_outlined,
              title: "Set up Recovery Key",
              onTap: _setupRecoveryKey,
              trailing: const Icon(Icons.chevron_right),
            ),

          _settingsTile(
            context,
            icon: Icons.password,
            title: "Change Master PIN",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePinScreen()),
              );
            },
          ),

          _switchTile(
            context,
            icon: Icons.fingerprint,
            title: "Enable Biometrics",
            subtitle: "Use fingerprint/face unlock",
            value: _biometricEnabled,
            onChanged: _toggleBiometrics,
          ),

          _autoLockTile(context, ref),

          _settingsTile(
            context,
            icon: Icons.health_and_safety,
            title: "Password Health",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PasswordHealthScreen()),
              );
            },
          ),

          const SizedBox(height: 20),
          _sectionTitle("Preferences"),

          _switchTile(
            context,
            icon: Icons.dark_mode,
            title: "Dark Mode",
            subtitle: "Use dark theme",
            value: isDarkTheme,
            onChanged: _toggleTheme,
          ),

          _switchTile(
            context,
            icon: Icons.lock_outline,
            title: "Lock on App Switch",
            subtitle: "Auto-lock when app goes to background",
            value: _lockOnSwitch,
            onChanged: _toggleLockOnSwitch,
          ),

          _switchTile(
            context,
            icon: Icons.autofps_select,
            title: "Autofill Service",
            subtitle: "Enable Android Autofill (system setting required)",
            value: _autofillEnabled,
            onChanged: _toggleAutofill,
          ),

          _settingsTile(
            context,
            icon: Icons.system_update_alt,
            title: "Check for Updates",
            onTap: () async {
              if (!context.mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) {
                  return const AlertDialog(
                    title: Text('Checking for updates'),
                    content: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Please wait...'),
                      ],
                    ),
                  );
                },
              );

              final info = await AppUpdateService().checkForUpdate();
              if (!context.mounted) return;
              Navigator.pop(context);

              if (info == null) {
                showDialog(
                  context: context,
                  builder: (_) {
                    return AlertDialog(
                      title: const Text('No update found'),
                      content: const Text(
                        'You already have the latest version.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
                return;
              }

              showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text('Found one update'),
                    content: Text(
                      'Version ${info.latestVersion} is available.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Not now'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          UpdatePrompt.show(context, info);
                        },
                        child: const Text('Download'),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 20),
          _sectionTitle("Help & Info"),

          _settingsTile(
            context,
            icon: Icons.security,
            title: "Security Tips",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecurityTipsScreen()),
              );
            },
          ),

          _settingsTile(
            context,
            icon: Icons.info_outline,
            title: "About",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),

          _settingsTile(
            context,
            icon: Icons.bug_report_outlined,
            title: "Report an Issue",
            onTap: () async {
              const url = 'https://github.com/r6rizwan/Password-Manager/issues';
              final uri = Uri.parse(url);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text("Logout", style: TextStyle(fontSize: 16)),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _settingsHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.shield_moon_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'IronVault',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your vault is protected and ready.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecurityTipsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Security tip: $_securityTip',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(title),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }

  // AUTO-LOCK TIMER TILE
  Widget _autoLockTile(BuildContext context, WidgetRef ref) {
    return _settingsTile(
      context,
      icon: Icons.lock_clock,
      title: "Auto-lock Timer",
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        showModalBottomSheet(
          context: context,
          builder: (_) => const _AutoLockSheet(),
        );
      },
    );
  }
}

class _AutoLockSheet extends ConsumerWidget {
  const _AutoLockSheet();

  static const options = {
    "immediately": "Immediately",
    "10": "After 10 seconds",
    "30": "After 30 seconds",
    "60": "After 1 minute",
    "300": "After 5 minutes",
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(secureStorageProvider).readValue("auto_lock_timer"),
      builder: (context, snapshot) {
        final selected = snapshot.data ?? "immediately";

        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                "Auto-lock Timer",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),

              ...options.entries.map((entry) {
                final key = entry.key;
                final label = entry.value;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    key == selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(label),
                  onTap: () async {
                    await ref
                        .read(secureStorageProvider)
                        .writeValue("auto_lock_timer", key);

                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
