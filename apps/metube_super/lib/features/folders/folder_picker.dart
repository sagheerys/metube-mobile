import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../settings/widgets/help_button.dart';
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
                // What a folder is, and what the server needs for it, is
                // asked for rather than imposed on everyone who opens this.
                HelpButton(title: l10n.chooseFolder, body: l10n.foldersHelp),
              ],
            ),
          ),
          if (server.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (disabled)
            _Notice(text: l10n.foldersDisabled)
          else if (ref.watch(foldersIgnoredProvider))
            _Notice(text: l10n.foldersIgnored),
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
                      final made = await _askNewFolder(context, current.path);
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

/// The name of a new folder, nested when typed with a slash. It is made on
/// the server by the first download saved into it.
Future<String?> _askNewFolder(BuildContext context, String parent) async {
  final typed = await showDialog<String>(
    context: context,
    builder: (_) => _NewFolderDialog(parent: parent),
  );
  final clean = ServerPath.cleanFolder(typed ?? '');
  return clean.isEmpty ? null : clean;
}

/// **The dialog owns its controller**, so it is disposed only once the
/// route is gone: disposing it when `showDialog` returns runs during the
/// closing animation, while the field is still being built.
class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog({required this.parent});

  final String parent;

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  late final _controller = TextEditingController(
    text: widget.parent.isEmpty ? '' : '${widget.parent}/',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return AlertDialog(
      title: Text(l10n.newFolder),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.newFolderHint),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}

/// A line the picker must say before the list: the server refuses folders,
/// or ignores them.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: MTSpace.pagePad,
        vertical: MTSpace.xs,
      ),
      padding: const EdgeInsets.all(MTSpace.sm),
      decoration: BoxDecoration(
        color: p.cardAlt,
        border: BorderDirectional(start: BorderSide(color: p.err, width: 3)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
