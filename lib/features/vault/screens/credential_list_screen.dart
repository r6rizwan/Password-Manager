// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/categories/categories_screen.dart';
import 'package:ironvault/core/constants/item_types.dart';
import 'view_credential_screen.dart';
import 'package:ironvault/features/vault/providers/search_provider.dart';
import 'package:ironvault/core/widgets/search_bar.dart';

enum SortOption { favoritesFirst, aToZ, zToA, recentAdded, recentUpdated }

class CredentialListScreen extends ConsumerStatefulWidget {
  final String? categoryFilter;
  final bool showAppBar;

  const CredentialListScreen({
    super.key,
    this.categoryFilter,
    this.showAppBar = true,
  });

  @override
  ConsumerState<CredentialListScreen> createState() =>
      _CredentialListScreenState();
}

class _CredentialListScreenState extends ConsumerState<CredentialListScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  SortOption _sortBy = SortOption.favoritesFirst;

  final searchController = TextEditingController();

  /// ⭐ GLOBAL KEY to control the search bar (expand/collapse)
  final GlobalKey<IronSearchBarState> _searchBarKey =
      GlobalKey<IronSearchBarState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchQueryProvider.notifier).state = "";
    });
    _loadCredentials();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    setState(() => _loading = true);

    final repo = ref.read(credentialRepoProvider);
    final data = await repo.getAllDecrypted();

    _items = data;
    _applySorting();

    setState(() => _loading = false);
  }

  void _applySorting() {
    switch (_sortBy) {
      case SortOption.favoritesFirst:
        _items.sort((a, b) {
          final favA = a["isFavorite"] == true;
          final favB = b["isFavorite"] == true;
          if (favA && !favB) return -1;
          if (!favA && favB) return 1;
          return a["title"].toLowerCase().compareTo(b["title"].toLowerCase());
        });
        break;

      case SortOption.aToZ:
        _items.sort(
          (a, b) =>
              a["title"].toLowerCase().compareTo(b["title"].toLowerCase()),
        );
        break;

      case SortOption.zToA:
        _items.sort(
          (a, b) =>
              b["title"].toLowerCase().compareTo(a["title"].toLowerCase()),
        );
        break;

      case SortOption.recentAdded:
        _items.sort((a, b) => b["createdAt"].compareTo(a["createdAt"]));
        break;

      case SortOption.recentUpdated:
        _items.sort((a, b) => b["updatedAt"].compareTo(a["updatedAt"]));
        break;
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final repo = ref.read(credentialRepoProvider);
    final newState = !(item["isFavorite"] == true);

    await repo.toggleFavorite(item["id"], newState);
    await _loadCredentials();
  }

  String _subtitleForItem(Map<String, dynamic> item) {
    final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
    if (item['type'] == 'password') {
      return (fields['username'] ?? item['username'] ?? '').toString();
    }
    for (final v in fields.values) {
      final text = v?.toString() ?? '';
      if (text.trim().isNotEmpty) return text;
    }
    return '';
  }

  void _openSortSheet() {
    _searchBarKey.currentState
        ?.collapse(); // also collapse search when opening sheet

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              _buildSortTile(
                ctx,
                "Favorites First",
                SortOption.favoritesFirst,
                Icons.star,
                Colors.amber,
              ),
              _buildSortTile(
                ctx,
                "A → Z",
                SortOption.aToZ,
                Icons.sort_by_alpha,
                Colors.blue,
              ),
              _buildSortTile(
                ctx,
                "Z → A",
                SortOption.zToA,
                Icons.sort_by_alpha,
                Colors.blue,
              ),
              _buildSortTile(
                ctx,
                "Recently Added",
                SortOption.recentAdded,
                Icons.fiber_new,
                Colors.green,
              ),
              _buildSortTile(
                ctx,
                "Recently Updated",
                SortOption.recentUpdated,
                Icons.update,
                Colors.green,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  ListTile _buildSortTile(
    BuildContext ctx,
    String text,
    SortOption option,
    IconData icon,
    Color highlight,
  ) {
    return ListTile(
      title: Text(text),
      leading: Icon(icon, color: _sortBy == option ? highlight : null),
      onTap: () {
        setState(() {
          _sortBy = option;
          _applySorting();
        });
        Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);

    final filteredItems = _items.where((item) {
      final q = query.toLowerCase();
      final category = widget.categoryFilter;
      if (category != null && category.isNotEmpty) {
        if ((item["category"] ?? "").toString().toLowerCase() !=
            category.toLowerCase()) {
          return false;
        }
      }

      return (item["title"]?.toLowerCase().contains(q) ?? false) ||
          (item["username"]?.toLowerCase().contains(q) ?? false) ||
          (item["email"]?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              elevation: 0,
              title: const Text("Vault"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.folder),
                  tooltip: "Categories",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategoriesScreen(),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,

      floatingActionButton: null,
      body: Builder(
        builder: (context) {
          return _loading
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  /// collapse search when tapping outside
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _searchBarKey.currentState?.collapse();
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),

                        /// SEARCH BAR + SORT CHIP
                        Row(
                          children: [
                            Expanded(
                              child: IronSearchBar(
                                key: _searchBarKey,
                                controller: searchController,
                                onChanged: (value) {
                                  ref.read(searchQueryProvider.notifier).state =
                                      value.trim().toLowerCase();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.swap_vert_rounded),
                              tooltip: "Sort",
                              onPressed: _openSortSheet,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        /// empty state
                        if (filteredItems.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12),
                                    child: Icon(
                                      Icons.lock_open_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No items found",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Try a different search or add a new item.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, index) {
                                final item = filteredItems[index];
                                final isFav = item["isFavorite"] == true;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () async {
                                    final _ = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ViewCredentialScreen(item: item),
                                      ),
                                    );
                                    if (mounted) await _loadCredentials();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                          color: Colors.black12.withValues(
                                            alpha: 0.05,
                                          ),
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.12),
                                          child: Icon(
                                            typeByKey(
                                              item['type'] ?? 'password',
                                            ).icon,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item["title"],
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isFav)
                                                    const Icon(
                                                      Icons.star,
                                                      color: Colors.amber,
                                                      size: 18,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              if (_subtitleForItem(
                                                item,
                                              ).trim().isNotEmpty)
                                                Text(
                                                  _subtitleForItem(item),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              if (item["category"] != null &&
                                                  item["category"]
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Text(
                                                    item["category"],
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade500,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        IconButton(
                                          onPressed: () =>
                                              _toggleFavorite(item),
                                          icon: Icon(
                                            isFav
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: isFav
                                                ? Colors.amber
                                                : Colors.grey,
                                            size: 24,
                                          ),
                                        ),

                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
        },
      ),
    );
  }

  // ignore: unused_element
  String _sortLabel() {
    switch (_sortBy) {
      case SortOption.favoritesFirst:
        return "Favorites";
      case SortOption.aToZ:
        return "A → Z";
      case SortOption.zToA:
        return "Z → A";
      case SortOption.recentAdded:
        return "Recent";
      case SortOption.recentUpdated:
        return "Updated";
    }
  }
}
