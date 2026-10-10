import 'dart:io';
import 'dart:math' show max;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart' show UrlKit;

/// An artwork value may be a **generated local file path**, a frame
/// capture or an embedded audio cover (see `MediaProbe.kt`), or a network
/// URL that needs authentication headers. Which one it is can be read from
/// the value itself.
///
/// It returns **null** rather than a `SizedBox` when there is no cover: the
/// card then draws its own fallback icon, and returning an empty widget
/// left a blank square with nothing in it.
///
/// [decodeWidth] is **in physical pixels**: a 1280x720 YouTube thumbnail
/// occupies about 3.5MB in the image cache however small the box it is
/// drawn in, and forty visible cards mean tens of megabytes for nothing.
/// Decoding at display size cuts that to a fraction. Compute it with
/// [mtDecodeWidth] rather than by hand.
Widget? artworkFor(
  String? value, {
  Map<String, String>? headers,
  BoxFit fit = BoxFit.cover,
  int? decodeWidth,
}) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: value,
      httpHeaders: headers,
      fit: fit,
      memCacheWidth: decodeWidth,
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return Image.file(
    File(value),
    fit: fit,
    cacheWidth: decodeWidth,
    // The cache was cleared or the file deleted, so the card shows no cover
    // rather than an error box.
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

/// The audio player's square cover, wanting a wider picture than a card.
///
/// YouTube's `hqdefault` is 4:3 with the 16:9 picture between black bands.
/// A card's 16:9 box crops them away, but a square one shows them, so the
/// player asks for the wide thumbnail, which has none. Where an upload has
/// no wide one, the 4:3 picture is enlarged by 4/3 so the bands fall
/// outside the square. Anything that is not a YouTube thumbnail is drawn
/// as [artworkFor] draws it.
Widget? coverArtworkFor(String? value, {Map<String, String>? headers}) {
  final wide = UrlKit.youtubeWideThumbnail(value);
  if (wide == null) return artworkFor(value, headers: headers);
  return CachedNetworkImage(
    imageUrl: wide,
    fit: BoxFit.cover,
    errorWidget: (_, _, _) => Transform.scale(
      scale: 4 / 3,
      child: artworkFor(value) ?? const SizedBox.shrink(),
    ),
  );
}

/// The decode width in physical pixels for a [width] by [height] box under
/// `cover`.
///
/// **The box width alone is not enough**: `BoxFit.cover` enlarges the
/// image until both dimensions are filled, so a 16:9 thumbnail in a
/// proportionally wider box (98x62) takes its scale from the height, not
/// the width. Decoding at 98 gave an image 55 tall which was then
/// stretched to 62: blur we added ourselves. The safe bound is the larger
/// of the width and `height x 16/9`.
int mtDecodeWidth(BuildContext context, double width, [double? height]) {
  final needed = height == null ? width : max(width, height * 16 / 9);
  return (needed * MediaQuery.devicePixelRatioOf(context)).ceil();
}
