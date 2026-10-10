import 'dart:async';

import 'package:mt_media/src/video/mt_video_codec.dart';

/// No test reaches a real file or server to learn a clip's codec: the read
/// would finish outside the test's fake clock and leave its timers behind.
/// Every clip reads as "not AV1", the path all clips took before; the
/// codec's own tests replace this.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MTVideoCodec.readHead = (_) async => null;
  await testMain();
}
