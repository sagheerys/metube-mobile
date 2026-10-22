import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The name of a new folder, nested when typed with a slash. It is made on
/// the server by the first download saved into it.
Future<String?> askNewFolder(BuildContext context, String parent) async {
  final typed = await showDialog<String>(
    context: context,
    builder: (_) => NewFolderDialog(parent: parent),
  );
  final clean = ServerPath.cleanFolder(typed ?? '');
  return clean.isEmpty ? null : clean;
}

/// **The dialog owns its controller**, so it is disposed only once the
/// route is gone: disposing it when `showDialog` returns runs during the
/// closing animation, while the field is still being built.
class NewFolderDialog extends StatefulWidget {
  const NewFolderDialog({super.key, required this.parent});

  final String parent;

  @override
  State<NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<NewFolderDialog> {
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
class FolderNotice extends StatelessWidget {
  const FolderNotice({super.key, required this.text});

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

/// **Three pulses as the picker opens, then still**: enough to draw the eye
/// to the help, not a light that keeps blinking at someone who has read it.
/// Nothing moves when the system asks for less motion.
class PulsingHelp extends StatefulWidget {
  const PulsingHelp({super.key, required this.child});

  static const pulses = 3;

  final Widget child;

  @override
  State<PulsingHelp> createState() => _PulsingHelpState();
}

class _PulsingHelpState extends State<PulsingHelp>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: MTMotion.slow,
  );
  var _left = PulsingHelp.pulses;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      _left--;
      if (_left > 0) _controller.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_left == PulsingHelp.pulses &&
        !_controller.isAnimating &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = MTThemeX.of(context).palette.accent;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Up and back within each pulse, as a breath rather than a flash.
        final t = Curves.easeInOut.transform(
          1 - (2 * _controller.value - 1).abs(),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.18 * t),
          ),
          child: Transform.scale(scale: 1 + 0.18 * t, child: child),
        );
      },
    );
  }
}
