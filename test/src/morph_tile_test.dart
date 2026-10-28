import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morph_route/morph_route.dart';

const _overlay = Color(0xFF336699);

void main() {
  Future<void> pumpTile(WidgetTester tester, {Color? overlay, double pressedScale = 0.9, VoidCallback? onTap}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MorphTile<void>(
              pressedScale: pressedScale,
              pressedOverlayColor: overlay,
              pressedAnimDuration: const Duration(milliseconds: 100),
              transitionDuration: const Duration(milliseconds: 200),
              closedColor: Colors.white,
              closedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
              onTap: onTap,
              closedBuilder: (context) => const SizedBox(width: 200, height: 100, child: Center(child: Text('Tile'))),
              openBuilder: (context, _) => const Scaffold(body: Text('Detail')),
            ),
          ),
        ),
      ),
    );
  }

  // The OpenContainer's decorated card (closedColor + closedShape + shadows).
  Finder card() => find.descendant(
    of: find.byType(MorphTile<void>),
    matching: find.byWidgetPredicate((w) => w is Container && w.decoration is ShapeDecoration),
  );

  Color? overlayColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(of: find.byType(AnimatedContainer), matching: find.byType(Container)),
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  testWidgets('pressing scales the whole card, not just its content', (tester) async {
    await pumpTile(tester);
    final rest = tester.getRect(card());
    expect(rest.size, const Size(200, 100));

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final pressed = tester.getRect(card());
    expect(pressed.width, closeTo(rest.width * 0.9, 0.01));
    expect(pressed.height, closeTo(rest.height * 0.9, 0.01));
    expect(pressed.center.dx, closeTo(rest.center.dx, 0.01));
    expect(pressed.center.dy, closeTo(rest.center.dy, 0.01));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('releasing fades the tint by alpha only, keeping its RGB', (tester) async {
    await pumpTile(tester, overlay: _overlay);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(overlayColor(tester), _overlay);

    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final mid = overlayColor(tester)!;
    expect(mid.a, greaterThan(0));
    expect(mid.a, lessThan(1));
    expect(mid.r, closeTo(_overlay.r, 0.01));
    expect(mid.g, closeTo(_overlay.g, 0.01));
    expect(mid.b, closeTo(_overlay.b, 0.01));

    await tester.pumpAndSettle();
    expect(overlayColor(tester)!.a, 0);
  });

  testWidgets('exposes a button with a tap action', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpTile(tester);

    expect(tester.getSemantics(find.text('Tile')), isSemantics(isButton: true, hasTapAction: true, label: 'Tile'));
    handle.dispose();
  });

  testWidgets('tapping opens the route and fires onTap once', (tester) async {
    var taps = 0;
    await pumpTile(tester, onTap: () => taps++);

    await tester.tap(find.text('Tile'));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.text('Detail'), findsOneWidget);
  });
}
