import 'package:flutter/material.dart';
import 'package:nami/widgets/confetti_overlay.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story confettiOverlayStory() {
  return Story(
    name: 'Fun/ConfettiOverlay',
    description: 'Animiertes Konfetti mit steuerbaren Parametern',
    builder: (context) {
      final knobs = context.knobs;
      final count = knobs.sliderInt(
        label: 'Particle Count',
        initial: 230,
        max: 500,
        min: 10,
      );
      final durationSeconds = knobs.sliderInt(
        label: 'Duration (s)',
        initial: 2,
        max: 10,
        min: 1,
      );
      final startCorner = knobs.options<Alignment>(
        label: 'Start Alignment',
        initial: Alignment.bottomCenter,
        options: const [
          Option(label: 'Bottom Right', value: Alignment.bottomRight),
          Option(label: 'Bottom Left', value: Alignment.bottomLeft),
          Option(label: 'Bottom Center', value: Alignment.bottomCenter),
        ],
      );
      final speedMin = knobs.slider(
        label: 'Speed Min',
        initial: 200,
        max: 1000,
        min: 0,
      );
      final speedMax = knobs.slider(
        label: 'Speed Max',
        initial: 1200,
        max: 2000,
        min: 0,
      );
      final spread = knobs.slider(
        label: 'Spread (rad)',
        initial: 3.14159 / 1.2,
        max: 3.14159,
        min: 0,
      );
      final bottomSpawnHeight = knobs.slider(
        label: 'Bottom Spawn Height',
        initial: 30,
        max: 400,
        min: 0,
      );

      return _ConfettiStoryContent(
        count: count,
        durationSeconds: durationSeconds,
        startCorner: startCorner,
        speedMin: speedMin,
        speedMax: speedMax,
        spread: spread,
        bottomSpawnHeight: bottomSpawnHeight,
      );
    },
  );
}

class _ConfettiStoryContent extends StatefulWidget {
  final int count;
  final int durationSeconds;
  final Alignment startCorner;
  final double speedMin;
  final double speedMax;
  final double spread;
  final double bottomSpawnHeight;

  const _ConfettiStoryContent({
    required this.count,
    required this.durationSeconds,
    required this.startCorner,
    required this.speedMin,
    required this.speedMax,
    required this.spread,
    required this.bottomSpawnHeight,
  });

  @override
  State<_ConfettiStoryContent> createState() => _ConfettiStoryContentState();
}

class _ConfettiStoryContentState extends State<_ConfettiStoryContent> {
  int seed = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Text(
              'Konfetti Overlay\nTippe irgendwo, um neu zu starten',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ConfettiOverlay(
            key: ValueKey<int>(seed),
            particleCount: widget.count,
            duration: Duration(seconds: widget.durationSeconds),
            startAlignment: widget.startCorner,
            speedMin: widget.speedMin,
            speedMax: widget.speedMax,
            spreadRadians: widget.spread,
            bottomSpawnHeight: widget.bottomSpawnHeight,
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  seed++;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
