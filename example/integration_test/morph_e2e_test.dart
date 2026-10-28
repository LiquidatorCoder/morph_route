// End-to-end checks for the morph_route demo, run on a real simulator/device:
//
//   flutter test integration_test -d <device-id>
//
// Scenarios that animate print one `PERF {json}` line with tap-to-motion
// latency, morph duration and engine frame timings (build/raster), so runs can
// be compared across builds.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:morph_route/morph_route.dart';
import 'package:morph_route_example/main.dart' as app;

const _tiles = ['send', 'receive', 'swap', 'borrow'];

Finder _tile(String id) => find.byKey(ValueKey('tile-$id'));
Finder get _close => find.byTooltip('Close');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> launch(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    for (final id in _tiles) {
      expect(_tile(id), findsOneWidget, reason: 'tile-$id');
    }
  }

  Future<void> openTile(WidgetTester tester, String id) async {
    await tester.ensureVisible(_tile(id));
    await tester.pumpAndSettle();
    await tester.tap(_tile(id));
    await tester.pumpAndSettle();
    expect(_close, findsOneWidget);
    expect(OpenContainer.activeProgress.value, 1.0);
  }

  Future<void> closeRoute(WidgetTester tester) async {
    await tester.tap(_close);
    await tester.pumpAndSettle();
    expect(_close, findsNothing);
    expect(OpenContainer.activeProgress.value, 0.0);
  }

  testWidgets('every tile: open → close, latency and frame timings', (tester) async {
    await launch(tester);
    for (final id in _tiles) {
      final perf = _FrameRecorder()..start();
      final opens = <_Latency>[];
      final closes = <_Latency>[];
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(_tile(id));
        await tester.pumpAndSettle();
        final rest = tester.getRect(_tile(id));
        final open = _Latency(opening: true)..arm();
        await tester.tap(_tile(id));
        await tester.pumpAndSettle();
        opens.add(open..disarm());
        expect(_close, findsOneWidget);

        final close = _Latency(opening: false)..arm();
        await tester.tap(_close);
        await tester.pumpAndSettle();
        closes.add(close..disarm());
        expect(_close, findsNothing);
        expect(tester.getRect(_tile(id)), rest, reason: 'tile-$id back at rest');
        expect(OpenContainer.activeProgress.value, 0.0);
      }
      await perf.report('tile_$id', extra: {'open': _Latency.summary(opens), 'close': _Latency.summary(closes)});
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('swap returns a value to onClosed', (tester) async {
    await launch(tester);
    await openTile(tester, 'swap');
    await tester.tap(find.byKey(const ValueKey('swap-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Swap confirmed'), findsOneWidget);
    expect(OpenContainer.activeProgress.value, 0.0);
    // Closing with the X returns null: no new snack bar.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await openTile(tester, 'swap');
    await closeRoute(tester);
    expect(find.text('Swap confirmed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page pushed on top of a morph route pops back to it', (tester) async {
    await launch(tester);
    await openTile(tester, 'borrow');
    await tester.tap(find.byKey(const ValueKey('borrow-details')));
    await tester.pumpAndSettle();
    const pushedBody = 'A regular page on top of the morph.';
    expect(find.text(pushedBody), findsOneWidget);
    expect(OpenContainer.activeProgress.value, 1.0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(pushedBody), findsNothing);
    expect(_close, findsOneWidget);
    await closeRoute(tester);
    expect(_tile('borrow').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap pushes exactly one route', (tester) async {
    await launch(tester);
    final center = tester.getCenter(_tile('send'));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_close, findsOneWidget);
    await closeRoute(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing mid-open lands back on the tile', (tester) async {
    await launch(tester);
    final rest = tester.getRect(_tile('send'));
    final perf = _FrameRecorder()..start();
    await tester.tap(_tile('send'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(_close);
    await tester.pumpAndSettle();
    await perf.report('interrupt_open');
    expect(_close, findsNothing);
    expect(tester.getRect(_tile('send')), rest);
    expect(OpenContainer.activeProgress.value, 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping where the tile was mid-close does not reopen', (tester) async {
    await launch(tester);
    final center = tester.getCenter(_tile('send'));
    await openTile(tester, 'send');
    await tester.tap(_close);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_close, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rotating while open: the close lands on the new tile rect', (tester) async {
    addTearDown(() => SystemChrome.setPreferredOrientations(const []));
    await launch(tester);
    await openTile(tester, 'send');
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Where the closing card's icon is on the last morph frame vs where the
    // tile's icon sits once the route is gone. A mismatch is a visible snap.
    // Sampled after every frame (not on fixed pumps, which can skip the end).
    Rect? lastInFlight;
    var sampling = true;
    void sample(Duration _) {
      if (!sampling) return;
      SchedulerBinding.instance.addPostFrameCallback(sample);
      final icons = find.byIcon(Icons.north_east).evaluate();
      if (OpenContainer.activeProgress.value > 0 && icons.length == 1) {
        final box = icons.single.renderObject! as RenderBox;
        lastInFlight = box.localToGlobal(Offset.zero) & box.size;
      }
    }

    SchedulerBinding.instance.addPostFrameCallback(sample);
    await tester.tap(_close);
    await tester.pumpAndSettle();
    sampling = false;
    final landed = tester.getRect(find.byIcon(Icons.north_east));
    debugPrint('ROTATE lastInFlight=$lastInFlight landed=$landed');
    expect(lastInFlight, isNotNull);
    expect((lastInFlight!.center - landed.center).distance, lessThan(4.0));

    // Landscape layout: the whole first row is on screen, labels included.
    for (final id in _tiles) {
      expect(_tile(id).hitTestable(), findsOneWidget, reason: 'tile-$id visible in landscape');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('largest accessibility text size: no overflow, every tile works', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester);
    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow at 3.1x');
    for (final id in _tiles) {
      await openTile(tester, id);
      expect(tester.takeException(), isNull, reason: 'destination $id at 3.1x');
      await closeRoute(tester);
    }
  });

  testWidgets('Reduce Motion: cross-fade, no tilt, no recede scale', (tester) async {
    // What iOS sends for Settings → Accessibility → Motion → Reduce Motion.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);
    final perf = _FrameRecorder()..start();
    final rest = tester.getRect(_tile('send'));
    final titleRest = tester.getRect(find.text('morph_route'));
    await tester.tap(_tile('send'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(OpenContainer.activeProgress.value, inExclusiveRange(0.0, 1.0));
    // Mid-transition: no perspective/rotation transform anywhere on screen.
    final tilted = tester.widgetList<Transform>(find.byType(Transform)).where((t) => t.transform.entry(3, 2) != 0);
    expect(tilted, isEmpty);
    // The home screen does not recede.
    expect(tester.getRect(find.text('morph_route')), titleRest);
    await tester.pumpAndSettle();
    await closeRoute(tester);
    await perf.report('reduce_motion');
    expect(tester.getRect(_tile('send')), rest);
    expect(tester.takeException(), isNull);
  });
}

/// Timestamps (µs since the tap) of the first frame, the first morph tick and
/// the morph reaching its end, read off [OpenContainer.activeProgress].
class _Latency {
  _Latency({required this.opening});

  final bool opening;
  final Stopwatch _sw = Stopwatch();
  int? firstTickUs;
  int? settledUs;
  int? firstFrameUs;

  void _onProgress() {
    final v = OpenContainer.activeProgress.value;
    final moved = opening ? v > 0 : v < 1;
    final done = opening ? v >= 1 : v <= 0;
    if (firstTickUs == null && moved) firstTickUs = _sw.elapsedMicroseconds;
    if (settledUs == null && done) settledUs = _sw.elapsedMicroseconds;
  }

  void arm() {
    _sw.start();
    OpenContainer.activeProgress.addListener(_onProgress);
    SchedulerBinding.instance.addPostFrameCallback((_) => firstFrameUs ??= _sw.elapsedMicroseconds);
  }

  void disarm() => OpenContainer.activeProgress.removeListener(_onProgress);

  static Map<String, Object?> summary(List<_Latency> runs) {
    double ms(int? us) => us == null ? double.nan : us / 1000;
    List<double> col(int? Function(_Latency) f) => runs.map((r) => ms(f(r))).toList()..sort();
    Map<String, double> stat(List<double> v) => {'min': v.first, 'median': v[v.length ~/ 2], 'max': v.last};
    return {
      'runs': runs.length,
      'tap_to_first_frame_ms': stat(col((r) => r.firstFrameUs)),
      'tap_to_first_tick_ms': stat(col((r) => r.firstTickUs)),
      'tap_to_settled_ms': stat(col((r) => r.settledUs)),
    };
  }
}

/// Collects engine [FrameTiming]s between [start] and [report].
class _FrameRecorder {
  final List<FrameTiming> _timings = [];

  void _onTimings(List<FrameTiming> t) => _timings.addAll(t);

  void start() => SchedulerBinding.instance.addTimingsCallback(_onTimings);

  Future<void> report(String scenario, {Map<String, Object?> extra = const {}}) async {
    // The engine batches FrameTiming reports; give it time to flush.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    List<double> sorted(Duration Function(FrameTiming) f) =>
        _timings.map((t) => f(t).inMicroseconds / 1000).toList()..sort();
    Map<String, double> pct(List<double> v) => v.isEmpty
        ? const {}
        : {
            'p50': v[(v.length * .5).floor()],
            'p90': v[((v.length - 1) * .9).round()],
            'p99': v[((v.length - 1) * .99).round()],
            'max': v.last,
          };
    const budgetMs = 1000 / 60;
    final janky = _timings
        .where(
          (t) => t.buildDuration.inMicroseconds / 1000 > budgetMs || t.rasterDuration.inMicroseconds / 1000 > budgetMs,
        )
        .length;
    debugPrint(
      'PERF ${jsonEncode({'scenario': scenario, 'mode': kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release'), 'frames': _timings.length, 'janky_frames': janky, 'build_ms': pct(sorted((t) => t.buildDuration)), 'raster_ms': pct(sorted((t) => t.rasterDuration)), ...extra})}',
    );
  }
}
