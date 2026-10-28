import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morph_route/morph_route.dart';

const _openKey = Key('open');
const _closeKey = Key('close');
const _tileKey = Key('tile');

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

Widget _app(Widget home, {required bool reduce}) {
  return MaterialApp(
    theme: ThemeData(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          for (final p in TargetPlatform.values) p: const _NoTransitions(),
        },
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: child!,
    ),
    home: Scaffold(body: home),
  );
}

Widget _open(BuildContext context, CloseContainerActionCallback<void> action) {
  return GestureDetector(
    key: _closeKey,
    behavior: HitTestBehavior.opaque,
    onTap: () => action(),
    child: const SizedBox.expand(
      key: _openKey,
      child: ColoredBox(color: Colors.red),
    ),
  );
}

Widget _container({double tilt = 0.0}) {
  return Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: OpenContainer<void>(
        transitionDuration: const Duration(milliseconds: 400),
        peakTiltY: tilt,
        peakTiltX: tilt,
        closedBuilder: (context, open) => GestureDetector(
          onTap: open,
          child: const SizedBox(
            key: _tileKey,
            width: 100,
            height: 50,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
        openBuilder: _open,
      ),
    ),
  );
}

// Painted rect of the open content (includes any FittedBox scaling).
Rect _openRect(WidgetTester tester) => tester.getRect(find.byKey(_openKey));

Rect _navRect(WidgetTester tester) => tester.getRect(find.byType(Navigator));

bool _hasTilt(WidgetTester tester) {
  return tester.widgetList<Transform>(find.descendant(of: find.byType(Overlay), matching: find.byType(Transform))).any((
    t,
  ) {
    final m = t.transform;
    return m.entry(3, 2) != 0 || m.entry(0, 2) != 0 || m.entry(1, 2) != 0;
  });
}

void main() {
  setUp(() => OpenContainer.activeProgress.value = 0);

  testWidgets('reduced: mid-open the open content is full-navigator size and untilted', (tester) async {
    await tester.pumpWidget(_app(_container(tilt: 0.1), reduce: true));
    await tester.tap(find.byKey(_tileKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Rect nav = _navRect(tester);
    expect(_openRect(tester), nav);
    expect(_hasTilt(tester), isFalse);
    expect(OpenContainer.activeProgress.value, inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(_openRect(tester), nav);
  });

  testWidgets('control: flag off morphs the rect and tilts', (tester) async {
    await tester.pumpWidget(_app(_container(tilt: 0.1), reduce: false));
    await tester.tap(find.byKey(_tileKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_openRect(tester), isNot(_navRect(tester)));
    expect(_hasTilt(tester), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('reduced: open -> close round trip restores the tile and resets progress', (tester) async {
    await tester.pumpWidget(_app(_container(), reduce: true));
    await tester.tap(find.byKey(_tileKey));
    await tester.pumpAndSettle();
    expect(OpenContainer.activeProgress.value, 1.0);

    await tester.tap(find.byKey(_closeKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_openRect(tester), _navRect(tester));
    await tester.pumpAndSettle();

    expect(find.byKey(_openKey), findsNothing);
    expect(find.byKey(_tileKey).hitTestable(), findsOneWidget);
    expect(OpenContainer.activeProgress.value, 0.0);
  });

  testWidgets('reduced: closing mid-open (interruption) still settles cleanly', (tester) async {
    await tester.pumpWidget(_app(_container(), reduce: true));
    await tester.tap(find.byKey(_tileKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final NavigatorState nav = tester.state(find.byType(Navigator));
    nav.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byKey(_openKey), findsNothing);
    expect(find.byKey(_tileKey).hitTestable(), findsOneWidget);
    expect(OpenContainer.activeProgress.value, 0.0);
  });

  testWidgets('reduced: MorphRecede stays at scale 1.0 at progress 1', (tester) async {
    final progress = ValueNotifier<double>(1.0);
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      _app(
        MorphRecede(
          progress: progress,
          child: const SizedBox.expand(key: _tileKey),
        ),
        reduce: true,
      ),
    );
    expect(tester.getRect(find.byKey(_tileKey)), _navRect(tester));
  });

  testWidgets('control: MorphRecede scales when the flag is off', (tester) async {
    final progress = ValueNotifier<double>(1.0);
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      _app(
        MorphRecede(
          progress: progress,
          child: const SizedBox.expand(key: _tileKey),
        ),
        reduce: false,
      ),
    );
    expect(tester.getRect(find.byKey(_tileKey)).width / _navRect(tester).width, closeTo(0.94, 1e-6));
  });

  testWidgets('reduced: MorphTile card rect is unchanged while held', (tester) async {
    Widget tile() => Align(
      alignment: Alignment.topLeft,
      child: MorphTile<void>(
        pressedOverlayColor: Colors.black12,
        closedBuilder: (context) => const SizedBox(key: _tileKey, width: 100, height: 50),
        openBuilder: _open,
      ),
    );

    for (final reduce in [true, false]) {
      await tester.pumpWidget(_app(tile(), reduce: reduce));
      final Rect before = tester.getRect(find.byKey(_tileKey));
      final TestGesture g = await tester.startGesture(tester.getCenter(find.byKey(_tileKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final Rect held = tester.getRect(find.byKey(_tileKey));
      if (reduce) {
        expect(held, before);
      } else {
        expect(held.width, lessThan(before.width));
      }
      await g.cancel();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('reduced via the platform accessibility feature reaches the route', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _container())));
    await tester.tap(find.byKey(_tileKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_openRect(tester), _navRect(tester));
    await tester.pumpAndSettle();
  });

  group('iOS path: AccessibilityFeatures.reduceMotion (disableAnimations false)', () {
    void enableIosReduceMotion(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    testWidgets('route cross-fades full-screen with no tilt mid-transition', (tester) async {
      enableIosReduceMotion(tester);
      await tester.pumpWidget(_app(_container(tilt: 0.1), reduce: false));
      await tester.tap(find.byKey(_tileKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(OpenContainer.activeProgress.value, inExclusiveRange(0, 1));
      expect(_openRect(tester), _navRect(tester));
      expect(_hasTilt(tester), isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('MorphRecede stays at scale 1.0 at progress 1', (tester) async {
      enableIosReduceMotion(tester);
      final progress = ValueNotifier<double>(0.0);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        _app(
          MorphRecede(
            progress: progress,
            child: const SizedBox.expand(key: _tileKey),
          ),
          reduce: false,
        ),
      );
      progress.value = 1.0;
      await tester.pump();
      expect(tester.getRect(find.byKey(_tileKey)), _navRect(tester));
    });

    testWidgets('MorphRecede reacts to a toggle on the next progress tick', (tester) async {
      final progress = ValueNotifier<double>(1.0);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        _app(
          MorphRecede(
            progress: progress,
            child: const SizedBox.expand(key: _tileKey),
          ),
          reduce: false,
        ),
      );
      expect(tester.getRect(find.byKey(_tileKey)).width, lessThan(_navRect(tester).width));
      enableIosReduceMotion(tester);
      progress.value = 0.99;
      await tester.pump();
      expect(tester.getRect(find.byKey(_tileKey)), _navRect(tester));
    });

    testWidgets('MorphTile does not press-scale', (tester) async {
      enableIosReduceMotion(tester);
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topLeft,
            child: MorphTile<void>(
              closedBuilder: (context) => const SizedBox(key: _tileKey, width: 100, height: 50),
              openBuilder: _open,
            ),
          ),
          reduce: false,
        ),
      );
      final Rect before = tester.getRect(find.byKey(_tileKey));
      final TestGesture g = await tester.startGesture(tester.getCenter(find.byKey(_tileKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getRect(find.byKey(_tileKey)), before);
      await g.cancel();
      await tester.pumpAndSettle();
    });
  });
}
