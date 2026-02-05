import 'dart:convert';
import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/constants/item_types.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/widgets/common_text_field.dart';
import 'package:ironvault/features/categories/providers/category_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final Map<String, dynamic>? existingItem;

  const AddItemScreen({super.key, this.initialType, this.existingItem});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _docErrorKey = GlobalKey();
  final Map<String, GlobalKey> _fieldKeys = {};

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _obscure = {};
  final List<String> _scanPaths = [];
  final Map<String, String?> _fieldErrors = {};

  String _typeKey = 'password';
  String? _selectedCategory;
  bool _saving = false;
  String? _titleError;
  String? _documentError;

  @override
  void initState() {
    super.initState();
    _typeKey = widget.initialType ?? widget.existingItem?['type'] ?? 'password';
    if (_typeKey == 'password') {
      _selectedCategory = widget.existingItem?['category'] as String?;
    }

    _titleController.text = widget.existingItem?['title'] ?? '';
    _initControllersForType(_typeKey);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _scrollController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllersForType(String typeKey) {
    final type = typeByKey(typeKey);
    final existingFields = (widget.existingItem?['fields'] as Map?)
        ?.cast<String, dynamic>();

    final existingScans = existingFields?['scans'];
    if (_scanPaths.isEmpty &&
        existingScans is String &&
        existingScans.isNotEmpty) {
      try {
        final decoded = jsonDecode(existingScans);
        if (decoded is List) {
          _scanPaths.addAll(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    for (final field in type.fields) {
      _fieldKeys.putIfAbsent(field.key, () => GlobalKey());
      _controllers.putIfAbsent(
        field.key,
        () => TextEditingController(
          text: existingFields?[field.key]?.toString() ?? '',
        ),
      );
      if (field.obscure) {
        _obscure[field.key] = true;
      }
    }
  }

  void _onTypeChanged(String? value) {
    if (value == null) return;
    setState(() {
      _typeKey = value;
      _initControllersForType(value);
      if (_typeKey != 'password') {
        _selectedCategory = null;
      }
      _fieldErrors.clear();
      _titleError = null;
      _documentError = null;
    });
  }

  Map<String, String> _collectFields() {
    final type = typeByKey(_typeKey);
    final Map<String, String> fields = {};
    for (final field in type.fields) {
      if (field.key == 'scans') {
        fields[field.key] = jsonEncode(_scanPaths);
        continue;
      }
      fields[field.key] = _controllers[field.key]?.text.trim() ?? '';
    }
    return fields;
  }

  bool _validateFields() {
    final type = typeByKey(_typeKey);
    final title = _titleController.text.trim();
    bool ok = true;
    _fieldErrors.clear();
    _titleError = null;
    _documentError = null;

    if (title.isEmpty) {
      _titleError = 'Title is required';
      ok = false;
    }

    for (final field in type.fields) {
      if (!field.required) continue;
      if (field.key == 'scans') continue;
      final value = _controllers[field.key]?.text.trim() ?? '';
      if (value.isEmpty) {
        _fieldErrors[field.key] = '${field.label} is required';
        ok = false;
      }
    }

    if (_typeKey == 'document') {
      final hasScan = _scanPaths.isNotEmpty;
      final docId = _controllers['document_id']?.text.trim() ?? '';
      final notes = _controllers['notes']?.text.trim() ?? '';
      if (!hasScan && docId.isEmpty && notes.isEmpty) {
        _documentError =
            'Add at least one detail (scan, document ID, or notes)';
        ok = false;
      }
    }

    return ok;
  }

  Future<void> _scrollToFirstError() async {
    final type = typeByKey(_typeKey);
    final keys = <GlobalKey>[
      _titleKey,
      ...type.fields.where((f) => f.required).map((f) => _fieldKeys[f.key]!),
    ];

    if (_documentError != null) {
      keys.add(_docErrorKey);
    }

    for (final key in keys) {
      final ctx = key.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.2,
        );
        break;
      }
    }
  }

  Future<void> _scanDocuments() async {
    ref.read(autoLockProvider.notifier).suspendAutoLock();
    List<String>? pages;
    try {
      pages = await CunningDocumentScanner.getPictures();
    } catch (_) {
      pages = null;
    }
    ref.read(autoLockProvider.notifier).resumeAutoLock();
    if (pages == null || pages.isEmpty) return;

    final dir = await getApplicationDocumentsDirectory();
    for (final path in pages) {
      final compressed = await _compressAndMove(path, dir.path);
      if (compressed != null) {
        _scanPaths.add(compressed);
      }
    }

    if (mounted) setState(() {});
  }

  Future<String?> _compressAndMove(String inputPath, String dirPath) async {
    final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = '$dirPath/$fileName';
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        inputPath,
        targetPath,
        quality: 70,
        minWidth: 1280,
        minHeight: 1280,
      );
      if (result != null) {
        try {
          final original = File(inputPath);
          if (await original.exists()) {
            await original.delete();
          }
        } catch (_) {}
        return result.path;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _save() async {
    if (!_validateFields()) {
      if (mounted) setState(() {});
      await _scrollToFirstError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(credentialRepoProvider);
    final fields = _collectFields();
    final category = _typeKey == 'password' ? _selectedCategory : null;

    try {
      if (widget.existingItem == null) {
        await repo.addItem(
          type: _typeKey,
          title: _titleController.text.trim(),
          fields: fields,
          category: category,
        );
      } else {
        await repo.updateItem(
          id: widget.existingItem!['id'],
          type: _typeKey,
          title: _titleController.text.trim(),
          fields: fields,
          category: category,
        );
      }

      TextInput.finishAutofillContext(shouldSave: true);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _scanSection(BuildContext context) {
    final textMuted = AppThemeColors.textMuted(context);
    return Container(
      padding: const EdgeInsets.all(16),
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
            children: const [
              Icon(Icons.document_scanner, size: 18),
              SizedBox(width: 8),
              Text(
                'Scan Document',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _scanPaths.isEmpty
                ? 'No pages scanned yet'
                : '${_scanPaths.length} page(s) scanned',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
          if (_scanPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _scanPaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final path = _scanPaths[i];
                  return GestureDetector(
                    onTap: () => _openScanPreview(context, i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(path),
                        width: 70,
                        height: 88,
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
                onPressed: () => _openScanManager(context),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Manage pages'),
              ),
            ),
          ],
          if (_documentError != null) ...[
            const SizedBox(height: 6),
            Row(
              key: _docErrorKey,
              children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _documentError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _scanDocuments,
                icon: const Icon(Icons.document_scanner),
                label: const Text('Scan Pages'),
              ),
              const SizedBox(width: 10),
              if (_scanPaths.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _scanPaths.clear());
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openScanPreview(BuildContext context, int initialIndex) {
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
              itemCount: _scanPaths.length,
              itemBuilder: (_, i) {
                return InteractiveViewer(
                  child: Image.file(File(_scanPaths[i]), fit: BoxFit.contain),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openScanManager(BuildContext context) {
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
                    itemCount: _scanPaths.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _scanPaths.removeAt(oldIndex);
                        _scanPaths.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = _scanPaths[index];
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
                            setState(() => _scanPaths.removeAt(index));
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = typeByKey(_typeKey);
    final categories = ref.watch(categoryListProvider);
    final isDocument = _typeKey == 'document';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null ? 'Add Item' : 'Edit Item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _typeKey,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: itemTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.key,
                            child: Text(t.label),
                          ),
                        )
                        .toList(),
                    onChanged: _onTypeChanged,
                  ),
                  const SizedBox(height: 16),

                  KeyedSubtree(
                    key: _titleKey,
                    child: CommonTextField(
                      label: 'Title',
                      controller: _titleController,
                      requiredField: true,
                      errorText: _titleError,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_typeKey == 'password') ...[
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.name,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 18),
                  ],

                  if (isDocument) ...[
                    _scanSection(context),
                    const SizedBox(height: 12),
                  ],

                  ...type.fields.map((field) {
                    if (field.key == 'scans') {
                      return const SizedBox.shrink();
                    }
                    final controller = _controllers[field.key]!;
                    final obscure = _obscure[field.key] ?? false;
                    final suffix = field.obscure
                        ? IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscure[field.key] = !obscure;
                              });
                            },
                          )
                        : null;

                    return Padding(
                      key: _fieldKeys[field.key],
                      padding: const EdgeInsets.only(bottom: 14),
                      child: CommonTextField(
                        label: field.label,
                        controller: controller,
                        obscure: field.obscure ? obscure : false,
                        keyboardType: field.keyboardType,
                        maxLines: field.maxLines,
                        suffix: suffix,
                        requiredField: field.required,
                        errorText: _fieldErrors[field.key],
                      ),
                    );
                  }),

                  const SizedBox(height: 6),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.existingItem == null
                                  ? 'Save Item'
                                  : 'Save Changes',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
