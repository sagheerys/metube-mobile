import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'error_text.dart';

/// **Every error shown is also written down** (requested 2026-09-06).
///
/// The diagnostic log was a download log rather than an error log: forty
/// places in this app show an error message and not one of them reached
/// the log, not even the credential rejection that took down the entire
/// library (2026-09-05).
///
/// **The user's text is translated and the log's is technical**: a log is
/// read a week later and from another device, so translating it costs its
/// meaning (`AuthFailureException: HTTP 401` is more use than "the
/// username or password is wrong").
void showErrorSnack(
  BuildContext context,
  WidgetRef ref,
  Object error, {
  String tag = 'ui',
}) {
  unawaited(logError(ref.read(loggerProvider), error, tag: tag));
  showMTSnack(context, errorText(context.mtl, error), type: MTSnackType.error);
}

/// **It returns the future rather than swallowing it**: the call from the
/// interface is `unawaited` so the screen never waits on the disk, but a
/// test needs a decisive await rather than polling that varies with disk
/// speed.
Future<void> logError(MTLogger logger, Object error, {String tag = 'ui'}) =>
    logger.error(error.toString(), tag: tag);

/// **The last error's signature per repeating source.** Live polling every
/// two seconds repeats the same fault thirty times a minute, and the log is
/// a ring of a thousand lines: without this filter one fault erases the
/// app's entire history in half an hour.
final _lastSignature = <String, String>{};

/// Logs the error **if it changed** from what was last logged for this
/// source.
Future<void> logErrorOnce(
  MTLogger logger,
  String source,
  Object error, {
  String tag = 'network',
}) {
  final signature = error.toString();
  if (_lastSignature[source] == signature) return Future<void>.value();
  _lastSignature[source] = signature;
  return logger.error('$source: $signature', tag: tag);
}

/// Called when the source succeeds, so the fault repeating after a recovery
/// is a new event worth a line.
void clearErrorSignature(String source) => _lastSignature.remove(source);
