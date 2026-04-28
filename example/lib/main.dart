import 'package:flutter/material.dart';
import 'package:morph_route/morph_route.dart';

void main() {
  runApp(const _DemoApp());
}

const _cream = Color(0xFFFAF9F5);
const _ink = Color(0xFF111111);
const _muted = Color(0xFFEFEAE0);
const _coral = Color(0xFFD97757);

const _shadowSm = <BoxShadow>[
  BoxShadow(color: Color(0x0A141413), offset: Offset(0, 1), blurRadius: 2),
];

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'morph_route example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _cream,
        textTheme: const TextTheme(bodyMedium: TextStyle(color: _ink)),
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Wraps the body so it scales down behind any active morph route.
      body: MorphRecede(
        scaleFloor: 0.94,
        curve: Curves.ease,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                const Text(
                  'morph_route',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the active tile to see the morph in flight.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _ink.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: const [
                      _MorphingTile(),
                      _StaticTile(label: 'Receive'),
                      _StaticTile(label: 'Swap'),
                      _StaticTile(label: 'Borrow'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphingTile extends StatelessWidget {
  const _MorphingTile();

  @override
  Widget build(BuildContext context) {
    return MorphTile(
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      transitionType: ContainerTransitionType.fade,
      closedColor: Colors.white,
      openColor: _cream,
      middleColor: _cream,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      openShape: const RoundedRectangleBorder(),
      closedShadows: _shadowSm,
      // The premium bits.
      openBlurSigma: 12,
      scrimColor: _coral.withValues(alpha: 0.08),
      peakTiltY: 0.09,
      peakTiltX: 0.025,
      // Press feedback.
      pressedScale: 0.98,
      pressedOverlayColor: _muted,
      closedBuilder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.north_east, size: 28, color: _ink),
            SizedBox(height: 12),
            Text(
              'Send',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
      openBuilder: (context, action) => _DestinationScreen(onClose: () => action()),
    );
  }
}

class _StaticTile extends StatelessWidget {
  final String label;
  const _StaticTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _shadowSm,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _ink.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Destination screen — what the morph reveals.
class _DestinationScreen extends StatelessWidget {
  final VoidCallback onClose;
  const _DestinationScreen({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => onClose(),
                    icon: const Icon(Icons.close, color: _ink),
                  ),
                  const Spacer(),
                  const Text(
                    'Send',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This is where your real flow goes.\n\nTap the X to morph back.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: _ink,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
