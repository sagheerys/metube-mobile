/// نواة MTF — Dart خالص: عميل MeTube API، النماذج المتسامحة، أدوات الروابط.
/// كل السلوك من `docs/plan/05-DATA-SCHEMA.md` حرفياً.
library;

export 'src/api/api_exceptions.dart';
export 'src/api/endpoint_resolver.dart';
export 'src/api/metube_api_client.dart' show MeTubeApiClient, ServerConfig;
export 'src/constants/mt_constants.dart';
export 'src/models/download_task.dart';
export 'src/models/history_item.dart';
export 'src/models/history_response.dart';
export 'src/models/quality.dart';
export 'src/urls/platform_detector.dart';
export 'src/urls/playlist_detector.dart';
export 'src/urls/short_link_resolver.dart';
export 'src/urls/url_kit.dart';
