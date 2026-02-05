// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/constants.dart';
import 'package:ironvault/core/constants/item_types.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/add/screens/add_item_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class ViewCredentialScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ViewCredentialScreen({super.key, required this.item});

  @override
  ConsumerState<ViewCredentialScreen> createState() =>
      _ViewCredentialScreenState();
}

class _ViewCredentialScreenState extends ConsumerState<ViewCredentialScreen> {
  late Map<String, dynamic> item;

  String? _copiedKey;
  Timer? _clipboardClearTimer;
  String? _lastCopiedValue;
  final Map<String, bool> _obscureFields = {};

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.item); // local copy so UI updates
    _initObscureStates();
  }

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  void _initObscureStates() {
    final type = (item['type'] ?? 'password').toString();
    final def = typeByKey(type);
    for (final field in def.fields) {
      if (field.obscure) {
        _obscureFields[field.key] = true;
      }
    }
  }

  Future<void> _scheduleClipboardClear(String value) async {
    _clipboardClearTimer?.cancel();
    _lastCopiedValue = value;

    _clipboardClearTimer = Timer(
      const Duration(seconds: AppConstants.clipboardClearSeconds),
      () async {
        try {
          final data = await Clipboard.getData('text/plain');
          if (data?.text == _lastCopiedValue) {
            await Clipboard.setData(const ClipboardData(text: ""));
          }
        } catch (_) {}

        if (mounted) {
          setState(() => _copiedKey = null);
        }
      },
    );
  }

  Future<void> _copyValue(String key, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    setState(() => _copiedKey = key);
    await _scheduleClipboardClear(value);
  }

  void _openScanPreview(
    BuildContext context,
    List<String> pages,
    int initialIndex,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            color: Colors.black,
            height: MediaQuery.of(context).size.height * 0.7,
            child: PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: pages.length,
              itemBuilder: (_, i) {
                return InteractiveViewer(
                  child: Image.file(
                    File(pages[i]),
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openScanManager(BuildContext context, List<String> pages) {
    final mutable = List<String>.from(pages);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Manage scanned pages',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ReorderableListView.builder(
                    itemCount: mutable.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = mutable.removeAt(oldIndex);
                        mutable.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = mutable[index];
                      return ListTile(
                        key: ValueKey(path),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(path),
                            width: 48,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text('Page ${index + 1}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() => mutable.removeAt(index));
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final repo = ref.read(credentialRepoProvider);
                      final fields = Map<String, String>.from(
                        (item['fields'] as Map).cast<String, String>(),
                      );
                      fields['scans'] = jsonEncode(mutable);
                      await repo.updateItem(
                        id: item['id'],
                        type: item['type'],
                        title: item['title'],
                        fields: fields,
                        category: item['category'],
                      );
                      setState(() {
                        item['fields'] = fields;
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite() async {
    final repo = ref.read(credentialRepoProvider);
    final newState = !(item["isFavorite"] == true);

    await repo.toggleFavorite(item["id"], newState);

    setState(() {
      item["isFavorite"] = newState;
    });
  }

  Widget _sectionTitle(String title) {
    final textMuted = AppThemeColors.textMuted(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          color: textMuted,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoTile({
    required String value,
    bool obscure = false,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              obscure ? "•" * 10 : value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = (item["isFavorite"] == true);
    final typeKey = (item["type"] ?? "password").toString();
    final typeDef = typeByKey(typeKey);
    final fields =
        (item["fields"] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          item["title"],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: isFav ? "Unpin" : "Mark as Favorite",
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : Colors.grey,
              size: 26,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddItemScreen(existingItem: item),
                ),
              );

              if (mounted) Navigator.pop(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Delete",
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text("Delete Item"),
                    content: const Text(
                      "Are you sure you want to permanently delete this item?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                final repo = ref.read(credentialRepoProvider);
                await repo.deleteCredential(item["id"]);

                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    radius: 26,
                    child: Icon(
                      typeDef.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      item["title"],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _sectionTitle("Type"),
            _infoTile(value: typeDef.label),

            ...typeDef.fields.map((field) {
              if (field.key == 'scans') {
                final raw = (fields['scans'] ?? '').toString();
                if (raw.trim().isEmpty) return const SizedBox.shrink();
                int count = 0;
                List<String> pages = [];
                try {
                  final decoded = jsonDecode(raw);
                  if (decoded is List) {
                    pages = decoded.map((e) => e.toString()).toList();
                    count = pages.length;
                  }
                } catch (_) {}
                if (count == 0) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Scanned Pages'),
                    _infoTile(value: '$count page(s)'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final path = pages[i];
                          return GestureDetector(
                            onTap: () => _openScanPreview(context, pages, i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(path),
                                width: 70,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openScanManager(context, pages),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Manage pages'),
                      ),
                    ),
                  ],
                );
              }

              final value = (fields[field.key] ?? '').toString();
              if (value.trim().isEmpty) return const SizedBox.shrink();

              final isObscure = field.obscure;
              final obscureState = _obscureFields[field.key] ?? true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(field.label),
                  _infoTile(
                    value: value,
                    obscure: isObscure ? obscureState : false,
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isObscure)
                          IconButton(
                            icon: Icon(
                              obscureState
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureFields[field.key] = !obscureState;
                              });
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _copiedKey == field.key ? Icons.check : Icons.copy,
                            color:
                                _copiedKey == field.key ? Colors.green : null,
                            size: 22,
                          ),
                          onPressed: _copiedKey == field.key
                              ? null
                              : () => _copyValue(field.key, value),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),

            if (item["category"] != null &&
                item["category"].toString().trim().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Category"),
                  _infoTile(value: item["category"]),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
