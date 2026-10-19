/// Typesets formulas and constraint strings in the math font: ASCII connectives
/// become ¬ ∧ ∨ → ⊤ ⊥, variables are italic. Works token by token, so it also
/// renders half-typed input that does not parse yet.
library;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

final _ident = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
const _upright = {'min', 'max', 'Sub', 'pairs', 'on', 'for'};
const _greek = 'φψχαβγ';

/// Spans for [src]. With [ascii] the input syntax (~ ! & | -> T F) is translated;
/// without it only Unicode connectives are recognised, so `|` stays literal.
List<InlineSpan> mathSpans(String src, TextStyle style, {bool ascii = true}) {
  final italic = style.copyWith(fontStyle: FontStyle.italic);
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  var bufItalic = false;
  var last = ''; // last character emitted
  var pendingSpace = false;
  bool wordEnd(String c) => c.isNotEmpty && (RegExp(r'[A-Za-z0-9_)⊤⊥]').hasMatch(c) || _greek.contains(c));
  bool wordStart(String c) => RegExp(r'[A-Za-z0-9_(⊤⊥¬]').hasMatch(c) || _greek.contains(c);
  void emit(String s, {bool it = false}) {
    // Operators bring their own spacing; source whitespace is kept only
    // between word-like tokens ("for (p ∧ q)").
    if (pendingSpace && wordEnd(last) && wordStart(s[0])) s = ' $s';
    pendingSpace = false;
    if (buf.isNotEmpty && it != bufItalic) {
      spans.add(TextSpan(text: buf.toString(), style: bufItalic ? italic : style));
      buf.clear();
    }
    bufItalic = it;
    buf.write(s);
    last = s[s.length - 1];
  }

  var i = 0;
  while (i < src.length) {
    final ch = src[i];
    if (ch.trim().isEmpty) {
      pendingSpace = true;
      i++;
    } else if (src.startsWith('→', i) || (ascii && src.startsWith('->', i))) {
      emit(' → ');
      i += ch == '→' ? 1 : 2;
    } else if (ch == '¬' || (ascii && (ch == '~' || ch == '!'))) {
      emit('¬');
      i++;
    } else if (ch == '∧' || (ascii && ch == '&')) {
      emit(' ∧ ');
      i++;
    } else if (ch == '∨' || (ascii && ch == '|')) {
      emit(' ∨ ');
      i++;
    } else if ('<>=≤≥'.contains(ch)) {
      emit(' $ch ');
      i++;
    } else if (ch == ',') {
      emit(', ');
      i++;
    } else if (_greek.contains(ch)) {
      emit(ch, it: true);
      i++;
    } else {
      final m = _ident.matchAsPrefix(src, i);
      if (m == null) {
        emit(ch);
        i++;
        continue;
      }
      final tok = m[0]!;
      if (ascii && tok == 'T') {
        emit('⊤');
      } else if (ascii && tok == 'F') {
        emit('⊥');
      } else {
        emit(tok, it: !_upright.contains(tok));
      }
      i = m.end;
    }
  }
  if (buf.isNotEmpty) spans.add(TextSpan(text: buf.toString(), style: bufItalic ? italic : style));
  return spans;
}

/// `v((p ∧ q)) < v(⊤)` → `v(p ∧ q) < v(⊤)`: drops the outer parentheses that
/// `Formula.toString` puts around binary compounds when they sit inside v(…).
String tidyConstraint(String s) {
  var out = s;
  var from = 0;
  while (true) {
    final i = out.indexOf('v((', from);
    if (i < 0) return out;
    final open = i + 2;
    var depth = 0, j = open;
    for (; j < out.length; j++) {
      if (out[j] == '(') depth++;
      if (out[j] == ')' && --depth == 0) break;
    }
    if (j + 1 < out.length && out[j + 1] == ')') {
      out = out.substring(0, open) + out.substring(open + 1, j) + out.substring(j + 1);
    }
    from = open;
  }
}

class MathText extends StatelessWidget {
  final String source;
  final double size;
  final Color color;
  final FontWeight weight;
  final bool ascii;
  const MathText(this.source,
      {super.key, this.size = 16, this.color = AppColors.ink, this.weight = FontWeight.w400, this.ascii = true});

  @override
  Widget build(BuildContext context) {
    final style = AppText.math(size: size, color: color, weight: weight);
    return Text.rich(TextSpan(style: style, children: mathSpans(source, style, ascii: ascii)));
  }
}
