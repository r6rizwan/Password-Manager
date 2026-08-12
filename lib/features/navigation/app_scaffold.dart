import 'package:flutter/material.dart';
import '../home/dashboard_screen.dart';
import '../search/search_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../vault/screens/credential_list_screen.dart';
import '../add/screens/add_item_screen.dart';
import '../categories/categories_screen.dart';
import 'package:ironvault/core/update/app_update_service.dart';
import 'package:ironvault/core/update/update_prompt.dart';
import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'package:ironvault/features/auth/screens/welcome_screen.dart';
import 'package:ironvault/features/auth/screens/recovery_key_screen.dart';

enum AppPage { home, vault, settings }

class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  AppPage _currentPage = AppPage.home;
  DateTime? _lastBackPress;
  OverlayEntry? _exitToast;
  final GlobalKey<CredentialListScreenState> _vaultKey =
      GlobalKey<CredentialListScreenState>();
  final SecureStorage _storage = SecureStorage();
  final AppUpdateService _updateService = AppUpdateService();
  bool _updateAvailable = false;
  String? _updateVersion;
  bool _checkingUpdate = false;
  static const _updateCacheInstalledVersionKey =
      'update_cache_installed_version';

  @override
  void dispose() {
    _exitToast?.remove();
    _exitToast = null;
    super.dispose();
  }

  Future<_PendingRecoveryKeyStatus> _readPendingRecoveryKeyStatus() async {
    final confirmed = await RecoveryKeyUtil.isConfirmed(_storage);
    if (confirmed) {
      return const _PendingRecoveryKeyStatus();
    }
    final key = await RecoveryKeyUtil.readPendingKey(_storage);
    final hasPendingState = await RecoveryKeyUtil.hasPendingState(_storage);
    return _PendingRecoveryKeyStatus(
      key: key,
      hasPendingState: hasPendingState,
      unreadable: hasPendingState && (key == null || key.isEmpty),
    );
  }

  Future<void> _openPendingRecoveryKey(BuildContext context, String key) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecoveryKeyScreen(
          recoveryKey: key,
          doneLabel: 'I have saved it',
          onDone: () => Navigator.pop(context),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showPendingRecoveryKeyIssue(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recovery Key Needs Attention'),
        content: const Text(
          'IronVault knows there is a recovery key reminder pending, but it cannot be opened from the current app state. Please verify your vault access and create a new recovery key if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        _checkForUpdatesIfNeeded();
      });
    });
  }

  Future<void> _checkForUpdatesIfNeeded() async {
    if (_checkingUpdate) return;
    _checkingUpdate = true;

    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersion = packageInfo.buildNumber.trim().isEmpty
        ? packageInfo.version.trim()
        : '${packageInfo.version.trim()}+${packageInfo.buildNumber.trim()}';
    final last = await _storage.readValue('last_update_check');
    final cachedAvailable = await _storage.readValue('update_available');
    final cachedVersion = await _storage.readValue('update_version');
    final cachedForInstalledVersion = await _storage.readValue(
      _updateCacheInstalledVersionKey,
    );

    if (cachedForInstalledVersion != installedVersion) {
      _updateAvailable = false;
      _updateVersion = null;
      await _storage.writeValue('update_available', 'false');
      await _storage.writeValue('update_version', '');
      await _storage.writeValue(
        _updateCacheInstalledVersionKey,
        installedVersion,
      );
    } else if (last != null) {
      final lastTime = DateTime.tryParse(last);
      if (lastTime != null &&
          DateTime.now().difference(lastTime).inHours < 12) {
        _updateAvailable = cachedAvailable == 'true';
        _updateVersion = cachedVersion;
        if (mounted) setState(() {});
        _checkingUpdate = false;
        return;
      }
    }

    final result = await _updateService.checkForUpdateResult();
    if (!result.success) {
      _checkingUpdate = false;
      return;
    }

    _updateAvailable = result.info != null;
    _updateVersion = result.info?.latestVersion;

    await _storage.writeValue(
      'last_update_check',
      DateTime.now().toIso8601String(),
    );
    await _storage.writeValue(
      'update_available',
      _updateAvailable ? 'true' : 'false',
    );
    await _storage.writeValue('update_version', _updateVersion ?? '');
    await _storage.writeValue(
      _updateCacheInstalledVersionKey,
      installedVersion,
    );

    if (mounted) setState(() {});
    _checkingUpdate = false;
  }

  Future<void> _refreshCachedUpdateStatus() async {
    final cachedAvailable = await _storage.readValue('update_available');
    final cachedVersion = await _storage.readValue('update_version');
    final nextAvailable = cachedAvailable == 'true';
    final nextVersion = (cachedVersion == null || cachedVersion.isEmpty)
        ? null
        : cachedVersion;

    if (_updateAvailable == nextAvailable && _updateVersion == nextVersion) {
      return;
    }

    _updateAvailable = nextAvailable;
    _updateVersion = nextVersion;
    if (mounted) setState(() {});
  }

  int _indexForPage(AppPage page) {
    switch (page) {
      case AppPage.home:
        return 0;
      case AppPage.vault:
        return 1;
      case AppPage.settings:
        return 2;
    }
  }

  AppPage _pageForIndex(int index) {
    switch (index) {
      case 0:
        return AppPage.home;
      case 1:
        return AppPage.vault;
      case 2:
        return AppPage.settings;
      default:
        return AppPage.home;
    }
  }

  String _titleForPage(AppPage page) {
    switch (page) {
      case AppPage.home:
        return 'IronVault';
      case AppPage.vault:
        return 'Vault';
      case AppPage.settings:
        return 'Settings';
    }
  }

  List<Widget> _actionsForPage(BuildContext context, AppPage page) {
    if (page == AppPage.vault) {
      return [
        IconButton(
          icon: const Icon(Icons.swap_vert_rounded),
          tooltip: "Sort",
          onPressed: () => _vaultKey.currentState?.openSortSheetFromParent(),
        ),
        IconButton(
          icon: const Icon(Icons.folder),
          tooltip: "Categories",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            );
          },
        ),
      ];
    }
    if (page == AppPage.home) {
      return [
        FutureBuilder<_PendingRecoveryKeyStatus>(
          future: _readPendingRecoveryKeyStatus(),
          builder: (context, snapshot) {
            final status = snapshot.data;
            if (status == null || !status.hasPendingState) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
              ),
              tooltip: 'Recovery key not confirmed yet',
              onPressed: () {
                final pendingKey = status.key;
                if (pendingKey != null && pendingKey.isNotEmpty) {
                  _openPendingRecoveryKey(context, pendingKey);
                  return;
                }
                _showPendingRecoveryKeyIssue(context);
              },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: "Search",
          onPressed: () => _showSearchSheet(context),
        ),
        IconButton(
          icon: const Icon(Icons.lock_outline),
          tooltip: "Lock now",
          onPressed: () {
            ref.read(autoLockProvider.notifier).lockNow();
            navKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const WelcomeScreen(),
                settings: const RouteSettings(name: WelcomeScreen.routeName),
              ),
              (_) => false,
            );
          },
        ),
      ];
    }
    return const [];
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, controller) => Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Expanded(
                    child: SearchScreen(showAppBar: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddItem({String? typeKey}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemScreen(initialType: typeKey),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _indexForPage(_currentPage) == index;
    return _NavItem(
      icon: icon,
      label: label,
      selected: selected,
      onTap: () async {
        await _refreshCachedUpdateStatus();
        if (!mounted) return;
        setState(() => _currentPage = _pageForIndex(index));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFBFD0F2).withValues(alpha: 0.85);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          _showExitToast(context);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: Text(_titleForPage(_currentPage)),
          actions: [
            ..._actionsForPage(context, _currentPage),
            if (_updateAvailable)
              IconButton(
                tooltip:
                    'Update available${_updateVersion != null ? ' (${AppUpdateService.displayVersion(_updateVersion!)})' : ''}',
                icon: const Icon(Icons.system_update_alt),
                onPressed: () async {
                  final ctx = context;
                  final hasConnection = await _updateService
                      .hasNetworkConnection();
                  if (!mounted || !ctx.mounted) return;
                  if (!hasConnection) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No internet connection. Connect to Wi-Fi or mobile data and try again.',
                        ),
                      ),
                    );
                    return;
                  }
                  final result = await _updateService.checkForUpdateResult();
                  if (!mounted || !ctx.mounted) return;
                  if (!result.success) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.offline
                              ? 'No internet connection. Connect to Wi-Fi or mobile data and try again.'
                              : 'Could not check for updates right now.',
                        ),
                      ),
                    );
                    return;
                  }
                  final info = result.info;
                  if (info != null) {
                    _updateAvailable = true;
                    _updateVersion = info.latestVersion;
                    await _storage.writeValue(
                      'last_update_check',
                      DateTime.now().toIso8601String(),
                    );
                    await _storage.writeValue('update_available', 'true');
                    await _storage.writeValue(
                      'update_version',
                      info.latestVersion,
                    );
                    final packageInfo = await PackageInfo.fromPlatform();
                    final installedVersion =
                        packageInfo.buildNumber.trim().isEmpty
                        ? packageInfo.version.trim()
                        : '${packageInfo.version.trim()}+${packageInfo.buildNumber.trim()}';
                    await _storage.writeValue(
                      _updateCacheInstalledVersionKey,
                      installedVersion,
                    );
                    if (mounted) setState(() {});
                    if (!ctx.mounted) return;
                    await UpdatePrompt.show(ctx, info);
                  } else {
                    _updateAvailable = false;
                    _updateVersion = null;
                    await _storage.writeValue(
                      'last_update_check',
                      DateTime.now().toIso8601String(),
                    );
                    await _storage.writeValue('update_available', 'false');
                    await _storage.writeValue('update_version', '');
                    final packageInfo = await PackageInfo.fromPlatform();
                    final installedVersion =
                        packageInfo.buildNumber.trim().isEmpty
                        ? packageInfo.version.trim()
                        : '${packageInfo.version.trim()}+${packageInfo.buildNumber.trim()}';
                    await _storage.writeValue(
                      _updateCacheInstalledVersionKey,
                      installedVersion,
                    );
                    if (mounted) setState(() {});
                  }
                },
              ),
          ],
        ),
        body: IndexedStack(
          index: _indexForPage(_currentPage),
          children: [
            const DashboardScreen(showAppBar: false),
            CredentialListScreen(key: _vaultKey, showAppBar: false),
            const SettingsScreen(showAppBar: false),
          ],
        ),
        floatingActionButton: _currentPage == AppPage.settings
            ? null
            : FloatingActionButton(
                heroTag: null,
                tooltip: 'Add item',
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 6,
                onPressed: () => _openAddItem(),
                child: const Icon(Icons.add, size: 26),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: navBorderColor, width: 2.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        index: 0,
                      ),
                      _navItem(
                        icon: Icons.lock_rounded,
                        label: 'Vault',
                        index: 1,
                      ),
                      _navItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        index: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showExitToast(BuildContext context) {
    _exitToast?.remove();
    _exitToast = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 16,
        right: 16,
        bottom: 90,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Text('Press back again to exit'),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_exitToast!);
    Future.delayed(const Duration(seconds: 2), () {
      _exitToast?.remove();
      _exitToast = null;
    });
  }
}

class _PendingRecoveryKeyStatus {
  final String? key;
  final bool hasPendingState;
  final bool unreadable;

  const _PendingRecoveryKeyStatus({
    this.key,
    this.hasPendingState = false,
    this.unreadable = false,
  });
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.6);
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : (muted ?? Colors.grey.shade500);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
