import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import 'components.dart';
import 'json_code_view.dart';
import 'json_tree_view.dart';

class JsonBeautifyScreen extends StatefulWidget {
  const JsonBeautifyScreen({super.key});

  @override
  State<JsonBeautifyScreen> createState() => _JsonBeautifyScreenState();
}

class _JsonBeautifyScreenState extends State<JsonBeautifyScreen> {
  final _input = TextEditingController();
  final _outputScroll = ScrollController();
  dynamic _result;
  bool _hasResult = false;
  bool _tree = false;
  int _revision = 0;
  double _inputFraction = .5;
  bool _dividerHovered = false;
  bool _dividerDragging = false;

  @override
  void dispose() {
    _input.dispose();
    _outputScroll.dispose();
    super.dispose();
  }

  void _format() {
    try {
      final result = jsonDecode(_input.text);
      setState(() {
        _result = result;
        _hasResult = true;
        _revision++;
      });
      if (_outputScroll.hasClients) _outputScroll.jumpTo(0);
    } on FormatException catch (error) {
      final offset = (error.offset ?? 0).clamp(0, _input.text.length);
      final beforeError = _input.text.substring(0, offset);
      final line = '\n'.allMatches(beforeError).length + 1;
      final column = offset - beforeError.lastIndexOf('\n');
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: context.palette.warning,
          ),
          title: Text(context.l10n.invalidJson),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(error.message, style: mono),
                const SizedBox(height: 12),
                Text(
                  context.l10n.jsonErrorAt(line, column),
                  style: TextStyle(color: context.palette.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.gotIt),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter, control: true): _format,
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): _format,
    },
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - 16;
          final minWidth = math.min(240.0, availableWidth / 2);
          final inputWidth = (availableWidth * _inputFraction).clamp(
            minWidth,
            availableWidth - minWidth,
          );
          void resize(double width) => setState(
            () => _inputFraction =
                width.clamp(minWidth, availableWidth - minWidth) /
                availableWidth,
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const ValueKey('json-beautify-input-pane'),
                width: inputWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Text(
                            context.l10n.jsonInput,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.palette.muted,
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            key: const ValueKey('format-json'),
                            onPressed: _format,
                            icon: const Icon(
                              Icons.auto_fix_high_rounded,
                              size: 16,
                            ),
                            label: Text(context.l10n.formatJson),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('json-beautify-input'),
                        controller: _input,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        style: mono,
                        textAlignVertical: TextAlignVertical.top,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: '{"name": "value"}',
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _divider(inputWidth, availableWidth, resize),
              Expanded(
                key: const ValueKey('json-beautify-output-pane'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          _viewTabs(),
                          const Spacer(),
                          IconButton(
                            tooltip: context.l10n.copyFormattedJson,
                            onPressed: _hasResult
                                ? () => copyText(
                                    context,
                                    const JsonEncoder.withIndent(
                                      '  ',
                                    ).convert(_result),
                                  )
                                : null,
                            icon: const Icon(Icons.copy_outlined, size: 17),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: !_hasResult
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.palette.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: context.palette.line),
                              ),
                              child: Center(
                                child: Text(
                                  context.l10n.formattedJson,
                                  style: TextStyle(
                                    color: context.palette.muted,
                                  ),
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) => Scrollbar(
                                controller: _outputScroll,
                                child: SingleChildScrollView(
                                  controller: _outputScroll,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: _tree
                                        ? JsonTreeView(
                                            key: ValueKey(_revision),
                                            value: _result,
                                          )
                                        : JsonCodeView(value: _result),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _divider(
    double inputWidth,
    double availableWidth,
    ValueChanged<double> resize,
  ) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: context.l10n.resizeJsonPanels,
    onIncrease: () => resize(inputWidth + 32),
    onDecrease: () => resize(inputWidth - 32),
    child: MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _dividerHovered = true),
      onExit: (_) => setState(() => _dividerHovered = false),
      child: GestureDetector(
        key: const ValueKey('json-beautify-divider'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          resize(inputWidth);
          setState(() => _dividerDragging = true);
        },
        onHorizontalDragUpdate: (details) =>
            resize(_inputFraction * availableWidth + details.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dividerDragging = false),
        onHorizontalDragCancel: () => setState(() => _dividerDragging = false),
        onDoubleTap: () => resize(availableWidth / 2),
        child: SizedBox(
          width: 16,
          child: Center(
            child: Container(
              width: _dividerHovered || _dividerDragging ? 3 : 1,
              color: _dividerHovered || _dividerDragging
                  ? context.palette.accent
                  : context.palette.line,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _viewTabs() => SizedBox(
    width: 144,
    height: 34,
    child: DefaultTabController(
      length: 2,
      child: Material(
        color: context.palette.input,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: TabBar(
            onTap: (index) => setState(() => _tree = index == 1),
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: context.palette.primaryFill,
              borderRadius: BorderRadius.circular(30),
            ),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            labelColor: Colors.white,
            unselectedLabelColor: context.palette.muted,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            labelPadding: EdgeInsets.zero,
            tabs: [
              const Tab(text: 'JSON'),
              Tab(text: context.l10n.treeTab),
            ],
          ),
        ),
      ),
    ),
  );
}
