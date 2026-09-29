import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class MemberSearchBar extends StatefulWidget {
  const MemberSearchBar({
    super.key,
    required this.initial,
    required this.onChanged,
    this.showFilterIndicator = false,
    this.onTunePressed,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final bool showFilterIndicator;
  final VoidCallback? onTunePressed;

  @override
  State<MemberSearchBar> createState() => _MemberSearchBarState();
}

class _MemberSearchBarState extends State<MemberSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant MemberSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial &&
        widget.initial != _controller.text) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearSearch() {
    if (_controller.text.isEmpty) {
      return;
    }
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasText = _controller.text.trim().isNotEmpty;
    final borderColor = _focusNode.hasFocus
        ? theme.colorScheme.primary
        : Colors.transparent;
    final fillColor = _focusNode.hasFocus
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 20,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: (value) {
                  widget.onChanged(value);
                  setState(() {});
                },
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: null,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: t.t('member_list_search_hint'),
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            if (hasText)
              SizedBox.square(
                dimension: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: Icon(
                    Icons.cancel,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  tooltip: t.t('settings_map_search_close'),
                  onPressed: _clearSearch,
                ),
              ),
            SizedBox.square(
              dimension: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 22,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(36),
                  minimumSize: const Size.square(36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.tune, size: 22),
                    if (widget.showFilterIndicator)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6007E),
                            shape: BoxShape.circle,
                            border: Border.all(color: fillColor, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: t.t('member_filter_open_tooltip'),
                onPressed: widget.onTunePressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
