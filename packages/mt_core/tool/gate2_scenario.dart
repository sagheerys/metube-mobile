// Gate 2 script: a complete download scenario with no UI against a real
// server.
// Usage, with both policies:
// dart tool/gate2_scenario.dart <baseUrl> <user> <pass> <videoUrl>
// autoDelete
// dart tool/gate2_scenario.dart <baseUrl> <user> <pass> <videoUrl>
// keepOnServer
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:mt_core/mt_core.dart';

Future<void> main(List<String> args) async {
  if (args.length < 5) {
    print(
      'Usage: dart tool/gate2_scenario.dart '
      '<baseUrl> <user> <pass> <videoUrl> <autoDelete|keepOnServer>',
    );
    exit(64);
  }
  final [baseUrl, user, pass, videoUrl, policyName, ...] = args;
  final policy = policyName == 'autoDelete'
      ? DeletePolicy.autoDelete
      : DeletePolicy.keepOnServer;

  // '-' means no credentials (Windows shells drop an empty "").
  final client = MeTubeApiClient(
    config: ServerConfig(
      baseUrl: baseUrl,
      username: user == '-' ? null : user,
      password: pass == '-' ? null : pass,
    ),
  );

  print('▸ testConnection...');
  await client.testConnection();
  print('✓ سيرفر MeTube صالح');

  final outDir = Directory('build/gate2')..createSync(recursive: true);
  final engine = DownloadEngine(
    api: client,
    policy: policy,
    savePathBuilder: (task, serverFilename) =>
        '${outDir.path}/${buildLocalFilename(serverFilename, serverFilename: serverFilename)}',
  );

  engine.updates.listen(
    (t) => print(
      '  [${t.phase.name}] ${(t.progress * 100).toStringAsFixed(0)}%'
      '${t.error == null ? '' : ' — ${t.error}'}',
    ),
  );

  print('▸ submit ($policyName)...');
  final task = engine.submit(videoUrl, Quality.best);
  final result = await engine.updates
      .firstWhere((t) => t.id == task.id && t.isFinished)
      .timeout(const Duration(minutes: 12));

  if (result.phase != TaskPhase.completed) {
    print('✗ فشل: ${result.phase.name} — ${result.error}');
    exit(1);
  }
  final file = File(result.localPath!);
  print('✓ اكتمل: ${file.path} (${file.lengthSync()} بايت)');
  print('✓ canonicalUrl: ${result.canonicalUrl}');
  await engine.dispose();
  client.close();
  exit(0);
}
