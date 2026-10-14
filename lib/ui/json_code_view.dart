import 'dart:convert';

import 'package:flutter/material.dart';

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
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final tokens = RegExp(
      r'"(?:\\.|[^"\\])*"|true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',
    );
    final spans = <TextSpan>[];
    var offset = 0;
    for (final match in tokens.allMatches(_document)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: _document.substring(offset, match.start)));
      }
      final token = match.group(0)!;
      final isKey =
          token.startsWith('"') &&
          match.end < _document.length &&
          _document[match.end] == ':';
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
    spans.add(TextSpan(text: _document.substring(offset)));
    final lineCount = '\n'.allMatches(_document).length + 1;
    return DecoratedBox(
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
                ExcludeSemantics(
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: colors.line)),
                    ),
                    child: Text(
                      List.generate(
                        lineCount,
                        (index) => '${index + 1}',
                      ).join('\n'),
                      textAlign: TextAlign.right,
                      style: mono.copyWith(color: colors.muted),
                    ),
                  ),
                ),
                SelectableText.rich(
                  TextSpan(children: spans),
                  style: mono.copyWith(
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
}
