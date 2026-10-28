import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:morph_route/morph_route.dart';

void main() {
  runApp(const _DemoApp());
}

const _cream = Color(0xFFFAF9F5);
const _ink = Color(0xFF111111);
const _muted = Color(0xFFEFEAE0);
const _coral = Color(0xFFD97757);

const _shadowSm = <BoxShadow>[BoxShadow(color: Color(0x0A141413), offset: Offset(0, 1), blurRadius: 2)];

const _tileShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)));

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
        colorScheme: ColorScheme.fromSeed(seedColor: _coral, surface: _cream),
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
          // Scrolls so the grid stays reachable at large text sizes and in landscape.
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The headline shrinks to fit instead of wrapping mid-word at large text sizes.
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'morph_route',
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _ink, letterSpacing: -1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap a tile to see the morph in flight.',
                        style: TextStyle(fontSize: 14, color: _ink.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildListDelegate.fixed([_SendTile(), _ReceiveTile(), _SwapTile(), _BorrowTile()]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The signature look: fade, backdrop blur, accent scrim and 3D tilt.
class _SendTile extends StatelessWidget {
  const _SendTile();

  @override
  Widget build(BuildContext context) {
    return MorphTile(
      key: const ValueKey('tile-send'),
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      transitionType: ContainerTransitionType.fade,
      closedColor: Colors.white,
      openColor: _cream,
      closedShape: _tileShape,
      closedShadows: _shadowSm,
      openBlurSigma: 12,
      scrimColor: _coral.withValues(alpha: 0.08),
      peakTiltY: 0.09,
      peakTiltX: 0.025,
      pressedOverlayColor: _muted,
      onTap: HapticFeedback.lightImpact,
      closedBuilder: (context) => const _TileLabel(icon: Icons.north_east, label: 'Send'),
      openBuilder: (context, close) => _DestinationScreen(
        title: 'Send',
        body: 'Fade + blur + scrim + 3D tilt.\n\nTap the X to morph back.',
        onClose: () => close(),
      ),
    );
  }
}

/// `fadeThrough` from a coloured tile, flat (no tilt).
class _ReceiveTile extends StatelessWidget {
  const _ReceiveTile();

  @override
  Widget build(BuildContext context) {
    return MorphTile(
      key: const ValueKey('tile-receive'),
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionType: ContainerTransitionType.fadeThrough,
      closedColor: _coral,
      middleColor: _cream,
      openColor: _cream,
      closedShape: _tileShape,
      closedShadows: _shadowSm,
      openBlurSigma: 8,
      pressedOverlayColor: Colors.black12,
      onTap: HapticFeedback.lightImpact,
      closedBuilder: (context) => const _TileLabel(icon: Icons.south_west, label: 'Receive', color: Colors.white),
      openBuilder: (context, close) => _DestinationScreen(
        title: 'Receive',
        body: 'fadeThrough from a coloured tile, no tilt.\n\nTap the X to morph back.',
        onClose: () => close(),
      ),
    );
  }
}

/// [OpenContainer] used directly: the route returns a value to `onClosed`.
class _SwapTile extends StatelessWidget {
  const _SwapTile();

  @override
  Widget build(BuildContext context) {
    return OpenContainer<String>(
      key: const ValueKey('tile-swap'),
      transitionDuration: const Duration(milliseconds: 440),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      closedColor: Colors.white,
      openColor: _cream,
      closedShape: _tileShape,
      closedShadows: _shadowSm,
      openBlurSigma: 10,
      peakTiltY: 0.06,
      onClosed: (result) {
        if (result == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Swap $result'), behavior: SnackBarBehavior.floating));
      },
      closedBuilder: (context, open) => Semantics(
        button: true,
        child: const _TileLabel(icon: Icons.swap_horiz, label: 'Swap'),
      ),
      openBuilder: (context, close) => _DestinationScreen(
        title: 'Swap',
        body: 'OpenContainer used directly.\nThe route hands a value back to onClosed.',
        onClose: () => close(),
        actions: [
          FilledButton(
            key: const ValueKey('swap-confirm'),
            style: FilledButton.styleFrom(backgroundColor: _ink),
            onPressed: () => close(returnValue: 'confirmed'),
            child: const Text('Confirm swap'),
          ),
        ],
      ),
    );
  }
}

/// A morph route that pushes a regular page on top of itself.
class _BorrowTile extends StatelessWidget {
  const _BorrowTile();

  @override
  Widget build(BuildContext context) {
    return MorphTile(
      key: const ValueKey('tile-borrow'),
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      closedColor: Colors.white,
      openColor: _cream,
      closedShape: _tileShape,
      closedShadows: _shadowSm,
      openBlurSigma: 12,
      peakTiltY: 0.09,
      pressedOverlayColor: _muted,
      onTap: HapticFeedback.lightImpact,
      closedBuilder: (context) => const _TileLabel(icon: Icons.account_balance_outlined, label: 'Borrow'),
      openBuilder: (context, close) => _DestinationScreen(
        title: 'Borrow',
        body: 'Routes can be pushed on top of a morph route.\n\nTap the X to morph back.',
        onClose: () => close(),
        actions: [
          OutlinedButton(
            key: const ValueKey('borrow-details'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  backgroundColor: _cream,
                  appBar: AppBar(backgroundColor: _cream, title: const Text('Loan details')),
                  body: const Center(child: Text('A regular page on top of the morph.')),
                ),
              ),
            ),
            child: const Text('Loan details'),
          ),
        ],
      ),
    );
  }
}

class _TileLabel extends StatelessWidget {
  const _TileLabel({required this.icon, required this.label, this.color = _ink});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        // Large accessibility text sizes scale the label down instead of overflowing the tile.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destination screen — what the morph reveals.
class _DestinationScreen extends StatelessWidget {
  const _DestinationScreen({required this.title, required this.body, required this.onClose, this.actions = const []});

  final String title;
  final String body;
  final VoidCallback onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: _ink),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: _ink, height: 1.5),
                      ),
                      for (final action in actions) ...[const SizedBox(height: 24), action],
                    ],
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
