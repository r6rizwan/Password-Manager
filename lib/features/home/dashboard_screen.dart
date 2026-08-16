// lib/features/home/dashboard_screen.dart
// Home dashboard: clean, modern, and fast to scan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:ironvault/core/constants/item_types.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/add/screens/add_item_screen.dart';
import 'package:ironvault/features/categories/add_category_screen.dart';
import 'package:ironvault/features/categories/categories_screen.dart';
import 'package:ironvault/features/categories/providers/category_provider.dart';
import 'package:ironvault/features/vault/screens/credential_list_screen.dart';
import 'package:ironvault/features/vault/screens/password_health_screen.dart';
import 'package:ironvault/features/vault/screens/view_credential_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

final dashboardItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(vaultRefreshProvider);
  final repo = ref.read(credentialRepoProvider);
  return repo.getAllDecrypted();
});

class DashboardScreen extends ConsumerWidget {
  final bool showAppBar;

  const DashboardScreen({super.key, this.showAppBar = false});

  List<Map<String, dynamic>> _recentItems(List<Map<String, dynamic>> all) {
    final sorted = [...all];
    sorted.sort((a, b) {
      final aTime = a['updatedAt'] ?? a['createdAt'];
      final bTime = b['updatedAt'] ?? b['createdAt'];
      return bTime.toString().compareTo(aTime.toString());
    });

    return sorted.take(5).toList();
  }

  Map<String, int> _statsForItems(List<Map<String, dynamic>> all) {
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

  Map<String, int> _categoryCountsForItems(List<Map<String, dynamic>> all) {
    final counts = <String, int>{};
    all.sort((a, b) {
      return 0;
    });
    for (final item in all) {
      final raw = (item['category'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      counts[raw] = (counts[raw] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemsAsync = ref.watch(dashboardItemsProvider);

    return Scaffold(
      backgroundColor: showAppBar
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.transparent,
      appBar: showAppBar ? AppBar(title: const Text('IronVault')) : null,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A2330), const Color(0xFF141B26)]
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
                  itemsAsync.when(
                    data: (allItems) {
                      final stats = _statsForItems(allItems);
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
                            color: const Color(0xFFF59E0B),
                          ),
                        ],
                      );
                    },
                    loading: () => const Row(
                      children: [
                        _StatPillSkeleton(),
                        SizedBox(width: 10),
                        _StatPillSkeleton(),
                        SizedBox(width: 10),
                        _StatPillSkeleton(),
                      ],
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PasswordHealthScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.health_and_safety_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Open Password Health",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Review weak, reused, and old passwords.",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white70,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _SectionHeader(title: "Quick Add", icon: Icons.add_circle_outline),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _QuickActionChip(typeKey: 'password'),
                  SizedBox(width: 10),
                  _QuickActionChip(typeKey: 'note'),
                  SizedBox(width: 10),
                  _QuickActionChip(typeKey: 'card'),
                  SizedBox(width: 10),
                  _QuickActionChip(typeKey: 'document'),
                ],
              ),
            ),

            const SizedBox(height: 22),

            _SectionHeader(
              title: "Categories",
              icon: Icons.folder_open,
              trailing: ActionChip(
                avatar: const Icon(Icons.apps, size: 16),
                label: const Text("All"),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoriesScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            itemsAsync.when(
              data: (allItems) {
                final counts = _categoryCountsForItems(allItems);
                final topCategories = [...categories]
                  ..sort((a, b) {
                    final ac = counts[a.name] ?? 0;
                    final bc = counts[b.name] ?? 0;
                    if (ac != bc) return bc.compareTo(ac);
                    return a.name.compareTo(b.name);
                  });
                final shown = topCategories.take(5).toList();

                return SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: shown.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      if (index == shown.length) {
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text("Add"),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
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

                      final c = shown[index];
                      return ActionChip(
                        label: Text(c.name),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
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
                );
              },
              loading: () => SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => const _ChipSkeleton(width: 108),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
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
            itemsAsync.when(
              data: (allItems) {
                if (allItems.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No recent items")),
                  );
                }
                final items = _recentItems(allItems);
                return Column(
                  children: items.map((item) => _RecentTile(item: item)).toList(),
                );
              },
              loading: () => const Column(
                children: [
                  _RecentTileSkeleton(),
                  _RecentTileSkeleton(),
                  _RecentTileSkeleton(),
                ],
              ),
              error: (_, __) => const SizedBox.shrink(),
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

class _StatPillSkeleton extends StatelessWidget {
  const _StatPillSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _SkeletonBox(width: 84, height: 34, radius: 999);
  }
}

class _QuickActionChip extends StatelessWidget {
  final String typeKey;

  const _QuickActionChip({required this.typeKey});

  @override
  Widget build(BuildContext context) {
    final def = typeByKey(typeKey);
    return ActionChip(
      avatar: Icon(
        def.icon,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: Text(def.label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddItemScreen(initialType: typeKey),
          ),
        );
      },
    );
  }
}

class _RecentTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _RecentTile({required this.item});

  String _subtitleForItem(Map<String, dynamic> item) {
    final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
    if (item['type'] == 'password') {
      return (fields['username'] ?? item['username'] ?? '').toString();
    }
    if (item['type'] == 'card') {
      final number = (fields['number'] ?? '').toString().replaceAll(' ', '');
      if (number.isEmpty) return 'Card ••••';
      final last4 = number.length >= 4 ? number.substring(number.length - 4) : number;
      return 'Card •••• $last4';
    }
    if (item['type'] == 'bank') {
      final acct = (fields['account_number'] ?? '').toString().replaceAll(' ', '');
      if (acct.isEmpty) return 'Bank account';
      final last4 = acct.length >= 4 ? acct.substring(acct.length - 4) : acct;
      return 'A/C •••• $last4';
    }
    if (item['type'] == 'document') {
      final documentId = (fields['document_id'] ?? '').toString().trim();
      if (documentId.isNotEmpty) {
        return 'ID: $documentId';
      }

      final notes = (fields['notes'] ?? '').toString().trim();
      if (notes.isNotEmpty) {
        return notes;
      }

      final rawScans = (fields['scans'] ?? '').toString().trim();
      if (rawScans.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawScans);
          if (decoded is List) {
            final count = decoded.length;
            if (count > 0) {
              return count == 1 ? '1 scanned page' : '$count scanned pages';
            }
          }
        } catch (_) {}
      }

      return 'Saved document';
    }
    for (final v in fields.values) {
      final text = v?.toString() ?? '';
      if (text.trim().isNotEmpty) return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? 'Untitled';
    final subtitle = _subtitleForItem(item);
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
                  if (subtitle.toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
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

class _RecentTileSkeleton extends StatelessWidget {
  const _RecentTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: const Row(
        children: [
          _SkeletonBox(width: 40, height: 40, radius: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: 8),
                _SkeletonBox(width: 120, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkeletonBox(width: 18, height: 18, radius: 9),
        ],
      ),
    );
  }
}

class _ChipSkeleton extends StatelessWidget {
  final double width;

  const _ChipSkeleton({required this.width});

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(width: width, height: 38, radius: 24);
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

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
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}
