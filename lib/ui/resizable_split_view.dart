import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'viewer_theme.dart';

class ResizableSplitView extends StatefulWidget {
  const ResizableSplitView({
    super.key,
    required this.list,
    required this.inspector,
  });

  final Widget list;
  final Widget inspector;

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  static const _defaultWidth = 400.0;
  static const _minInspectorWidth = 320.0;
  static const _minListWidth = 360.0;
  static const _dividerWidth = 8.0;
  double _width = _defaultWidth;
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth - _minListWidth - _dividerWidth;
      final width = _width.clamp(_minInspectorWidth, maxWidth).toDouble();
      void resize(double nextWidth) => setState(
        () => _width = nextWidth.clamp(_minInspectorWidth, maxWidth).toDouble(),
      );

      return Row(
        children: [
          Expanded(
            key: const ValueKey('capture-list-pane'),
            child: widget.list,
          ),
          Semantics(
            label: context.l10n.resizeInspector,
            onIncrease: () => resize(width + 32),
            onDecrease: () => resize(width - 32),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                key: const ValueKey('inspector-divider'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() {
                  _dragging = true;
                  _width = width;
                }),
                onHorizontalDragUpdate: (details) =>
                    resize(_width - details.delta.dx),
                onHorizontalDragEnd: (_) => setState(() => _dragging = false),
                onHorizontalDragCancel: () => setState(() => _dragging = false),
                onDoubleTap: () => resize(_defaultWidth),
                child: SizedBox(
                  width: _dividerWidth,
                  height: double.infinity,
                  child: Center(
                    child: Container(
                      width: _hovered || _dragging ? 3 : 1,
                      color: _hovered || _dragging
                          ? context.palette.accent
                          : context.palette.line,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            key: const ValueKey('inspector-pane'),
            width: width,
            child: widget.inspector,
          ),
        ],
      );
    },
  );
}
