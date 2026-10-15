import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'components.dart';

/// A selectable JSON document; the gutter is kept out of copied text.
class JsonCodeView extends StatefulWidget {
  const JsonCodeView({super.key, required this.value});
  final dynamic value;

  @override
  State<JsonCodeView> createState() => _JsonCodeViewState();
}

class _JsonCodeViewState extends State<JsonCodeView> {
  final _scroll = ScrollController();
  late String _document;
  late List<String> _lines;
  final _ranges = <int, int>{};
  final _collapsed = <int>{};

  @override
  void initState() {
    super.initState();
    _format();
  }

  @override
  void didUpdateWidget(JsonCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _format();
  }

  void _format() {
    _document = const JsonEncoder.withIndent('  ').convert(widget.value);
    _lines = _document.split('\n');
    _ranges.clear();
    _collapsed.clear();
    final openings = <int>[];
    var line = 0;
    var inString = false;
    var escaped = false;
    for (final character in _document.codeUnits) {
      if (character == 10) line++;
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (character == 92) {
          escaped = true;
        } else if (character == 34) {
          inString = false;
        }
      } else if (character == 34) {
        inString = true;
      } else if (character == 123 || character == 91) {
        openings.add(line);
      } else if (character == 125 || character == 93) {
        final start = openings.removeLast();
        if (start < line) _ranges[start] = line;
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final codeStyle = DefaultTextStyle.of(context).style.merge(mono);
    final visibleLines = <int>[];
    final visibleText = <String>[];
    for (var line = 0; line < _lines.length; line++) {
      visibleLines.add(line);
      final end = _ranges[line];
      if (end != null && _collapsed.contains(line)) {
        visibleText.add('${_lines[line]} … ${_lines[end].trimLeft()}');
        line = end;
      } else {
        visibleText.add(_lines[line]);
      }
    }
    final document = visibleText.join('\n');
    final tokens = RegExp(
      r'"(?:\\.|[^"\\])*"|true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',
    );
    final spans = <TextSpan>[];
    var offset = 0;
    for (final match in tokens.allMatches(document)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: document.substring(offset, match.start)));
      }
      final token = match.group(0)!;
      final isKey =
          token.startsWith('"') &&
          match.end < document.length &&
          document[match.end] == ':';
      final color = token.startsWith('"')
          ? (isKey ? colors.info : colors.string)
          : token == 'null'
          ? colors.muted
          : token == 'true' || token == 'false'
          ? colors.method
          : colors.warning;
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(color: color),
        ),
      );
      offset = match.end;
    }
    spans.add(TextSpan(text: document.substring(offset)));
    final strut = StrutStyle.fromTextStyle(codeStyle, forceStrutHeight: true);
    final metrics = TextPainter(
      text: TextSpan(text: document, style: codeStyle),
      strutStyle: strut,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final lineMetrics = metrics.computeLineMetrics();
    final documentHeight = metrics.height;
    metrics.text = TextSpan(text: '${_lines.length}', style: codeStyle);
    metrics.layout();
    final numberWidth = metrics.width.ceilToDouble();
    metrics.dispose();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 12, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: colors.line)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: SizedBox(
                          width: numberWidth,
                          child: Text(
                            visibleLines
                                .map((line) => '${line + 1}')
                                .join('\n'),
                            key: const ValueKey('json-line-numbers'),
                            softWrap: false,
                            textAlign: TextAlign.right,
                            strutStyle: strut,
                            style: codeStyle.copyWith(color: colors.muted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 20,
                        height: documentHeight,
                        child: Stack(
                          children: [
                            for (
                              var index = 0;
                              index < visibleLines.length;
                              index++
                            )
                              if (_ranges.containsKey(visibleLines[index]))
                                Positioned(
                                  top:
                                      lineMetrics[index].baseline -
                                      lineMetrics[index].ascent,
                                  height: lineMetrics[index].height,
                                  left: 0,
                                  right: 0,
                                  child: _foldButton(visibleLines[index]),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SelectableText.rich(
                  TextSpan(children: spans),
                  strutStyle: strut,
                  style: codeStyle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _foldButton(int line) {
    final collapsed = _collapsed.contains(line);
    return Tooltip(
      message: collapsed
          ? context.l10n.expandJsonRange
          : context.l10n.collapseJsonRange,
      child: Semantics(
        button: true,
        expanded: !collapsed,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('json-fold-$line'),
            borderRadius: BorderRadius.circular(3),
            onTap: () => setState(() {
              if (collapsed) {
                _collapsed.remove(line);
              } else {
                _collapsed.add(line);
              }
            }),
            child: Icon(
              collapsed
                  ? Icons.chevron_right_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: context.palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}
