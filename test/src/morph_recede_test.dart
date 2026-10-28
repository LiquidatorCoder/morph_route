import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morph_route/morph_route.dart';

const _childKey = Key('recede-child');

void main() {
  // The test view is 800x600; a centred scale of s paints the child at s * 800 wide.
  double paintedScale(WidgetTester tester) => tester.getRect(find.byKey(_childKey)).width / 800;

  Future<void> pumpRecede(
    WidgetTester tester, {
    ValueNotifier<double>? progress,
    double scaleFloor = 0.9,
    Offset translate = Offset.zero,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MorphRecede(
          progress: progress,
          curve: Curves.linear,
          scaleFloor: scaleFloor,
          translateOffset: translate,
          child: const SizedBox.expand(key: _childKey),
        ),
      ),
    );
  }

  testWidgets('identity at rest, scaleFloor at full progress', (tester) async {
    final progress = ValueNotifier<double>(0);
    addTearDown(progress.dispose);
    await pumpRecede(tester, progress: progress);
    expect(paintedScale(tester), closeTo(1.0, 1e-6));
    expect(tester.getRect(find.byKey(_childKey)), const Rect.fromLTWH(0, 0, 800, 600));

    progress.value = 1;
    await tester.pump();
    expect(paintedScale(tester), closeTo(0.9, 1e-6));
    expect(tester.getRect(find.byKey(_childKey)).center, const Offset(400, 300));

    progress.value = 0.5;
    await tester.pump();
    expect(paintedScale(tester), closeTo(0.95, 1e-6));
  });

  testWidgets('clamps out-of-range progress', (tester) async {
    final progress = ValueNotifier<double>(1.7);
    addTearDown(progress.dispose);
    await pumpRecede(tester, progress: progress);
    expect(paintedScale(tester), closeTo(0.9, 1e-6));

    progress.value = -0.4;
    await tester.pump();
    expect(paintedScale(tester), closeTo(1.0, 1e-6));
  });

  testWidgets('translateOffset lerps with progress', (tester) async {
    final progress = ValueNotifier<double>(0.5);
    addTearDown(progress.dispose);
    await pumpRecede(tester, progress: progress, translate: const Offset(0, 40));
    expect(tester.getRect(find.byKey(_childKey)).center, const Offset(400, 320));
  });

  testWidgets('follows OpenContainer.activeProgress by default', (tester) async {
    addTearDown(() => OpenContainer.activeProgress.value = 0);
    await pumpRecede(tester, scaleFloor: 0.8);
    expect(paintedScale(tester), closeTo(1.0, 1e-6));

    OpenContainer.activeProgress.value = 1;
    await tester.pump();
    expect(paintedScale(tester), closeTo(0.8, 1e-6));
  });
}
