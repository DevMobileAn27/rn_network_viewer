import 'package:flutter/material.dart';

import '../models/capture.dart';
import '../l10n/strings.dart';
import 'components.dart';

class NetworkInspector extends StatelessWidget {
  const NetworkInspector({super.key, required this.record});
  final NetworkRecord record;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 10, 6),
          child: Row(
            children: [
              Icon(Icons.data_object, size: 17, color: context.palette.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.requestInspector,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: context.l10n.copyCurl,
                onPressed: record.request.isEmpty
                    ? null
                    : () => copyText(
                        context,
                        record.curl,
                        context.l10n.curlCopied,
                      ),
                icon: Icon(Icons.terminal, size: 18),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              StatusChip(
                record.method,
                color: context.palette.methodColor(record.method),
              ),
              SizedBox(width: 8),
              StatusChip(
                filterLabel(context, record.state),
                color: context.palette.statusColor(
                  record.status,
                  transportError: record.error.isNotEmpty,
                ),
              ),
              Spacer(),
              Text(
                record.duration == null ? '—' : '${record.duration} ms',
                style: TextStyle(color: context.palette.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              record.request.isEmpty ? context.l10n.missingRequest : record.url,
              style: mono,
            ),
          ),
        ),
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: TextStyle(fontSize: 12),
          tabs: [
            Tab(text: context.l10n.overview),
            Tab(text: context.l10n.request),
            Tab(text: context.l10n.response),
            Tab(text: context.l10n.raw),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              ListView(
                children: [
                  DataSection(context.l10n.requestId, record.requestId),
                  DataSection(context.l10n.source, record.source),
                  DataSection(
                    context.l10n.started,
                    record.time?.toLocal().toIso8601String(),
                  ),
                  DataSection(
                    context.l10n.status,
                    record.pending
                        ? context.l10n.waitingResponse
                        : '${filterLabel(context, record.state)} ${record.response['statusText'] ?? ''}',
                  ),
                  DataSection(
                    context.l10n.responseSize,
                    context.l10n.capturedBytes(record.responseBytes),
                  ),
                  if (record.error.isNotEmpty)
                    DataSection(context.l10n.error, record.error),
                  DataSection(
                    context.l10n.queryParameters,
                    Uri.tryParse(record.url)?.queryParametersAll,
                  ),
                ],
              ),
              ListView(
                children: [
                  DataSection(
                    context.l10n.headers,
                    record.request['headers'],
                    initiallyExpanded: false,
                  ),
                  DataSection(
                    context.l10n.body,
                    record.request['body'] ?? record.request['bodyPreview'],
                    body: true,
                  ),
                ],
              ),
              ListView(
                children: [
                  if (record.pending)
                    Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        context.l10n.waitingResponse,
                        style: TextStyle(color: context.palette.muted),
                      ),
                    ),
                  if (record.error.isNotEmpty)
                    DataSection(context.l10n.error, record.error),
                  DataSection(
                    context.l10n.headers,
                    record.response['headers'],
                    initiallyExpanded: false,
                  ),
                  DataSection(
                    context.l10n.body,
                    record.response['body'] ?? record.response['bodyPreview'],
                    body: true,
                  ),
                ],
              ),
              SingleChildScrollView(
                padding: EdgeInsets.all(18),
                child: SelectableText(pretty(record.toJson()), style: mono),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ConsoleInspector extends StatelessWidget {
  const ConsoleInspector({super.key, required this.record});
  final ConsoleRecord record;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          context.l10n.consoleInspector,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      DataSection(context.l10n.level, record.level),
      DataSection(
        context.l10n.timestamp,
        record.time?.toLocal().toIso8601String(),
      ),
      DataSection(context.l10n.message, record.message),
      DataSection(context.l10n.arguments, record.event['args']),
      ExpansionTile(
        title: Text(context.l10n.rawEvent, style: TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: EdgeInsets.all(18),
            child: SelectableText(pretty(record.event), style: mono),
          ),
        ],
      ),
    ],
  );
}
