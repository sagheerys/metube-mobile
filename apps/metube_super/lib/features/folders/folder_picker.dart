import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../settings/widgets/help_button.dart';
import 'folder_widgets.dart';
import 'folders_providers.dart';

/// A folder chosen in the picker. An empty [path] is the top of the
/// downloads, unless [channelName] says "named after the channel", which
/// only the server can resolve.
class FolderChoice {
  const FolderChoice(this.path, {this.channelName = false});

  static const top = FolderChoice('');
  static const channel = FolderChoice('', channelName: true);

  final String path;
  final bool channelName;

  bool get isTop => path.isEmpty && !channelName;
}

/// **The server folder row**, shared by the add sheet and the follow sheet:
/// what is chosen, and a tap to choose again.
class FolderRow extends StatelessWidget {
  const FolderRow({super.key, required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.folder_rounded, color: p.ink2),
      title: Text(context.mtl.folder),
      subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.unfold_more_rounded, color: p.ink3),
      onTap: onTap,
    );
  }
}

/// Picks a server folder: the top, the channel's own name when following,
/// any folder the server has (empty ones too), or a new one, nested if
/// typed so (`Ai/Lessons`). Null when dismissed.
Future<FolderChoice?> showFolderPicker(
  BuildContext context, {
  required bool audio,
  required FolderChoice current,
  bool offerTop = true,
  bool offerChannelName = false,
}) => showModalBottomSheet<FolderChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _FolderPicker(
    audio: audio,
    current: current,
    offerTop: offerTop,
    offerChannelName: offerChannelName,
  ),
);

class _FolderPicker extends ConsumerWidget {
  const _FolderPicker({
    required this.audio,
    required this.current,
    required this.offerTop,
    required this.offerChannelName,
  });

  final bool audio;
  final FolderChoice current;
  final bool offerTop;
  final bool offerChannelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final server = ref.watch(serverFoldersProvider);
    final disabled = server.valueOrNull?.enabled == false;
    final folders = disabled
        ? const <String>[]
        : pickableFolders(
            server.valueOrNull,
            ref.watch(libraryFolderPathsProvider),
            audio: audio,
          );

    Widget option({
      required IconData icon,
      required String title,
      String? subtitle,
      required bool selected,
      required FolderChoice choice,
      double indent = 0,
    }) => ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: MTSpace.pagePad + indent,
        end: MTSpace.pagePad,
      ),
      leading: Icon(icon, color: selected ? p.accent : p.ink2),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: selected ? Icon(Icons.check_rounded, color: p.accent) : null,
      onTap: () => Navigator.of(context).pop(choice),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: mtSheetBottomPad(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MTSpace.pagePad,
              MTSpace.md,
              MTSpace.pagePad,
              MTSpace.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chooseFolder,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // The explanation of folders and of what the server needs
                // sits behind a help button rather than always showing; the
                // button pulses as the picker opens so it gets noticed.
                PulsingHelp(
                  child: HelpButton(
                    title: l10n.chooseFolder,
                    body: l10n.foldersHelp,
                  ),
                ),
              ],
            ),
          ),
          if (server.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (disabled)
            FolderNotice(text: l10n.foldersDisabled)
          else if (ref.watch(foldersIgnoredProvider))
            FolderNotice(text: l10n.foldersIgnored),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (offerTop)
                  option(
                    icon: Icons.home_rounded,
                    title: l10n.noFolder,
                    subtitle: l10n.noFolderHint,
                    selected: current.isTop,
                    choice: FolderChoice.top,
                  ),
                if (offerChannelName)
                  option(
                    icon: Icons.subscriptions_rounded,
                    title: l10n.channelNameFolder,
                    selected: current.channelName,
                    choice: FolderChoice.channel,
                  ),
                for (final path in folders)
                  option(
                    icon: Icons.folder_rounded,
                    title: mtName(path.split('/').last),
                    selected: !current.channelName && current.path == path,
                    choice: FolderChoice(path),
                    indent: MTSpace.lg * (path.split('/').length - 1),
                  ),
                if (!disabled)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MTSpace.pagePad,
                    ),
                    leading: Icon(
                      Icons.create_new_folder_rounded,
                      color: p.ink2,
                    ),
                    title: Text(l10n.newFolder),
                    onTap: () async {
                      final made = await askNewFolder(context, current.path);
                      if (made != null && context.mounted) {
                        Navigator.of(context).pop(FolderChoice(made));
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
