import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:godel_dpll/main.dart';
import 'package:godel_dpll/ui/equal_height_row.dart';

Future<void> loadFonts() async {
  for (final f in Directory('/private/tmp/claude-501/-Users-kiumarschaharlangi-Documents-dev-godel-dpll-flutter/207e8a02-13d2-4661-ab00-b35d80233739/scratchpad/fonts').listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last.replaceAll('.ttf', '');
    final loader = FontLoader(name)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await loader.load();
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(loadFonts);
  for (final p in [TargetPlatform.macOS, TargetPlatform.android]) {
    for (final w in [390.0, 800.0, 1000.0, 1100.0, 1280.0, 1440.0, 1920.0]) {
      testWidgets('$p $w', (t) async {
        debugDefaultTargetPlatformOverride = p;
        t.view.physicalSize = Size(w, 1400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final old = FlutterError.onError;
        FlutterError.onError = (d) { debugPrint('DETAILS $p $w: ${d.toString()}'); };
        await t.pumpWidget(const GodelDpllApp());
        await t.pump();
        for (final f in ['p -> (q -> (p & q))', 'p | ~p', '~(p&q)->~p', '(p & (q | r)) -> ((p & q) | (p & r))', 'p -> (']) {
          await t.enterText(find.byType(TextField), f);
          await t.tap(find.text('Decide'));
          await t.pump();
        }
        await t.enterText(find.byType(TextField), '~(p&q)->~p');
        await t.tap(find.text('Decide'));
        await t.pump();
        if (w >= 1000) {
          final fc = t.getSize(find.byType(EqualHeightRow).first);
          final cards = find.descendant(of: find.byType(EqualHeightRow).first, matching: find.byType(Container));
          debugPrint('ROW1 $p $w: row=$fc');
        }
        final toggleRow = find.ancestor(of: find.text('Decide'), matching: find.byType(EqualHeightRow));
        if (toggleRow.evaluate().isNotEmpty) {
          final card = find.ancestor(of: find.text('Pinning rules'), matching: find.byType(Material)).first;
          debugPrint('TOGGLES $p $w: row=${t.getSize(toggleRow.first).height} card=${t.getSize(card).height} button=${t.getSize(find.ancestor(of: find.text('Decide'), matching: find.byType(DecoratedBox)).first).height}');
        }
        debugPrint('TITLE $p $w: ${t.getSize(find.text("Gödel-DPLL"))} formula card h=${t.getSize(find.byType(IntrinsicHeight).first)}');
        FlutterError.onError = old;
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
