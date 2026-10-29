import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_bewegung.dart';
import '../theme/app_haptik.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/achievement_tile.dart';
import '../widgets/achievement_visuals.dart';
import '../widgets/confetti_overlay.dart';

/// Zeigt den Freischalt-Moment für einen Erfolg.
///
/// Konfetti gibt es immer, außer bei „Bewegung reduzieren“. Bronze und
/// Silber erscheinen zusätzlich als Snackbar, ab Gold und bei einmaligen
/// Erfolgen als Dialog mit Erfolg-Haptik. [tier] ist `null` bei einmaligen
/// Erfolgen.
Future<void> showAchievementUnlocked(
  BuildContext context, {
  required AchievementDefinition definition,
  AchievementTier? tier,
  VoidCallback? onShowAll,
}) async {
  if (isAchievementCelebration(tier)) {
    await showGeneralDialog<void>(
      context: context,
      // Nächster Navigator, damit Lokalisierung und Theme des Aufrufers gelten.
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: AppBewegung.standard,
      pageBuilder: (dialogContext, _, _) => AchievementUnlockedDialog(
        definition: definition,
        tier: tier,
        onShowAll: onShowAll == null
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                onShowAll();
              },
      ),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppBewegung.ausgang),
        child: child,
      ),
    );
    return;
  }

  _showConfetti(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 5),
      content: AchievementUnlockedSnackbarContent(
        definition: definition,
        tier: tier,
        onTap: onShowAll == null
            ? null
            : () {
                messenger.hideCurrentSnackBar();
                onShowAll();
              },
      ),
    ),
  );
}

const _snackbarConfettiDuration = Duration(seconds: 2);

void _showConfetti(BuildContext context) {
  // Mit dem Navigator-Kontext der App-Shell liegt das Overlay unterhalb.
  final overlay =
      Overlay.maybeOf(context) ?? Navigator.maybeOf(context)?.overlay;
  if (overlay == null) {
    return;
  }
  final entry = OverlayEntry(
    builder: (_) => const Positioned.fill(
      child: ConfettiOverlay(
        particleCount: 90,
        duration: _snackbarConfettiDuration,
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(_snackbarConfettiDuration, () {
    if (entry.mounted) {
      entry.remove();
    }
  });
}

bool isAchievementCelebration(AchievementTier? tier) =>
    tier == null || tier.index >= AchievementTier.gold.index;

String _unlockedLine(
  AppLocalizations t,
  AchievementDefinition definition,
  AchievementTier? tier,
) {
  final count = tier == null ? 1 : definition.thresholds[tier.index];
  return AchievementVisuals.description(t, definition.id, count);
}

class AchievementUnlockedSnackbarContent extends StatelessWidget {
  const AchievementUnlockedSnackbarContent({
    super.key,
    required this.definition,
    this.tier,
    this.onTap,
  });

  final AchievementDefinition definition;
  final AchievementTier? tier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final tier = this.tier;
    final accent = tier == null
        ? AchievementVisuals.specialRim.light
        : AchievementVisuals.paletteFor(tier).light;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B4A7F), Color(0xFF002544)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40002544),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        child: Row(
          children: [
            AchievementBadge(
              icon: AchievementVisuals.iconFor(definition.id),
              tier: tier,
              special: tier == null,
              size: 64,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t('achievements_unlocked_title').toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tier == null
                        ? AchievementVisuals.title(t, definition.id)
                        : '${AchievementVisuals.title(t, definition.id)} · '
                              '${AchievementVisuals.tierLabel(t, tier)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _unlockedLine(t, definition, tier),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AchievementUnlockedDialog extends StatelessWidget {
  const AchievementUnlockedDialog({
    super.key,
    required this.definition,
    this.tier,
    this.onShowAll,
    this.showConfetti = true,
  });

  final AchievementDefinition definition;
  final AchievementTier? tier;
  final VoidCallback? onShowAll;
  final bool showConfetti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final tier = this.tier;

    return Stack(
      children: [
        if (showConfetti)
          const Positioned.fill(child: ConfettiOverlay(particleCount: 160)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF0B4A7F), Color(0xFF002544)],
                        ),
                      ),
                      child: Column(
                        children: [
                          _BadgeAuftritt(
                            child: AchievementBadge(
                              icon: AchievementVisuals.iconFor(definition.id),
                              tier: tier,
                              special: tier == null,
                              size: 132,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t.t('achievements_unlocked_title').toUpperCase(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: tier == null
                                  ? AchievementVisuals.specialRim.light
                                  : AchievementVisuals.paletteFor(tier).light,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                      child: Column(
                        children: [
                          Text(
                            AchievementVisuals.title(t, definition.id),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (tier != null) ...[
                            const SizedBox(height: 6),
                            AchievementTierChip(tier: tier),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            _unlockedLine(t, definition, tier),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          if (onShowAll != null)
                            Expanded(
                              child: TextButton(
                                onPressed: onShowAll,
                                child: Text(t.t('achievements_show_all')),
                              ),
                            ),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: Text(t.t('achievements_unlocked_close')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Auftritt des Badges im Freischalt-Dialog: Sobald der Dialog fast steht,
/// federt es sichtbar auf und schwingt einmal nach. Im selben Moment kommt
/// die Erfolg-Haptik. Ein seltener Moment, deshalb darf es verspielt sein.
class _BadgeAuftritt extends StatefulWidget {
  const _BadgeAuftritt({required this.child});

  final Widget child;

  @override
  State<_BadgeAuftritt> createState() => _BadgeAuftrittState();
}

class _BadgeAuftrittState extends State<_BadgeAuftritt>
    with SingleTickerProviderStateMixin {
  /// Wartet, bis der Dialog (250 ms) fast eingeblendet ist.
  static const _verzoegerung = Duration(milliseconds: 180);
  static const _dauer = Duration(milliseconds: 900);
  static const _startSkala = 0.5;
  static final _feder = FederKurve(
    SpringDescription.withDurationAndBounce(
      duration: const Duration(milliseconds: 600),
      bounce: 0.45,
    ),
    dauer: _dauer,
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _dauer,
  );
  Timer? _start;
  bool _begonnen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_begonnen) {
      return;
    }
    _begonnen = true;
    if (AppBewegung.reduziert(context)) {
      // Das Badge steht sofort; die Haptik bleibt und kommt mit dem ersten
      // Bild des Dialogs, nicht mitten im Aufbau.
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(AppHaptik.erfolg());
        }
      });
      return;
    }
    _start = Timer(_verzoegerung, () {
      if (!mounted) {
        return;
      }
      unawaited(AppHaptik.erfolg());
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final skala = _startSkala + (1 - _startSkala) * _feder.transform(t);
        // Im ersten Fünftel sichtbar werden, nie aus dem Nichts wachsen.
        final deckkraft = AppBewegung.ausgang.transform(
          (t / 0.2).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: deckkraft,
          child: Transform.scale(scale: skala, child: child),
        );
      },
      child: widget.child,
    );
  }
}
