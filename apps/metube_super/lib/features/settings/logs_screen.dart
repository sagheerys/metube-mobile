import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../di.dart';

/// عارض السجلات التشخيصي (م-32): بحث/مسح/مشاركة — **المشاركة تمر
/// بالتعقيم الإلزامي** (حذف الروابط وIP والاعتمادات والمسارات).
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final TextEditingController _search = TextEditingController();
  List<String> _lines = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  MTLogger get _logger => ref.read(loggerProvider);

  Future<void> _load() async {
    final text = await _logger.readAll();
    if (!mounted) return;
    setState(() {
      _lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await _logger.clear();
    await _load();
  }

  /// المشاركة **معقّمة دائماً** — لا رابط ولا IP ولا ترويسة مصادقة.
  Future<void> _share() async {
    final sanitized = await _logger.readForShare();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/metube_super_logs.txt');
    await file.writeAsString(sanitized, flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? _lines
        : [
            for (final line in _lines)
              if (line.toLowerCase().contains(query)) line,
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diagnosticLogs),
        actions: [
          IconButton(
            tooltip: l10n.shareLogs,
            onPressed: _lines.isEmpty ? null : _share,
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: l10n.clearLogs,
            onPressed: _lines.isEmpty ? null : _confirmClear,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                MTSpace.pagePad, MTSpace.sm, MTSpace.pagePad, MTSpace.xs),
            child: MTSearchField(
              hint: l10n.searchLogs,
              onChanged: (value) => setState(() => _search.text = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
            child: Row(
              children: [
                Icon(Icons.privacy_tip_outlined, size: 14, color: p.ink3),
                const SizedBox(width: MTSpace.xs),
                Expanded(
                  child: Text(l10n.logsSanitizedNote,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall!
                          .copyWith(color: p.ink3)),
                ),
              ],
            ),
          ),
          const SizedBox(height: MTSpace.sm),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? MTEmptyState(
                        icon: Icons.article_outlined,
                        title: query.isEmpty ? l10n.logsEmpty : l10n.noResults,
                        message: query.isEmpty
                            ? l10n.noLogsFound
                            : l10n.noResultsMessage,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(MTSpace.pagePad, 0,
                            MTSpace.pagePad, MTSpace.xxl),
                        itemCount: visible.length,
                        itemBuilder: (context, index) => Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            visible[index],
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall!
                                .copyWith(
                                  color: visible[index].contains('ERROR')
                                      ? p.err
                                      : p.ink2,
                                  fontFamily: 'monospace',
                                ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmClear() {
    final l10n = context.mtl;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.clearLogsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _clear();
            },
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }
}
