// lib/features/home/dashboard_screen.dart
// Home dashboard: clean, modern, and fast to scan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/constants/item_types.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/add/screens/add_item_screen.dart';
import 'package:ironvault/features/categories/add_category_screen.dart';
import 'package:ironvault/features/categories/providers/category_provider.dart';
import 'package:ironvault/features/vault/screens/credential_list_screen.dart';
import 'package:ironvault/features/vault/screens/password_health_screen.dart';
import 'package:ironvault/features/vault/screens/view_credential_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class DashboardScreen extends ConsumerWidget {
  final bool showAppBar;

  const DashboardScreen({super.key, this.showAppBar = false});

  Future<List<Map<String, dynamic>>> _loadRecent(WidgetRef ref) async {
    final repo = ref.read(credentialRepoProvider);
    final all = await repo.getAllDecrypted();

    all.sort((a, b) {
      final aTime = a['updatedAt'] ?? a['createdAt'];
      final bTime = b['updatedAt'] ?? b['createdAt'];
      return bTime.toString().compareTo(aTime.toString());
    });

    return all.take(5).toList();
  }

  Future<Map<String, int>> _loadStats(WidgetRef ref) async {
    final repo = ref.read(credentialRepoProvider);
    final all = await repo.getAllDecrypted();
    final total = all.length;
    final favorites = all.where((e) => e['isFavorite'] == true).length;
    final passwordItems = all
        .where((e) => (e['type'] ?? 'password') == 'password')
        .toList();
    final weak = passwordItems.where((e) {
      final pwd = (e['password'] ?? '').toString();
      if (pwd.length < 10) return true;
      var categories = 0;
      if (RegExp(r'[a-z]').hasMatch(pwd)) categories++;
      if (RegExp(r'[A-Z]').hasMatch(pwd)) categories++;
      if (RegExp(r'[0-9]').hasMatch(pwd)) categories++;
      if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) categories++;
      return categories < 3;
    }).length;
    return {'total': total, 'favorites': favorites, 'weak': weak};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showAppBar ? AppBar(title: const Text('IronVault')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0D1B3D), const Color(0xFF0A1330)]
                      : [const Color(0xFF2563EB), const Color(0xFF4F8BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Vault Overview",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, int>>(
                    future: _loadStats(ref),
                    builder: (context, snapshot) {
                      final stats =
                          snapshot.data ??
                          {'total': 0, 'favorites': 0, 'weak': 0};
                      // final total = stats['total'] ?? 0;
                      return Row(
                        children: [
                          _StatPill(
                            label: 'Items',
                            value: stats['total']!.toString(),
                          ),
                          const SizedBox(width: 10),
                          _StatPill(
                            label: 'Favorites',
                            value: stats['favorites']!.toString(),
                          ),
                          const SizedBox(width: 10),
                          _StatPill(
                            label: 'Weak',
                            value: stats['weak']!.toString(),
                            color: const Color(0xFFFFC857),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PasswordHealthScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Password Health",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _SectionHeader(title: "Quick Add", icon: Icons.add_circle_outline),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _QuickActionMini(typeKey: 'password'),
                _QuickActionMini(typeKey: 'note'),
                _QuickActionMini(typeKey: 'card'),
                _QuickActionMini(typeKey: 'document'),
              ],
            ),

            const SizedBox(height: 22),

            _SectionHeader(title: "Categories", icon: Icons.folder_open),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == categories.length) {
                    return ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text("Add"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddCategoryScreen(),
                          ),
                        );
                      },
                    );
                  }

                  final c = categories[index];
                  return ActionChip(
                    label: Text(c.name),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CredentialListScreen(categoryFilter: c.name),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionHeader(title: "Recent", icon: Icons.history),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CredentialListScreen(),
                      ),
                    );
                  },
                  child: const Text("See all"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadRecent(ref),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No recent items")),
                  );
                }

                final items = snapshot.data!;
                return Column(
                  children: items
                      .map((item) => _RecentTile(item: item))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatPill({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionMini extends StatelessWidget {
  final String typeKey;

  const _QuickActionMini({required this.typeKey});

  @override
  Widget build(BuildContext context) {
    final def = typeByKey(typeKey);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddItemScreen(initialType: typeKey),
          ),
        );
      },
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                def.icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              def.label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _RecentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? 'Untitled';
    final subtitle = item['username'] ?? item['email'] ?? '';
    final typeKey = item['type'] ?? 'password';
    final typeDef = typeByKey(typeKey);
    final textMuted = AppThemeColors.textMuted(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ViewCredentialScreen(item: item)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                typeDef.icon,
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
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
