import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/capture.dart';
import 'viewer_theme.dart';
import '../l10n/strings.dart';
import 'json_code_view.dart';
import 'json_tree_view.dart';

export 'viewer_theme.dart';

const mono = TextStyle(
  fontFamily: 'JetBrains Mono',
  fontSize: 12,
  height: 1.65,
);

String clockTime(DateTime? date) => date == null
    ? '—'
    : '${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}:${date.toLocal().second.toString().padLeft(2, '0')}.${date.millisecond.toString().padLeft(3, '0')}';

Future<void> copyText(
  BuildContext context,
  String text, [
  String? message,
]) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? context.l10n.copied),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (color ?? context.palette.accent).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color ?? context.palette.accent,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.action,
  });
  final IconData icon;
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.palette.accent.withValues(alpha: .06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: context.palette.accent),
            ),
            SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            if (action != null) ...[SizedBox(height: 22), action!],
          ],
        ),
      ),
    ),
  );
}

class DataSection extends StatefulWidget {
  const DataSection(
    this.title,
    this.value, {
    super.key,
    this.body = false,
    this.initiallyExpanded = true,
  });
  final String title;
  final dynamic value;
  final bool body;
  final bool initiallyExpanded;

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  bool _tree = false;
  late dynamic _decoded;
  late bool _isJson;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(DataSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value || widget.body != oldWidget.body) {
      _decode();
    }
  }

  void _decode() {
    _decoded = widget.value;
    _isJson = _decoded is Map || _decoded is List;
    if (widget.body && widget.value is String) {
      try {
        _decoded = jsonDecode(widget.value as String);
        _isJson = true;
      } on FormatException {
        /* plain text */
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final value = widget.value;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: context.palette.muted,
                  ),
                ),
              ),
              if (widget.body && _isJson) ...[
                SizedBox(
                  width: 128,
                  height: 30,
                  child: DefaultTabController(
                    length: 2,
                    initialIndex: _tree ? 1 : 0,
                    child: Material(
                      color: context.palette.input,
                      borderRadius: BorderRadius.circular(30),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: TabBar(
                          splashBorderRadius: BorderRadius.circular(30),
                          onTap: (index) => setState(() => _tree = index == 1),
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: context.palette.surface,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: context.palette.line),
                          ),
                          labelColor: context.palette.accent,
                          unselectedLabelColor: context.palette.muted,
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(fontSize: 11),
                          labelPadding: EdgeInsets.zero,
                          tabs: [
                            Tooltip(
                              message: context.l10n.formattedJson,
                              child: const Tab(text: 'JSON'),
                            ),
                            Tooltip(
                              message: context.l10n.treeView,
                              child: Tab(text: context.l10n.treeTab),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (value != null)
                IconButton(
                  tooltip: context.l10n.copySection(title),
                  iconSize: 15,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => copyText(context, pretty(value)),
                  icon: Icon(Icons.copy_outlined),
                ),
            ],
          ),
          SizedBox(height: 6),
          if (value == null || !widget.body && value is Map && value.isEmpty)
            Text(
              context.l10n.notCaptured,
              style: TextStyle(
                color: context.palette.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (widget.body && _isJson && !_tree)
            JsonCodeView(value: _decoded)
          else if (widget.body && _isJson && _tree)
            JsonTreeView(
              value: _decoded,
              initiallyExpanded: widget.initiallyExpanded,
            )
          else if (_decoded is Map || _decoded is List)
            JsonTree(
              value: _decoded,
              initiallyExpanded: widget.initiallyExpanded,
            )
          else
            SelectableText('$value', style: mono),
        ],
      ),
    );
  }
}

/// Expand objects lazily: large structured console arguments stay navigable.
class JsonTree extends StatelessWidget {
  const JsonTree({
    super.key,
    required this.value,
    this.name,
    this.depth = 0,
    this.initiallyExpanded,
  });
  final dynamic value;
  final String? name;
  final int depth;
  final bool? initiallyExpanded;
  @override
  Widget build(BuildContext context) {
    final label = name == null ? '' : '$name: ';
    if (value is Map || value is List) {
      final entries = value is Map
          ? (value as Map).entries.toList()
          : (value as List).asMap().entries.toList();
      final bracket = value is Map ? '{…}' : '[…]';
      if (entries.isEmpty) {
        return SelectableText(
          '$label${value is Map ? '{}' : '[]'}',
          style: mono,
        );
      }
      return ExpansionTile(
        key: ValueKey('$depth:$name'),
        initiallyExpanded: initiallyExpanded ?? depth < 1,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(left: 14),
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: Border(),
        collapsedShape: Border(),
        title: Text(
          '$label$bracket  ${context.l10n.itemCount(entries.length)}',
          style: mono.copyWith(color: context.palette.accent),
        ),
        children: entries
            .map(
              (e) => Align(
                alignment: Alignment.centerLeft,
                child: JsonTree(
                  value: e.value,
                  name: '${e.key}',
                  depth: depth + 1,
                ),
              ),
            )
            .toList(),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: SelectableText(
        '$label${jsonEncode(value)}',
        style: mono.copyWith(
          color: value is String
              ? context.palette.string
              : context.palette.warning,
        ),
      ),
    );
  }
}
