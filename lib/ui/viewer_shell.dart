import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../l10n/strings.dart';
import 'settings_screen.dart';

import '../models/capture.dart';
import '../services/capture_store.dart';
import '../services/viewer_server.dart';
import 'components.dart';
import 'inspector.dart';
import 'resizable_split_view.dart';

class ViewerShell extends StatefulWidget {
  const ViewerShell({
    super.key,
    required this.store,
    required this.server,
    required this.settings,
  });
  final CaptureStore store;
  final ViewerServer server;
  final AppSettings settings;
  @override
  State<ViewerShell> createState() => _ViewerShellState();
}

class _ViewerShellState extends State<ViewerShell> {
  CaptureStore get store => widget.store;
  ViewerServer get server => widget.server;
  String? _session;
  String? _networkKey;
  int? _logId;
  bool _console = false;
  String _query = '';
  String _method = 'All methods';
  String _status = 'All statuses';
  String _level = 'All levels';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
    server.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    server.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  List<NetworkRecord> get _requests => store.network.values
      .where((r) {
        if (_session != null && r.sessionId != _session) return false;
        if (_method != 'All methods' && r.method != _method) return false;
        if (_status == 'Errors' && !r.failed) return false;
        if (_status == 'Pending' && !r.pending) return false;
        if (_status == 'Success' &&
            (r.status == null || r.status! < 200 || r.status! >= 400)) {
          return false;
        }
        return '${r.method} ${r.url} ${r.state} ${r.source}'
            .toLowerCase()
            .contains(_query);
      })
      .toList()
      .reversed
      .toList();

  List<ConsoleRecord> get _logs => store.logs
      .where(
        (r) =>
            (_session == null || r.sessionId == _session) &&
            (_level == 'All levels' || r.level == _level) &&
            (_query.isEmpty ||
                '${r.message} ${pretty(r.event['args'])}'
                    .toLowerCase()
                    .contains(_query)),
      )
      .toList()
      .reversed
      .toList();

  Future<void> _export() async {
    // Snapshot before the native save panel opens, while live capture continues.
    final snapshot = pretty(store.export());
    try {
      final location = await getSaveLocation(
        suggestedName:
            'rn-capture-${DateTime.now().millisecondsSinceEpoch}.json',
        acceptedTypeGroups: [
          XTypeGroup(label: 'JSON capture', extensions: ['json']),
        ],
      );
      if (location == null) return;
      await File(location.path).writeAsString(snapshot);
      if (mounted) _notice(context.l10n.exportedTo(location.path));
    } catch (e) {
      if (mounted) _notice(context.l10n.exportFailed(e.toString()));
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _settings() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) =>
          SettingsScreen(settings: widget.settings, server: server),
    ),
  );

  void _connectionGuide() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.guideTitle),
        content: SizedBox(
          width: 610,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  "import {bootRNNetworkDebuggerWithPort}\n  from '@quocandev27/rn_network_debugger';\n\nif (__DEV__) {\n  bootRNNetworkDebuggerWithPort(${server.port});\n}",
                  style: mono.copyWith(color: context.palette.accent),
                ),
                SizedBox(height: 20),
                Text(
                  context.l10n.availableEndpoints,
                  style: TextStyle(color: context.palette.muted),
                ),
                ...server.addresses.map(
                  (ip) => Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SelectableText(
                      'ws://$ip:${server.port}/rnv/network',
                      style: mono,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  context.l10n.physicalDeviceGuide,
                  style: TextStyle(color: context.palette.muted, height: 1.6),
                ),
                SizedBox(height: 12),
                Text(context.l10n.usbGuide(server.port), style: mono),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => copyText(context, server.localUrl),
            child: Text(context.l10n.copyEndpoint),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.gotIt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    final logs = _logs;
    final selectedRequest = requests
        .where((r) => r.key == _networkKey)
        .firstOrNull;
    final selectedLog = logs.where((r) => r.id == _logId).firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (server.error != null)
              _banner(
                context.l10n.serverStartFailed(server.error!),
                context.palette.danger,
              ),
            if (store.paused)
              _banner(context.l10n.pausedBanner, context.palette.warning),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sidebar = constraints.maxWidth >= 1050;
                  final inspector =
                      constraints.maxWidth >= 1200 ||
                      (constraints.maxWidth >= 900 && !sidebar);
                  return Row(
                    children: [
                      if (sidebar) SizedBox(width: 220, child: _sidebar()),
                      Expanded(
                        child: Column(
                          children: [
                            _toolbar(),
                            _filters(sidebar),
                            Expanded(
                              child: inspector
                                  ? ResizableSplitView(
                                      list: _console
                                          ? _consoleList(logs, true)
                                          : _networkList(requests, true),
                                      inspector: _console
                                          ? selectedLog == null
                                                ? _noSelection()
                                                : ConsoleInspector(
                                                    key: ValueKey(
                                                      selectedLog.id,
                                                    ),
                                                    record: selectedLog,
                                                  )
                                          : selectedRequest == null
                                          ? _noSelection()
                                          : NetworkInspector(
                                              key: ValueKey(
                                                selectedRequest.key,
                                              ),
                                              record: selectedRequest,
                                            ),
                                    )
                                  : _console
                                  ? _consoleList(logs, false)
                                  : _networkList(requests, false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: Border(bottom: BorderSide(color: context.palette.line)),
    ),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.palette.accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.hub_outlined,
            color: context.palette.accent,
            size: 22,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'RN Network Viewer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        StatusChip(
          server.busy
              ? context.l10n.starting
              : server.running
              ? context.l10n.listening(server.port)
              : context.l10n.serverStopped,
          color: server.running
              ? context.palette.accent
              : context.palette.muted,
        ),
        SizedBox(width: 8),
        IconButton(
          tooltip: server.running
              ? context.l10n.stopServer
              : context.l10n.startServer,
          onPressed: server.busy
              ? null
              : () async {
                  if (server.running) {
                    await server.stop();
                  } else {
                    await server.start(
                      port:
                          widget.settings.preferences?.getInt('viewerPort') ??
                          server.port,
                    );
                  }
                },
          icon: Icon(
            server.running
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline,
            size: 21,
          ),
        ),
        IconButton(
          tooltip: context.l10n.settings,
          onPressed: _settings,
          icon: Icon(Icons.settings_outlined, size: 20),
        ),
        IconButton(
          tooltip: context.l10n.connectionGuide,
          onPressed: _connectionGuide,
          icon: Icon(Icons.help_outline, size: 20),
        ),
      ],
    ),
  );

  Widget _sidebar() => Container(
    decoration: BoxDecoration(
      color: context.palette.sidebar,
      border: Border(right: BorderSide(color: context.palette.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            context.l10n.workspace,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              color: context.palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _sessionTile(
          null,
          context.l10n.allSessions,
          context.l10n.sessionCount(store.sessions.length),
          Icons.devices_outlined,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 10),
          child: Text(
            context.l10n.applications,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              color: context.palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: store.sessions.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    context.l10n.noApps,
                    style: TextStyle(color: context.palette.muted, height: 1.7),
                  ),
                )
              : ListView(
                  children: store.sessions.values
                      .map(
                        (s) => _sessionTile(
                          s.id,
                          s.name,
                          '${s.device} · ${s.id.substring(0, s.id.length.clamp(0, 6))}',
                          s.platform == 'ios'
                              ? Icons.phone_iphone
                              : Icons.android,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    ),
  );

  Widget _sessionTile(
    String? id,
    String title,
    String subtitle,
    IconData icon,
  ) => Container(
    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: _session == id
          ? context.palette.accent.withValues(alpha: .08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
    ),
    child: ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10),
      leading: Icon(
        icon,
        size: 20,
        color: _session == id ? context.palette.accent : context.palette.muted,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, color: context.palette.muted),
      ),
      trailing: id == null
          ? null
          : Tooltip(
              message: server.isOnline(id)
                  ? context.l10n.connected
                  : context.l10n.disconnected,
              child: Icon(
                Icons.circle,
                size: 7,
                color: server.isOnline(id)
                    ? context.palette.accent
                    : context.palette.muted,
              ),
            ),
      onTap: () => setState(() {
        _session = id;
        _networkKey = null;
        _logId = null;
      }),
    ),
  );

  Widget _toolbar() => Padding(
    padding: EdgeInsets.fromLTRB(20, 16, 12, 12),
    child: Row(
      children: [
        _tab(
          context.l10n.network,
          Icons.swap_vert,
          false,
          store.network.length,
        ),
        SizedBox(width: 6),
        _tab(context.l10n.console, Icons.terminal, true, store.logs.length),
        Spacer(),
        IconButton(
          tooltip: store.paused
              ? context.l10n.resumeCapture
              : context.l10n.pauseCapture,
          onPressed: store.togglePause,
          icon: Icon(
            store.paused ? Icons.play_arrow : Icons.pause,
            size: 20,
            color: store.paused ? context.palette.warning : null,
          ),
        ),
        IconButton(
          tooltip: context.l10n.clearCapture,
          onPressed: () {
            store.clear();
            setState(() {
              _networkKey = null;
              _logId = null;
            });
          },
          icon: Icon(Icons.delete_sweep_outlined, size: 20),
        ),
        IconButton(
          tooltip: context.l10n.exportCapture,
          onPressed: store.network.isEmpty && store.logs.isEmpty
              ? null
              : _export,
          icon: Icon(Icons.file_download_outlined, size: 20),
        ),
      ],
    ),
  );

  Widget _tab(String name, IconData icon, bool console, int count) =>
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: _console == console
              ? context.palette.accent
              : context.palette.muted,
          backgroundColor: _console == console
              ? context.palette.accent.withValues(alpha: .08)
              : Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        ),
        onPressed: () => setState(() {
          _console = console;
        }),
        child: Row(
          children: [
            Icon(icon, size: 17),
            SizedBox(width: 8),
            Text(name),
            SizedBox(width: 8),
            Text('$count', style: TextStyle(fontSize: 11)),
          ],
        ),
      );

  Widget _filters(bool sidebar) => Container(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.palette.line)),
    ),
    child: Column(
      children: [
        if (!sidebar)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              key: ValueKey(_session),
              initialValue: _session ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: context.l10n.session),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(context.l10n.allSessions),
                ),
                ...store.sessions.values.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.name} · ${s.device} · ${s.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                _session = value == '' ? null : value;
              }),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: _console
                      ? context.l10n.searchConsole
                      : context.l10n.searchNetwork,
                  prefixIcon: Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.clearSearch,
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                          icon: Icon(Icons.close, size: 16),
                        ),
                ),
              ),
            ),
            SizedBox(width: 10),
            if (_console)
              _dropdown(
                _level,
                ['All levels', 'log', 'info', 'warn', 'error', 'debug'],
                (v) => setState(() => _level = v),
                125,
              )
            else ...[
              _dropdown(
                _method,
                [
                  'All methods',
                  'GET',
                  'POST',
                  'PUT',
                  'PATCH',
                  'DELETE',
                  'HEAD',
                  'OPTIONS',
                ],
                (v) => setState(() => _method = v),
                135,
              ),
              SizedBox(width: 8),
              _dropdown(
                _status,
                ['All statuses', 'Success', 'Errors', 'Pending'],
                (v) => setState(() => _status = v),
                135,
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _dropdown(
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
    double width,
  ) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      items: values
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text(
                filterLabel(context, v),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );

  Widget _networkList(List<NetworkRecord> requests, bool inspector) {
    if (requests.isEmpty) return _empty(store.network.isEmpty);
    return Column(
      children: [
        Container(
          height: 33,
          padding: EdgeInsets.symmetric(horizontal: 18),
          color: context.palette.surface,
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  context.l10n.methodColumn,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.palette.muted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.l10n.urlColumn,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.palette.muted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              SizedBox(
                width: 82,
                child: Text(
                  context.l10n.statusColumn,
                  style: TextStyle(fontSize: 9, color: context.palette.muted),
                ),
              ),
              SizedBox(
                width: 82,
                child: Text(
                  context.l10n.timeColumn,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 9, color: context.palette.muted),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: requests.length,
            itemExtent: 68,
            itemBuilder: (context, index) {
              final r = requests[index];
              final uri = Uri.tryParse(r.url);
              final path = uri == null || uri.host.isEmpty
                  ? (r.request.isEmpty ? context.l10n.missingRequest : r.url)
                  : '${uri.path.isEmpty ? '/' : uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
              return Material(
                color: _networkKey == r.key
                    ? context.palette.accent.withValues(alpha: .07)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _networkKey = r.key);
                    if (!inspector) _detail(() => NetworkInspector(record: r));
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.palette.line),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusChip(
                              r.method,
                              color: r.method == 'GET'
                                  ? context.palette.accent
                                  : context.palette.method,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${uri?.host ?? ''} · ${store.sessions[r.sessionId]?.name ?? ''} · ${clockTime(r.time)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 82,
                          child: Text(
                            filterLabel(context, r.state),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: r.failed
                                  ? context.palette.danger
                                  : r.pending
                                  ? context.palette.muted
                                  : context.palette.accent,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 82,
                          child: Text(
                            r.duration == null ? '—' : '${r.duration} ms',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _consoleList(List<ConsoleRecord> logs, bool inspector) {
    if (logs.isEmpty) return _empty(store.logs.isEmpty);
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final r = logs[index];
        final color = r.level == 'error'
            ? context.palette.danger
            : r.level == 'warn'
            ? context.palette.warning
            : r.level == 'info'
            ? context.palette.info
            : context.palette.muted;
        return Material(
          color: _logId == r.id
              ? context.palette.accent.withValues(alpha: .07)
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _logId = r.id);
              if (!inspector) _detail(() => ConsoleInspector(record: r));
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.palette.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      clockTime(r.time),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.palette.muted,
                        height: 1.9,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 82,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(r.level.toUpperCase(), color: color),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.message,
                          style: mono.copyWith(
                            color: r.level == 'error'
                                ? context.palette.danger
                                : null,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          store.sessions[r.sessionId]?.name ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: context.palette.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _empty(bool noData) => EmptyState(
    icon: noData
        ? (_console ? Icons.terminal : Icons.sensors)
        : Icons.search_off,
    title: noData
        ? (_console
              ? context.l10n.consoleEmptyTitle
              : context.l10n.networkEmptyTitle)
        : context.l10n.noResults,
    action: noData
        ? OutlinedButton.icon(
            onPressed: _connectionGuide,
            icon: Icon(Icons.link, size: 16),
            label: Text(context.l10n.connectApp),
          )
        : TextButton(
            onPressed: () => setState(() {
              _search.clear();
              _query = '';
              _method = 'All methods';
              _status = 'All statuses';
              _level = 'All levels';
              _session = null;
            }),
            child: Text(context.l10n.resetFilters),
          ),
  );

  Widget _noSelection() =>
      EmptyState(icon: Icons.manage_search, title: context.l10n.selectionTitle);

  void _detail(Widget Function() buildInspector) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 700,
        height: 700,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: context.l10n.closeInspector,
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: store,
                builder: (context, child) => buildInspector(),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _banner(String message, Color color) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 10),
    color: color.withValues(alpha: .1),
    child: Text(message, style: TextStyle(color: color, fontSize: 12)),
  );

  Widget _footer() => Container(
    height: 31,
    padding: EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: Border(top: BorderSide(color: context.palette.line)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.circle,
          size: 6,
          color: server.running
              ? context.palette.accent
              : context.palette.muted,
        ),
        SizedBox(width: 7),
        Text(
          context.l10n.connectionCount(server.connections),
          style: TextStyle(fontSize: 10, color: context.palette.muted),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            context.l10n.captureStats(
              _console ? _logs.length : _requests.length,
              store.evicted,
              store.ignoredWhilePaused,
            ),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: context.palette.muted),
          ),
        ),
        if (server.invalidMessages + store.rejected > 0)
          Tooltip(
            message: server.lastProtocolError ?? context.l10n.unsupportedEvent,
            child: Text(
              context.l10n.invalidCount(
                server.invalidMessages + store.rejected,
              ),
              style: TextStyle(fontSize: 10, color: context.palette.danger),
            ),
          ),
      ],
    ),
  );
}
