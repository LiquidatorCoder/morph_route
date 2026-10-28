import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morph_route/morph_route.dart';

const _closedKey = Key('closed');
const _closeButtonKey = Key('close');
const _tileSize = Size(100, 50);

/// Page transitions that do nothing, so the only animations in play are the
/// OpenContainer's own.
class _NoTransitions extends PageTransitionsBuilder {
  const _NoTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

void main() {
  late int openBuilds;
  late int closedCopyTaps;

  setUp(() {
    openBuilds = 0;
    closedCopyTaps = 0;
    OpenContainer.activeProgress.value = 0;
  });

  // The tile sits at 90% of the free horizontal space, so its position depends
  // on the view width (rotation moves it).
  Widget tile({Size size = _tileSize, bool tappableContent = false}) {
    return OpenContainer<void>(
      transitionDuration: const Duration(milliseconds: 300),
      closedBuilder: (context, open) => tappableContent
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                closedCopyTaps++;
                open();
              },
              child: SizedBox(
                key: _closedKey,
                width: size.width,
                height: size.height,
                child: const ColoredBox(color: Colors.blue),
              ),
            )
          : SizedBox(
              key: _closedKey,
              width: size.width,
              height: size.height,
              child: const ColoredBox(color: Colors.blue),
            ),
      openBuilder: (context, action) {
        openBuilds++;
        return Center(
          child: GestureDetector(
            key: _closeButtonKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => action(),
            child: const SizedBox(width: 80, height: 40, child: ColoredBox(color: Colors.red)),
          ),
        );
      },
    );
  }

  Widget app(Widget body) {
    return MaterialApp(
      theme: ThemeData(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            for (final p in TargetPlatform.values) p: const _NoTransitions(),
          },
        ),
      ),
      home: Scaffold(body: body),
    );
  }

  Widget alignedTile({bool recede = false, Widget? child}) {
    final Widget body = Align(alignment: const Alignment(0.8, 0.2), child: child ?? tile());
    return app(recede ? MorphRecede(scaleFloor: 0.8, child: body) : body);
  }

  Future<void> useView(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Future<void> openRoute(WidgetTester tester) async {
    await tester.tap(find.byKey(_closedKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_closeButtonKey), findsOneWidget);
  }

  /// Taps close and advances to the very last in-flight frame of the close morph.
  Future<Rect> closeToLastInFlightFrame(WidgetTester tester) async {
    await tester.tap(find.byKey(_closeButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 298));
    expect(OpenContainer.activeProgress.value, greaterThan(0));
    return tester.getRect(find.byKey(_closedKey));
  }

  void expectRectClose(Rect actual, Rect expected, {double tolerance = 1.0}) {
    expect(actual.left, closeTo(expected.left, tolerance), reason: 'left: $actual vs $expected');
    expect(actual.top, closeTo(expected.top, tolerance), reason: 'top: $actual vs $expected');
    expect(actual.width, closeTo(expected.width, tolerance), reason: 'width: $actual vs $expected');
    expect(actual.height, closeTo(expected.height, tolerance), reason: 'height: $actual vs $expected');
  }

  testWidgets('B8: closing after a rotation lands on the relaid-out tile', (tester) async {
    await useView(tester, const Size(400, 800));
    await tester.pumpWidget(alignedTile());
    await openRoute(tester);

    await useView(tester, const Size(800, 400));
    await tester.pump();
    await tester.pump();

    final lastFrame = await closeToLastInFlightFrame(tester);
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byKey(_closedKey));

    expect(settled.left, closeTo((800 - 100) * 0.9, 0.5), reason: 'tile moved with the width');
    expectRectClose(lastFrame, settled);
  });

  testWidgets('B8: with MorphRecede and a rotation, close lands on the untransformed tile', (tester) async {
    await useView(tester, const Size(400, 800));
    await tester.pumpWidget(alignedTile(recede: true));
    await openRoute(tester);

    await useView(tester, const Size(800, 400));
    await tester.pump();
    await tester.pump();

    final lastFrame = await closeToLastInFlightFrame(tester);
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byKey(_closedKey));

    expectRectClose(lastFrame, settled);
  });

  testWidgets('MorphRecede around the tile: close still lands on the tile (no relayout)', (tester) async {
    await useView(tester, const Size(400, 800));
    await tester.pumpWidget(alignedTile(recede: true));
    final before = tester.getRect(find.byKey(_closedKey));
    await openRoute(tester);

    // The underlying screen is receded while the route is open.
    expect(OpenContainer.activeProgress.value, 1.0);

    final lastFrame = await closeToLastInFlightFrame(tester);
    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byKey(_closedKey));

    expectRectClose(settled, before, tolerance: 0.01);
    expectRectClose(lastFrame, settled);
  });

  testWidgets('B11: the placeholder keeps the untransformed layout size', (tester) async {
    await useView(tester, const Size(400, 800));
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.topLeft,
          child: Transform.scale(scale: 0.5, alignment: Alignment.topLeft, child: tile()),
        ),
      ),
    );
    final container = find.byWidgetPredicate((w) => w is OpenContainer);
    expect(tester.getSize(container), _tileSize);

    await tester.tap(find.byKey(_closedKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // While the route owns the visual the source slot is a placeholder; it must
    // not shrink to the scaled (50x25) rect.
    expect(tester.getSize(container), _tileSize);
    await tester.pumpAndSettle();
  });

  testWidgets('B6: every CurvedAnimation created is disposed, at most 2 per route', (tester) async {
    await useView(tester, const Size(400, 800));
    await tester.pumpWidget(alignedTile());
    await tester.pumpAndSettle();

    var created = 0;
    var disposed = 0;
    void listener(ObjectEvent event) {
      if (event.object is! CurvedAnimation) return;
      if (event is ObjectCreated) created++;
      if (event is ObjectDisposed) disposed++;
    }

    FlutterMemoryAllocations.instance.addListener(listener);
    addTearDown(() => FlutterMemoryAllocations.instance.removeListener(listener));

    await tester.tap(find.byKey(_closedKey));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_closeButtonKey));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    // Let the navigator dispose the popped route.
    await tester.pump(const Duration(milliseconds: 50));

    debugPrint('CurvedAnimation created=$created disposed=$disposed');
    expect(created, lessThanOrEqualTo(2));
    expect(disposed, created);
  });

  testWidgets('P1: openBuilder is not re-run on every frame of the morph', (tester) async {
    await useView(tester, const Size(400, 800));
    await tester.pumpWidget(alignedTile());

    await tester.tap(find.byKey(_closedKey));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    final afterOpen = openBuilds;

    await tester.tap(find.byKey(_closeButtonKey));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    debugPrint('openBuilder calls: open=$afterOpen total=$openBuilds');
    expect(afterOpen, lessThanOrEqualTo(4));
    expect(openBuilds, lessThanOrEqualTo(8));
  });

  testWidgets('B10: the fading closed copy inside the route ignores pointers', (tester) async {
    await useView(tester, const Size(400, 800));
    await tester.pumpWidget(alignedTile(child: tile(tappableContent: true)));

    await tester.tap(find.byKey(_closedKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(_closeButtonKey), findsOneWidget);
    closedCopyTaps = 0;

    // Top-left corner of the morphing closed copy; the open content (a centred
    // button) does not cover it.
    final topLeft = tester.getTopLeft(find.byKey(_closedKey)) + const Offset(2, 2);
    await tester.tapAt(topLeft);
    await tester.pump();
    expect(closedCopyTaps, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('activeProgress returns to 0 and the tile is visible and tappable after close', (tester) async {
    await useView(tester, const Size(400, 800));
    await tester.pumpWidget(alignedTile(recede: true));
    await openRoute(tester);
    expect(OpenContainer.activeProgress.value, 1.0);

    await tester.tap(find.byKey(_closeButtonKey));
    await tester.pumpAndSettle();

    expect(OpenContainer.activeProgress.value, 0.0);
    expect(find.byKey(_closeButtonKey), findsNothing);
    expect(tester.getRect(find.byKey(_closedKey)).size, _tileSize);

    // Tappable again.
    await tester.tap(find.byKey(_closedKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_closeButtonKey), findsOneWidget);
  });
}
