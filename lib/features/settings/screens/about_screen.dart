import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/core/update/app_update_service.dart';
import 'package:ironvault/core/update/update_prompt.dart';
import 'package:ironvault/features/settings/screens/privacy_policy_screen.dart';
import 'package:ironvault/features/settings/screens/security_tips_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  static const _updateCacheInstalledVersionKey =
      'update_cache_installed_version';

  String _version = '';
  late Future<AppUpdateCheckResult> _updateFuture;
  final SecureStorage _storage = SecureStorage();
  final AppUpdateService _updateService = AppUpdateService();

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _updateFuture = _updateService.checkForUpdateResult();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;

    final hasConnection = await _updateService.hasNetworkConnection();
    if (!mounted) return;
    if (!hasConnection) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('No internet connection'),
            content: const Text(
              'Connect to Wi-Fi or mobile data and try checking for updates again.',
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

    final result = await _updateService.checkForUpdateResult();
    if (!mounted) return;
    Navigator.pop(context);

    if (!result.success) {
      final failureMessage = result.offline
          ? 'Connect to Wi-Fi or mobile data and try again.'
          : 'IronVault could not reach GitHub right now. Please try again later.';
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text(
              result.offline ? 'No internet connection' : 'Update check failed',
            ),
            content: Text(failureMessage),
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

    final info = result.info;

    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersion = packageInfo.buildNumber.trim().isEmpty
        ? packageInfo.version.trim()
        : '${packageInfo.version.trim()}+${packageInfo.buildNumber.trim()}';

    await _storage.writeValue(
      'last_update_check',
      DateTime.now().toIso8601String(),
    );
    await _storage.writeValue('update_available', info != null ? 'true' : 'false');
    await _storage.writeValue('update_version', info?.latestVersion ?? '');
    await _storage.writeValue(
      _updateCacheInstalledVersionKey,
      installedVersion,
    );
    if (!mounted) return;

    setState(() {
      _updateFuture = Future.value(
        AppUpdateCheckResult(info: info, success: true),
      );
    });

    if (info == null) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Up to date'),
            content: const Text('You already have the latest version.'),
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

    UpdatePrompt.show(context, info);
  }

  Future<void> _reportIssue() async {
    final autoLock = ref.read(autoLockProvider.notifier);
    autoLock.suspendAutoLock();
    try {
      const url = 'https://github.com/r6rizwan/IronVault/issues';
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } finally {
      autoLock.resumeAutoLock();
    }
  }

  Future<void> _openGitHub() async {
    final autoLock = ref.read(autoLockProvider.notifier);
    autoLock.suspendAutoLock();
    try {
      const url = 'https://github.com/r6rizwan/IronVault';
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } finally {
      autoLock.resumeAutoLock();
    }
  }

  Future<void> _shareApp() async {
    final autoLock = ref.read(autoLockProvider.notifier);
    autoLock.suspendAutoLock();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Try IronVault, a private offline vault for Android: https://github.com/r6rizwan/IronVault/releases/latest',
        ),
      );
    } finally {
      autoLock.resumeAutoLock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = AppThemeColors.textMuted(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _heroCard(context, textMuted, primary),
          const SizedBox(height: 18),
          _sectionCard(
            context,
            title: 'About the App',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _BulletLine(
                  text:
                      'Store passwords, cards, notes, bank details, and documents in one place.',
                ),
                SizedBox(height: 8),
                _BulletLine(
                  text:
                      'Unlock your vault with your PIN and use biometrics if you enable them.',
                ),
                SizedBox(height: 8),
                _BulletLine(
                  text:
                      'Keep important information private on your device.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            title: 'Privacy and Recovery',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _BulletLine(text: 'Your data stays on your device.'),
                SizedBox(height: 8),
                _BulletLine(text: 'IronVault does not use cloud sync.'),
                SizedBox(height: 8),
                _BulletLine(
                  text:
                      'Keep your recovery key somewhere safe. If you lose both your PIN and recovery key, your data cannot be recovered.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            title: 'Resources',
            child: Column(
              children: [
                _actionTile(
                  context,
                  icon: Icons.security_outlined,
                  title: 'Security Tips',
                  subtitle: 'Learn how to keep your vault safer',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SecurityTipsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                FutureBuilder<AppUpdateCheckResult>(
                  future: _updateFuture,
                  builder: (context, snapshot) {
                    final result = snapshot.data;
                    final info = result?.info;
                    final status = snapshot.connectionState == ConnectionState.waiting
                        ? _statusChip(context, 'Checking...', false)
                        : result?.success == false
                        ? _statusChip(context, 'Check failed', false)
                        : _statusChip(
                            context,
                            info == null ? 'Up to date' : 'Update available',
                            info != null,
                          );

                    return _actionTile(
                      context,
                      icon: Icons.system_update_alt_outlined,
                      title: 'Check for Updates',
                      subtitle: 'See if a newer version is available',
                      status: status,
                      onTap: _checkForUpdates,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _actionTile(
                  context,
                  icon: Icons.share_outlined,
                  title: 'Share App',
                  subtitle: 'Send the app link to someone else',
                  onTap: _shareApp,
                ),
                const SizedBox(height: 10),
                _actionTile(
                  context,
                  icon: Icons.code_outlined,
                  title: 'GitHub',
                  subtitle: 'Open the project repository',
                  onTap: _openGitHub,
                ),
                const SizedBox(height: 10),
                _actionTile(
                  context,
                  icon: Icons.bug_report_outlined,
                  title: 'Report an Issue',
                  subtitle: 'Open the issue tracker in your browser',
                  onTap: _reportIssue,
                ),
                const SizedBox(height: 10),
                _actionTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'See how the app handles your data',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(
    BuildContext context,
    Color textMuted,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Icon(Icons.shield_outlined, size: 34, color: primary),
          ),
          const SizedBox(height: 12),
          Text(
            'IronVault',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Offline-first. Encrypted. Yours.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textMuted),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _version.isEmpty ? 'Version' : 'Version $_version',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? status,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle),
                    if (status != null) ...[
                      const SizedBox(height: 10),
                      status,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right,
                  color: AppThemeColors.textMuted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String text, bool highlight) {
    final color = highlight
        ? Theme.of(context).colorScheme.primary
        : AppThemeColors.textMuted(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45)),
        ),
      ],
    );
  }
}
