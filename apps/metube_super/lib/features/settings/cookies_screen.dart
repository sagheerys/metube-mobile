import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../shared/error_report.dart';
import 'widgets/help_button.dart';

/// Whether the server holds cookies — null while unknown, and null again
/// for a MeTube too old to answer (§2.8).
final cookieStatusProvider = FutureProvider<bool?>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api?.hasCookies();
});

/// **Cookies from the phone** (Super only).
///
/// A platform asking for a login used to end the conversation: the app
/// said "the server admin should refresh the cookies" and stopped —
/// including when the person reading it *was* the admin, holding the
/// phone, hours from the machine. This turns that message into an action.
///
/// **Nothing is kept here.** The file is read from the system picker into
/// memory, sent, and dropped. Cookies are live credentials for someone's
/// accounts; an app that keeps a copy is an app that leaks one.
class CookiesScreen extends ConsumerStatefulWidget {
  const CookiesScreen({super.key});

  @override
  ConsumerState<CookiesScreen> createState() => _CookiesScreenState();
}

class _CookiesScreenState extends ConsumerState<CookiesScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(cookieStatusProvider);
      if (mounted) showMTSnack(context, success, type: MTSnackType.success);
    } on Object catch (e) {
      // **The server's own words**, which for cookies are the useful ones:
      // "configured manually via YTDL_OPTIONS" tells the server's
      // operator to go and edit the container, and nothing this app could invent says that.
      if (mounted) showErrorSnack(context, ref, e, tag: 'cookies');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final api = ref.read(apiClientProvider);
    if (api == null) return;
    // **`withData: true`**: on Android 11+ the app cannot open a path it
    // did not create, so the bytes have to come back from the picker
    // itself rather than from a file we then try to read.
    //
    // **Several at once** (2026-09-24): the server keeps one file and each
    // upload replaces it whole, so a platform per upload signs the last
    // one out. Picked together, they are merged here into the one file.
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    final files = [
      for (final file in picked?.files ?? const <PlatformFile>[])
        if (file.bytes case final bytes?) (file.name, bytes),
    ];
    if (files.isEmpty || !mounted) return;
    final l10n = context.mtl;
    // One file is sent exactly as picked, as it always was.
    final (name, bytes) = files.length == 1
        ? files.single
        : ('cookies.txt', CookieFiles.merge([for (final f in files) f.$2]));
    if (bytes == null) {
      showMTSnack(context, l10n.cookiesNotNetscape, type: MTSnackType.error);
      return;
    }
    // **What went in, by name** (2026-09-24): after picking two files,
    // naming both sites is the only proof that both were sent. A file the
    // app cannot read a site from is still sent, and says so generically.
    final sites = CookieFiles.sites(bytes);
    await _run(
      () => api.uploadCookies(bytes, filename: name),
      sites.isEmpty
          ? l10n.cookiesUploaded
          : l10n.cookiesSentFor(mtLtrRun(sites.join(' · '))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final status = ref.watch(cookieStatusProvider);
    final has = status.valueOrNull;
    final api = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cookies)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad,
          MTSpace.md,
          MTSpace.pagePad,
          MTSpace.xxl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cookiesWhat,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              HelpButton(title: l10n.cookies, body: l10n.cookiesHelp),
            ],
          ),
          const SizedBox(height: MTSpace.lg),
          Container(
            padding: const EdgeInsets.all(MTSpace.md),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(MTRadius.card),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Icon(
                  has == true
                      ? Icons.verified_user_rounded
                      : Icons.cookie_outlined,
                  color: has == true ? p.ok : p.ink3,
                ),
                const SizedBox(width: MTSpace.md),
                Expanded(
                  child: Text(switch (has) {
                    true => l10n.cookiesPresent,
                    false => l10n.cookiesAbsent,
                    // A MeTube too old to answer, or one that has not
                    // answered yet. "Unknown" is shown rather than
                    // guessed at, exactly as with the version (§2.6).
                    null => l10n.cookiesUnknown,
                  }, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: MTSpace.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy || api == null ? null : _pickAndUpload,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                has == true ? l10n.cookiesReplace : l10n.cookiesUpload,
              ),
            ),
          ),
          const SizedBox(height: MTSpace.sm),
          Text(
            l10n.cookiesReplaceNote,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: p.ink2),
          ),
          // **Offered only when there is something to remove.** A delete
          // button on a server with no cookies answers 400 and teaches the
          // user that the app guesses.
          if (has == true) ...[
            const SizedBox(height: MTSpace.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy || api == null ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l10n.cookiesDelete),
                style: OutlinedButton.styleFrom(foregroundColor: p.err),
              ),
            ),
          ],
          const SizedBox(height: MTSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.privacy_tip_outlined, size: 16, color: p.ink3),
              const SizedBox(width: MTSpace.xs),
              Expanded(
                child: Text(
                  l10n.cookiesPrivacy,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: p.ink3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l10n = context.mtl;
    final api = ref.read(apiClientProvider);
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cookiesDelete),
        content: Text(l10n.cookiesDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(api.deleteCookies, l10n.cookiesDeleted);
  }
}
