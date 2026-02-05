import 'package:flutter/material.dart';
import '../home/dashboard_screen.dart';
import '../search/search_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../vault/screens/credential_list_screen.dart';
import '../add/screens/add_item_screen.dart';
import '../categories/categories_screen.dart';
import 'package:ironvault/core/update/app_update_service.dart';
import 'package:ironvault/core/update/update_prompt.dart';
import 'package:flutter/services.dart';

enum AppPage { home, vault, search, settings }

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  AppPage _currentPage = AppPage.home;
  bool _checkedUpdate = false;
  DateTime? _lastBackPress;
  OverlayEntry? _exitToast;

  int _indexForPage(AppPage page) {
    switch (page) {
      case AppPage.home:
        return 0;
      case AppPage.vault:
        return 1;
      case AppPage.search:
        return 2;
      case AppPage.settings:
        return 3;
    }
  }

  AppPage _pageForIndex(int index) {
    switch (index) {
      case 0:
        return AppPage.home;
      case 1:
        return AppPage.vault;
      case 2:
        return AppPage.search;
      case 3:
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
      case AppPage.search:
        return 'Search';
      case AppPage.settings:
        return 'Settings';
    }
  }

  List<Widget> _actionsForPage(BuildContext context, AppPage page) {
    if (page != AppPage.vault) return const [];
    return [
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
      onTap: () => setState(() => _currentPage = _pageForIndex(index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedUpdate) {
      _checkedUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final info = await AppUpdateService().checkForUpdate();
        if (info != null && mounted) {
          await UpdatePrompt.show(context, info);
        }
      });
    }

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
        appBar: AppBar(
          title: Text(_titleForPage(_currentPage)),
          actions: _actionsForPage(context, _currentPage),
        ),
        body: IndexedStack(
          index: _indexForPage(_currentPage),
          children: const [
            DashboardScreen(showAppBar: false),
            CredentialListScreen(showAppBar: false),
            SearchScreen(showAppBar: false),
            SettingsScreen(showAppBar: false),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'global_add_fab',
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 6,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddItemScreen()),
            );
          },
          child: const Icon(Icons.add, size: 26),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
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
                _navItem(icon: Icons.home_rounded, label: 'Home', index: 0),
                _navItem(icon: Icons.lock_rounded, label: 'Vault', index: 1),
                const SizedBox(width: 46),
                _navItem(icon: Icons.search_rounded, label: 'Search', index: 2),
                _navItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  index: 3,
                ),
              ],
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
