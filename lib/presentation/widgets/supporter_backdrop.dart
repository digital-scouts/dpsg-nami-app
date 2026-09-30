import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/appearance/appearance_catalog.dart';
import 'supporter_background.dart';

/// Legt die Header-Flaeche durchgehend vom oberen Rand (hinter Safe Area,
/// Banner und Lade-Info) bis zur Unterkante des Bereichs, den ein
/// [SupporterBackdropAnchor] markiert, z. B. den Listen-Header. Mit
/// Supporter-Hintergrund animiert, sonst schlicht in `surface`.
class SupporterBackdrop extends StatefulWidget {
  const SupporterBackdrop({
    super.key,
    required this.background,
    required this.child,
  });

  /// `null`: schlichte Flaeche in `surface`, sofern ein Anker sie anfordert.
  final AppearanceBackgroundId? background;
  final Widget child;

  static SupporterBackdropController? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_SupporterBackdropScope>()
      ?.controller;

  @override
  State<SupporterBackdrop> createState() => _SupporterBackdropState();
}

/// Verbindet [SupporterBackdrop] und [SupporterBackdropAnchor].
class SupporterBackdropController {
  final ValueNotifier<double?> extent = ValueNotifier<double?>(null);
  final GlobalKey _stackKey = GlobalKey();
  VoidCallback? _measureAnchor;
  bool _disposed = false;

  RenderBox? get _stackBox =>
      _stackKey.currentContext?.findRenderObject() as RenderBox?;

  void _requestMeasure() => _measureAnchor?.call();

  void _report(double? value) {
    if (!_disposed && extent.value != value) {
      extent.value = value;
    }
  }

  void _dispose() {
    _disposed = true;
    extent.dispose();
  }
}

class _SupporterBackdropState extends State<SupporterBackdrop> {
  final SupporterBackdropController _controller = SupporterBackdropController();

  @override
  void dispose() {
    _controller._dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Banner oberhalb koennen den Header verschieben, ohne dass sich seine
    // Groesse aendert: nach jedem Neuaufbau neu messen.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _controller._requestMeasure(),
    );
    final background = widget.background;
    return _SupporterBackdropScope(
      controller: _controller,
      child: Stack(
        key: _controller._stackKey,
        children: [
          // Feste Kinderzahl, damit der Inhalt beim Umschalten erhalten bleibt.
          ValueListenableBuilder<double?>(
            valueListenable: _controller.extent,
            builder: (context, extent, _) {
              if (extent == null || extent <= 0) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: extent,
                child: background == null
                    ? ColoredBox(
                        key: const ValueKey('supporter-backdrop-plain'),
                        color: Theme.of(context).colorScheme.surface,
                      )
                    : SupporterBackground(background: background),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _SupporterBackdropScope extends InheritedWidget {
  const _SupporterBackdropScope({
    required this.controller,
    required super.child,
  });

  final SupporterBackdropController controller;

  @override
  bool updateShouldNotify(_SupporterBackdropScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Markiert die Unterkante des Hintergrunds. Misst sich nach Layout- und
/// Groessenaenderungen und meldet die Position an den [SupporterBackdrop].
class SupporterBackdropAnchor extends StatefulWidget {
  const SupporterBackdropAnchor({super.key, required this.child});

  final Widget child;

  @override
  State<SupporterBackdropAnchor> createState() =>
      _SupporterBackdropAnchorState();
}

class _SupporterBackdropAnchorState extends State<SupporterBackdropAnchor> {
  SupporterBackdropController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SupporterBackdrop.maybeOf(context);
    if (!identical(controller, _controller)) {
      _controller?._measureAnchor = null;
      _controller = controller?.._measureAnchor = _measure;
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller._measureAnchor = null;
      // Nicht waehrend des Abbaus benachrichtigen, sondern im naechsten
      // Frame, und nur, wenn kein neuer Anker uebernommen hat.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (controller._measureAnchor == null) {
          controller._report(null);
        }
      });
    }
    super.dispose();
  }

  void _schedule() {
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final stack = controller._stackBox;
    if (box == null || stack == null || !box.attached || !box.hasSize) {
      return;
    }
    final bottom = box
        .localToGlobal(Offset(0, box.size.height), ancestor: stack)
        .dy;
    controller._report(bottom);
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _schedule();
        return true;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}
