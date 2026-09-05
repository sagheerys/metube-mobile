import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../shared/error_report.dart';

/// حالة السيرفر النشط. null ⇔ غير مهيأ. وإلا حالة مصنفة: **«يرفض
/// اعتمادك» ليس «تعذّر الوصول»** — الأول يُصلَح بالحقلين أسفل هذه
/// البطاقة، والثاني لا.
final serverStatusProvider = FutureProvider<MTEndpointStatus?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  try {
    await api.testConnection();
    clearErrorSignature('server-status');
    return MTEndpointStatus.ok;
  } on MTApiException catch (e) {
    unawaited(logErrorOnce(ref.read(loggerProvider), 'server-status', e));
    return switch (e) {
      AuthFailureException() => MTEndpointStatus.unauthorized,
      // العنوان حيّ لكنه ليس MeTube — خطأ عنوان لا خطأ شبكة.
      NotMeTubeServerException() ||
      NoApiException() =>
        MTEndpointStatus.notMeTube,
      _ => MTEndpointStatus.unreachable,
    };
  }
});

/// بطاقة حالة السيرفر (م-29) — إسبريسو داكنة دائماً (سجل §4).
class ServerStatusCard extends ConsumerWidget {
  const ServerStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final status = ref.watch(serverStatusProvider);
    final settings = ref.watch(settingsProvider);
    final p = MTThemeX.of(context).palette;

    final (icon, tint, label) = switch (status) {
      AsyncData(value: MTEndpointStatus.ok) => (
          Icons.cloud_done_rounded,
          p.ok,
          l10n.serverStatusConnected
        ),
      // البطاقة **داكنة دائماً** (سجل §4)، ولون الفعل البترولي في Lite
      // لا يُقرأ عليها — فالتمييز بالأيقونة والنص لا باللون.
      AsyncData(value: MTEndpointStatus.unauthorized) => (
          Icons.lock_outline_rounded,
          MTPalette.serverCardInk,
          l10n.signInRequired
        ),
      // «ليس MeTube» ليس انقطاعاً: العنوان حيّ ويردّ — والعلاج تصحيح
      // العنوان لا انتظار الشبكة.
      AsyncData(value: MTEndpointStatus.notMeTube) => (
          Icons.link_off_rounded,
          MTPalette.serverCardInk,
          l10n.errNotMeTube
        ),
      AsyncData(value: MTEndpointStatus.unreachable) => (
          Icons.cloud_off_rounded,
          p.err,
          l10n.serverStatusOffline
        ),
      AsyncData(value: null) => (
          Icons.cloud_outlined,
          MTPalette.serverCardInk,
          l10n.serverStatusUnconfigured
        ),
      _ => (
          Icons.cloud_sync_rounded,
          MTPalette.serverCardInk,
          l10n.serverStatusChecking
        ),
    };

    return Container(
      padding: const EdgeInsets.all(MTSpace.lg),
      decoration: BoxDecoration(
        color: MTPalette.serverCardBg,
        borderRadius: BorderRadius.circular(MTRadius.cardLg),
      ),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 26),
          const SizedBox(width: MTSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: MTPalette.serverCardInk,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (settings.isConfigured)
                  Text(
                    settings.serverUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color:
                            MTPalette.serverCardInk.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(serverStatusProvider),
            icon: Icon(Icons.refresh_rounded,
                color: MTPalette.serverCardInk.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
