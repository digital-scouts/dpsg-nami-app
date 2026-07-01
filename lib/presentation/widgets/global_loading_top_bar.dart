import 'dart:async';

import 'package:flutter/material.dart';

class GlobalLoadingTopBar extends StatefulWidget {
  const GlobalLoadingTopBar({
    super.key,
    required this.active,
    required this.immediate,
  });

  final bool active;
  final bool immediate;

  @override
  State<GlobalLoadingTopBar> createState() => _GlobalLoadingTopBarState();
}

class _GlobalLoadingTopBarState extends State<GlobalLoadingTopBar> {
  static const Duration _showDelay = Duration(milliseconds: 160);
  static const Duration _minVisibleImmediate = Duration(milliseconds: 1100);
  static const Duration _minVisibleDelayed = Duration(milliseconds: 420);

  Timer? _showTimer;
  Timer? _hideTimer;
  bool _visible = false;
  bool _visibleStartedImmediate = false;
  DateTime? _visibleAt;

  @override
  void initState() {
    super.initState();
    _syncVisibility(previousImmediate: widget.immediate);
  }

  @override
  void didUpdateWidget(covariant GlobalLoadingTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibility(previousImmediate: oldWidget.immediate);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _syncVisibility({required bool previousImmediate}) {
    if (widget.active) {
      _hideTimer?.cancel();
      if (_visible) {
        return;
      }

      final shouldShowNow = widget.immediate;
      if (shouldShowNow) {
        _showNow(startedImmediate: true);
        return;
      }

      final immediateActivated = !previousImmediate && widget.immediate;
      if (immediateActivated) {
        _showNow(startedImmediate: true);
        return;
      }

      _showTimer ??= Timer(_showDelay, () {
        _showNow(startedImmediate: false);
      });
      return;
    }

    _showTimer?.cancel();
    _showTimer = null;

    if (!_visible) {
      return;
    }

    _hideTimer?.cancel();
    final visibleAt = _visibleAt;
    final minVisible = _visibleStartedImmediate
        ? _minVisibleImmediate
        : _minVisibleDelayed;
    final elapsed = visibleAt == null
        ? minVisible
        : DateTime.now().difference(visibleAt);
    final remaining = minVisible - elapsed;
    if (remaining <= Duration.zero) {
      _hideNow();
      return;
    }

    _hideTimer = Timer(remaining, _hideNow);
  }

  void _showNow({required bool startedImmediate}) {
    _showTimer?.cancel();
    _showTimer = null;
    if (_visible) {
      return;
    }

    setState(() {
      _visible = true;
      _visibleStartedImmediate = startedImmediate;
      _visibleAt = DateTime.now();
    });
  }

  void _hideNow() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_visible) {
      return;
    }

    setState(() {
      _visible = false;
      _visibleAt = null;
      _visibleStartedImmediate = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    return const IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          bottom: false,
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ),
    );
  }
}
