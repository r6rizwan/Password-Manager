import 'package:flutter/material.dart';

class IronSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const IronSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<IronSearchBar> createState() => IronSearchBarState();
}

class IronSearchBarState extends State<IronSearchBar> {
  bool _expanded = false;
  final FocusNode _focusNode = FocusNode();

  /// Collapse only if search field is empty
  void collapse() {
    if (widget.controller.text.isEmpty) {
      setState(() => _expanded = false);
      _focusNode.unfocus();
    }
  }

  void _expand() {
    if (!_expanded) {
      setState(() => _expanded = true);

      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) FocusScope.of(context).requestFocus(_focusNode);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _expand, // tap anywhere in the whole bar to expand
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 22),
            const SizedBox(width: 8),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _expanded
                    ? TextField(
                        key: const ValueKey("searchField"),
                        focusNode: _focusNode,
                        controller: widget.controller,
                        onChanged: (value) {
                          widget.onChanged(value);
                          setState(() {}); // update collapse logic
                        },
                        decoration: InputDecoration(
                          hintText: "Search...",
                          border: InputBorder.none,
                        ),
                      )
                    : const SizedBox(height: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
