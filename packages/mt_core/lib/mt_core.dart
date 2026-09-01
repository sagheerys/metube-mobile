/// نواة MTF — Dart خالص: عميل MeTube API، النماذج المتسامحة، أدوات
/// الروابط، محرك التحميل، التخزين، النسخ الاحتياطي، السجلات.
/// كل السلوك من `docs/plan/05-DATA-SCHEMA.md` حرفياً.
library;

export 'src/api/api_exceptions.dart';
export 'src/api/endpoint_resolver.dart';
export 'src/api/metube_api.dart';
export 'src/api/metube_api_client.dart' show MeTubeApiClient, ServerConfig;
export 'src/backup/backup_crypto.dart';
export 'src/backup/backup_service.dart';
export 'src/constants/mt_constants.dart';
export 'src/download/delete_policy.dart';
export 'src/download/download_engine.dart';
export 'src/download/download_queue.dart';
export 'src/download/local_filename.dart';
export 'src/download/transfer.dart';
export 'src/logging/mt_logger.dart';
export 'src/models/download_task.dart';
export 'src/models/history_item.dart';
export 'src/models/history_response.dart';
export 'src/models/playlist_preview.dart';
export 'src/models/quality.dart';
export 'src/models/saved_playlist.dart';
export 'src/resolvers/http_fetch.dart';
export 'src/resolvers/soundcloud_resolver.dart';
export 'src/resolvers/youtube_playlist_resolver.dart';
export 'src/storage/artwork_index.dart';
export 'src/storage/key_value_store.dart';
export 'src/storage/memory_key_value_store.dart';
export 'src/storage/offline_index.dart';
export 'src/storage/playlists_store.dart';
export 'src/storage/secret_store.dart';
export 'src/storage/tags_index.dart';
export 'src/storage/url_keyed_index.dart';
export 'src/urls/platform_detector.dart';
export 'src/urls/playlist_detector.dart';
export 'src/urls/short_link_resolver.dart';
export 'src/urls/url_kit.dart';
