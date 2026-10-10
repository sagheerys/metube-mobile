import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:mt_core/mt_core.dart' show UrlKit;
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:path_provider/path_provider.dart';

/// The square cover for the media notification and the lock screen, made
/// once a clip and kept in the app's cache folder; see
/// `MTAudioHandler.squareArt`.
///
/// A YouTube song's wide thumbnail comes from the same image cache as the
/// player's cover, so it is not downloaded twice. Where an upload has no
/// wide one, the square is cut inside the 4:3 thumbnail's black bands.
/// Images on the server itself get no password: covers come from the
/// platforms, never from the server.
Future<Uri?> squareArtFor(PlaylistItem item) async {
  final art = item.artworkUrl;
  if (art == null || art.isEmpty) return null;
  final folder = Directory('${(await getTemporaryDirectory()).path}/covers');
  final file = File('${folder.path}/${_name(art)}.png');
  if (await file.exists()) return Uri.file(file.path);

  final wide = UrlKit.youtubeWideThumbnail(art);
  Uint8List? png;
  if (wide != null) png = await mtSquarePng(CachedNetworkImageProvider(wide));
  png ??= await mtSquarePng(
    art.startsWith('/')
        ? FileImage(File(art))
        : CachedNetworkImageProvider(art),
    letterboxed: wide != null,
  );
  if (png == null) return null;
  await folder.create(recursive: true);
  await file.writeAsBytes(png, flush: true);
  return Uri.file(file.path);
}

/// A file name from the cover's address: FNV-1a, stable across runs, which
/// `String.hashCode` is not promised to be.
String _name(String value) {
  var hash = 0xcbf29ce484222325;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  return hash.toUnsigned(64).toRadixString(16);
}
