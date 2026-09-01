// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'mt_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class MTLocalizationsEn extends MTLocalizations {
  MTLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get aboutApp => 'About App';

  @override
  String get activeDownloads => 'Active Downloads';

  @override
  String get activeDownloadsSheet => 'Active downloads';

  @override
  String get activeNow => 'Active now';

  @override
  String get addEndpoint => 'Add endpoint';

  @override
  String get addLinkFab => 'Add link';

  @override
  String addNToServer(int count) {
    return 'Add $count to server';
  }

  @override
  String get addToPlaylist => 'Add to Playlist';

  @override
  String get addUrl => 'Add URL';

  @override
  String addedNToServer(int count) {
    return 'Added $count to server';
  }

  @override
  String get addedToFavorites => 'Added to favorites';

  @override
  String get addedToQueue => 'Added to download queue';

  @override
  String get allDownloadsFinished => 'All downloads finished!';

  @override
  String get allPlatforms => 'All platforms';

  @override
  String get allRightsReserved => 'All rights reserved';

  @override
  String get allTagsFilter => 'All';

  @override
  String get appFeatures => 'App Features';

  @override
  String get appTitle => 'MeTube Super';

  @override
  String get appearance => 'Appearance';

  @override
  String get audioOnly => 'Audio Only';

  @override
  String get authHelper => 'Leave empty for open servers (no password)';

  @override
  String get authentication => 'Authentication (Optional)';

  @override
  String get autoBackgroundAudio => 'Auto Background Audio';

  @override
  String get autoPlayNext => 'Auto-play next: ON';

  @override
  String get autoPlayOff => 'Auto-play next: OFF';

  @override
  String get autoRestoreSuccess => 'Data restored from backup successfully!';

  @override
  String get autoUrlSwitching => 'Automatic URL switching';

  @override
  String get availability => 'Availability';

  @override
  String get availabilityOffline => 'Offline (local copy)';

  @override
  String get availabilityServer => 'Server (stream)';

  @override
  String get backgroundDownload => 'Downloading files in background...';

  @override
  String get backgroundPlay => 'Background play';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get backupNow => 'Back up now';

  @override
  String get backupNowSubtitle =>
      'Save an encrypted backup to the Downloads folder';

  @override
  String get backupOrphaned => 'Backup file unreadable';

  @override
  String get backupReset => 'Old backup deleted';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get backupSettings => 'Backup All Data';

  @override
  String backupSuccess(Object path) {
    return 'Backup saved to: $path';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get cardView => 'Card view';

  @override
  String get clear => 'Clear';

  @override
  String get clearAllSettings => 'Clear All Settings';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get clearLogsConfirm => 'Delete all diagnostic logs?';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get clipboardLinkReady => 'Paste link';

  @override
  String get closePlayer => 'Close player';

  @override
  String get compactView => 'Compact view';

  @override
  String get completed => 'Completed';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get contactDeveloper => 'Contact Developer';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get create => 'Create';

  @override
  String get createPlaylist => 'Create Playlist';

  @override
  String get creator => 'Creator';

  @override
  String get currentServerAddress => 'Current server address';

  @override
  String get date => 'Date';

  @override
  String get defaultQuality => 'Default Video Quality';

  @override
  String get delete => 'Delete';

  @override
  String get deleteFromServer => 'Delete From Server';

  @override
  String get deleteFromServerConfirm => 'Remove this item from the server?';

  @override
  String deleteMultipleConfirm(int count) {
    return 'Delete $count video(s)?\n\nThis will remove the files from your device.';
  }

  @override
  String deletePlaylistConfirm(Object name) {
    return 'Delete \\\"$name\\\"?';
  }

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String deleteTagConfirm(Object tag) {
    return 'Delete the tag \\\"$tag\\\" from all items? The videos themselves are not deleted.';
  }

  @override
  String get deleteVideo => 'Delete Video';

  @override
  String deleteVideoConfirm(Object title) {
    return 'Delete \\\"$title\\\"?\n\nThis will remove the file from your device.';
  }

  @override
  String deletedTitle(Object title) {
    return 'Deleted: $title';
  }

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get detailTitle => 'Title';

  @override
  String get details => 'Details';

  @override
  String get developer => 'Developer';

  @override
  String get developerName => 'Yasir Sagheer';

  @override
  String get diagnosticLogs => 'Diagnostic Logs';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get disclaimer => 'Disclaimer';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get done => 'Done';

  @override
  String get download => 'Download';

  @override
  String get downloadAndShare => 'Download & Share';

  @override
  String get downloadComplete => 'Download Complete';

  @override
  String get downloadCompleteTitle => 'Complete!';

  @override
  String get downloadDate => 'Download Date';

  @override
  String get downloadFailed => 'Download Failed';

  @override
  String get downloadFailedStatus => 'Download failed';

  @override
  String get downloadFailedTitle => 'Download Failed';

  @override
  String get downloadQuality => 'Download Quality';

  @override
  String get downloadStarted => 'Download started...';

  @override
  String downloadTracks(int count) {
    return 'Download $count Tracks';
  }

  @override
  String get downloadUrlUnavailable => 'Download URL not available';

  @override
  String get downloading => 'Downloading...';

  @override
  String downloadingSize(Object received, Object total) {
    return 'Downloading… $received / $total MB';
  }

  @override
  String get downloadingTitle => 'Downloading';

  @override
  String get downloadsTab => 'Downloads';

  @override
  String get email => 'Email';

  @override
  String get emptyLibraryMessage => 'Add a video link, or pull to refresh.';

  @override
  String get emptyPlaylist => 'Empty playlist';

  @override
  String get emptyPlaylistMessage => 'Add videos from the library';

  @override
  String get endpointReachable => 'Reachable';

  @override
  String get endpointUnreachable => 'Unreachable';

  @override
  String get endpointUrl => 'Endpoint URL';

  @override
  String get enterUrl => 'Enter URL';

  @override
  String get enterUrlHint => 'Paste video URL here...';

  @override
  String get enterUrlPrompt => 'Enter a video URL to download:';

  @override
  String errorGeneric(Object message) {
    return 'Error: $message';
  }

  @override
  String get errorLogs => 'Error Logs';

  @override
  String get errorLogsSubtitle => 'View app logs for diagnostics';

  @override
  String get exportBackupKey => 'Export Backup Key';

  @override
  String get exportKeyTitle => 'Export backup key';

  @override
  String get externalNetworkSection => 'External network';

  @override
  String get failed => 'Failed';

  @override
  String get failedToLoadPlaylist => 'Failed to load playlist';

  @override
  String get failedToLoadVideo => 'Failed to load video';

  @override
  String get failedToQueue => 'Failed to add to queue';

  @override
  String get favorites => 'Favorites';

  @override
  String get featureBackup => 'Automatic backup and restore';

  @override
  String get featureBilingual => 'Arabic and English language support';

  @override
  String get featureDownload =>
      'Download videos from YouTube and other platforms';

  @override
  String get featurePlayer => 'Direct download by sharing links from any app';

  @override
  String get featurePlaylists => 'Create and manage playlists';

  @override
  String get featureThemes => 'Dark and light themes';

  @override
  String get fieldHelp => 'Help';

  @override
  String get file => 'File';

  @override
  String get fileName => 'File Name';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get fileSize => 'File Size';

  @override
  String fileSizeBytes(Object value) {
    return '$value B';
  }

  @override
  String fileSizeGB(Object value) {
    return '$value GB';
  }

  @override
  String fileSizeKB(Object value) {
    return '$value KB';
  }

  @override
  String fileSizeMB(Object value) {
    return '$value MB';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterAudio => 'Audio';

  @override
  String get filterOffline => 'Offline';

  @override
  String get filterPlaylists => 'Playlists';

  @override
  String get filterServer => 'Server';

  @override
  String get filterVideo => 'Video';

  @override
  String get format => 'Format';

  @override
  String get helpAboutField => 'About this field';

  @override
  String get howItWorks => 'How it works';

  @override
  String get importBackupKey => 'Import Backup Key';

  @override
  String get importKeySubtitle =>
      'Load a previously exported key before restoring';

  @override
  String get importKeyTitle => 'Import backup key';

  @override
  String get keyExportFailed => 'Failed to export backup key';

  @override
  String keyExported(Object path) {
    return 'Key saved to:\n$path\n\nStore it somewhere safe (e.g. Google Drive).';
  }

  @override
  String keyExportedMessage(Object path) {
    return 'Saved to:\n$path\n\nUpload this file to Google Drive (or another safe place). You\'ll need it to restore your backup after Clear Data or on a new phone.';
  }

  @override
  String get keyExportedTitle => 'Backup key saved';

  @override
  String get keyImportConfirm => 'Replace key';

  @override
  String get keyImportConfirmTitle => 'Replace current key?';

  @override
  String get keyImportInvalid => 'Invalid key file';

  @override
  String get keyImported => 'Key imported. You can now use Restore.';

  @override
  String get keyImportedTitle => 'Key imported';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get latestAdditions => 'Latest additions';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get loadingVideo => 'Loading video...';

  @override
  String get localNetworkSection => 'Local network';

  @override
  String get localUrlLabel => 'Local server URL';

  @override
  String localVideos(int count) {
    return 'Library ($count)';
  }

  @override
  String get madeWithLove => 'Made with ❤️ By Yasir Sagheer';

  @override
  String get makeAvailableOffline => 'Make available offline';

  @override
  String get manageTags => 'Manage tags';

  @override
  String get modeAuto => 'Auto';

  @override
  String get modeAutoNext => 'Auto';

  @override
  String get modeOff => 'Off';

  @override
  String get modeRepeat => 'Repeat';

  @override
  String get modeRepeatAll => 'Repeat all';

  @override
  String get modeRepeatOne => 'Repeat one';

  @override
  String get navLibrary => 'Library';

  @override
  String get navMyDownloads => 'My downloads';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Settings';

  @override
  String get networkSettings => 'Networks';

  @override
  String get newTagHint => 'New tag';

  @override
  String get next => 'Next';

  @override
  String get noDownloads => 'No Downloads';

  @override
  String get noLogsFound => 'No logs found';

  @override
  String get noPlaylists => 'No playlists';

  @override
  String get noPlaylistsMessage => 'Create a playlist to organize your videos';

  @override
  String get noResults => 'No results';

  @override
  String get noResultsMessage => 'No items match your search.';

  @override
  String get noTagsYet => 'No tags yet. Create one below.';

  @override
  String get noValidUrl => 'No valid video URL found';

  @override
  String get noVideosFound => 'Your library is empty';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get offlineSmartList => 'Offline';

  @override
  String get ok => 'OK';

  @override
  String get openGithub => 'Open MeTube on GitHub';

  @override
  String get openOriginalLink => 'Open Original Link';

  @override
  String get originalUrl => 'Original URL';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get pasteFromClipboard => 'Paste';

  @override
  String get pause => 'Pause';

  @override
  String get pinPlaylist => 'Pin to top';

  @override
  String get platform => 'Platform';

  @override
  String platformCount(Object name, int count) {
    return '$name · $count';
  }

  @override
  String get platformFilter => 'Platform';

  @override
  String get play => 'Play';

  @override
  String get playAllFavorites => 'Play all favorites';

  @override
  String get playbackError => 'Playback Error';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get playerError => 'Couldn\'t play this file';

  @override
  String get playerLoading => 'Loading video...';

  @override
  String get playlist => 'Playlist';

  @override
  String get playlistDeleted => 'Playlist deleted';

  @override
  String get playlistDetails => 'Playlist Details';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get playlistNameHint => 'My Playlist';

  @override
  String playlistOf(int current, int total) {
    return '$current / $total';
  }

  @override
  String get playlists => 'Playlists';

  @override
  String playlistsCount(int count) {
    return '$count playlists';
  }

  @override
  String get pleaseEnterUrl => 'Please enter a URL';

  @override
  String get preparingDownload => 'Preparing download...';

  @override
  String get previous => 'Previous';

  @override
  String get quality => 'Quality';

  @override
  String get quality1080 => '1080p';

  @override
  String get quality480 => '480p';

  @override
  String get quality720 => '720p';

  @override
  String get qualityAudio => 'Audio only';

  @override
  String get qualityBest => 'Best available';

  @override
  String get qualityHelper => 'Sent to the server for new downloads';

  @override
  String queuePosition(int position) {
    return 'Queue position: $position';
  }

  @override
  String get queued => 'Queued';

  @override
  String get readyToShare => 'Ready to share!';

  @override
  String get reelsEndBack => 'Back to library';

  @override
  String get reelsEndReplay => 'Replay from the start';

  @override
  String get reelsEndTitle => 'End of the shorts lane';

  @override
  String get refresh => 'Refresh';

  @override
  String get remove => 'Remove';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get removeOfflineCopy => 'Remove offline copy';

  @override
  String get removeOfflineTitle => 'Remove Offline Copy';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get rename => 'Rename';

  @override
  String get renameTag => 'Rename tag';

  @override
  String get reorderHint => 'Drag to reorder';

  @override
  String get reportBug => 'Report a Bug';

  @override
  String get resetBackup => 'Reset backup';

  @override
  String get restoreCancelled => 'Backup file not found in Downloads folder';

  @override
  String get restoreData => 'Restore';

  @override
  String get restoreFailed => 'Restore failed — invalid backup file';

  @override
  String get restoreNotFound =>
      'No backup file found in Downloads/MeTube_Super';

  @override
  String get restoreSettings => 'Restore All Data';

  @override
  String get restoreSuccess => 'Data restored successfully';

  @override
  String get retry => 'Retry';

  @override
  String retryingAttempt(int attempt, int max) {
    return 'Retry $attempt/$max…';
  }

  @override
  String get saveQueueAsPlaylist => 'Save this queue as a playlist';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get savedPartial => 'Saved (Server delete failed)';

  @override
  String get savedSuccess => 'Settings saved';

  @override
  String get savedTo => 'Saved to Downloads/MeTube_Lite';

  @override
  String get savedToDownloads => 'Saved to Downloads/MeTube_Super';

  @override
  String get scanningVideos => 'Scanning videos...';

  @override
  String get searchHint => 'Search…';

  @override
  String get searchLogs => 'Search logs…';

  @override
  String searchResults(int found, int total) {
    return 'Results: $found of $total';
  }

  @override
  String get searchVideos => 'Search videos...';

  @override
  String get selectAll => 'Select All';

  @override
  String selected(int count) {
    return '$count selected';
  }

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get serverConfiguration => 'Server Configuration';

  @override
  String get serverDownload => 'Server Download';

  @override
  String get serverStatusChecking => 'Checking connection…';

  @override
  String get serverStatusConnected => 'Connected to server';

  @override
  String get serverStatusOffline => 'Server unreachable';

  @override
  String get serverStatusUnconfigured => 'No server configured';

  @override
  String get serverUrl => 'Server URL (MeTube)';

  @override
  String get serverUrlHelpTitle => 'About the Server URL';

  @override
  String get serverUrlHint => 'http://192.168.1.5:8086 or https://domain.com';

  @override
  String get serverUrlLabel => 'Server URL (MeTube Super)';

  @override
  String get serverUrlRequired => 'Server URL is required';

  @override
  String get settings => 'Settings';

  @override
  String get settingsCleared => 'Settings cleared';

  @override
  String get settingsSaved => 'Settings saved successfully';

  @override
  String get share => 'Share';

  @override
  String shareFailed(Object message) {
    return 'Failed to share: $message';
  }

  @override
  String get shareKeyFile => 'Share key file';

  @override
  String get shareLogs => 'Share Logs';

  @override
  String get shareRedacted => 'Share (redacted)';

  @override
  String get shareSelected => 'Share Selected';

  @override
  String get shareVia => 'Share';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get size => 'Size';

  @override
  String get smartPlaylists => 'Smart playlists';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortLargest => 'Largest';

  @override
  String get sortNameAZ => 'Name A–Z';

  @override
  String get sortNameZA => 'Name Z–A';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortOldest => 'Oldest';

  @override
  String get sortSmallest => 'Smallest';

  @override
  String get source => 'Source';

  @override
  String get sourceCode => 'Source code';

  @override
  String get speedNormal => 'Normal';

  @override
  String get startingDownload => 'Starting download via server...';

  @override
  String get status => 'Status';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusDownloading => 'Downloading...';

  @override
  String get statusError => 'Error';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusQueuing => 'Adding to queue...';

  @override
  String get statusServerDownloading => 'Server downloading...';

  @override
  String get statusStream => 'Stream';

  @override
  String get statusWaiting => 'Waiting...';

  @override
  String get streamUrlUnavailable => 'Stream URL not available';

  @override
  String get tagActionsHint => 'Long-press a tag to rename or delete it.';

  @override
  String get tagAudio => 'Audio';

  @override
  String get tagVideo => 'Video';

  @override
  String get tags => 'Tags';

  @override
  String get tapToCopy => 'Tap to copy';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeDarkMode => 'Dark theme';

  @override
  String get themeFollowSystem => 'Follow system settings';

  @override
  String get themeLight => 'Light';

  @override
  String get themeLightMode => 'Light theme';

  @override
  String get themeSystem => 'System';

  @override
  String totalDuration(Object duration) {
    return 'Total: $duration';
  }

  @override
  String tracksCount(int count) {
    return '$count tracks';
  }

  @override
  String get tryAgain => 'Try again';

  @override
  String get undo => 'Undo';

  @override
  String get unpinPlaylist => 'Unpin';

  @override
  String get upNext => 'Up next';

  @override
  String get urlMustStartWith => 'URL must start with http:// or https://';

  @override
  String get urlRequiredField => 'Enter a URL';

  @override
  String get useCurrentConnection => 'Use current connection';

  @override
  String get username => 'Username';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get version => 'Version';

  @override
  String get videoAdded => 'Added to playlist';

  @override
  String get videoDetails => 'Video details';

  @override
  String get videoLabel => 'Video';

  @override
  String get videoPlayer => 'Video Player';

  @override
  String get videoRemoved => 'Removed from playlist';

  @override
  String videosCount(int count) {
    return '$count videos';
  }

  @override
  String get viewAllInPlaylists => 'View all';

  @override
  String get waiting => 'Waiting for server...';

  @override
  String get yourPlaylists => 'Your playlists';

  @override
  String get yourTags => 'Your tags';

  @override
  String get youtubeDownloadStarting => 'Starting YouTube download...';
}
