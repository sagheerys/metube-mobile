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
  String get aboutDescriptionLite =>
      'A light, fast app that downloads videos from many platforms through your MeTube server, pulls them to your device and cleans the server afterwards — with a built-in player and playlists.';

  @override
  String get aboutDescriptionSuper =>
      'The server owner\'s edition: one library across server and device, streaming, tags, offline availability, batch downloads and server address switching.';

  @override
  String get activeDownloads => 'Active Downloads';

  @override
  String activeDownloadsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads in progress',
      one: '1 download in progress',
    );
    return '$_temp0';
  }

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
  String get addTo => 'Add to…';

  @override
  String get addToFavorites => 'Add to favorites';

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
  String addedToPlaylistCount(int count) {
    return '$count added to the playlist';
  }

  @override
  String get addedToQueue => 'Added to download queue';

  @override
  String get addingToServer => 'Sending to the server…';

  @override
  String get allDownloadsFinished => 'All downloads finished!';

  @override
  String get allPlatforms => 'All platforms';

  @override
  String get allTagsFilter => 'All';

  @override
  String get alreadyInPlaylist => 'Already added';

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
  String get autoBackgroundAudioSubtitle =>
      'Play audio in background when pressing back button';

  @override
  String get autoBuilt => 'Automatic';

  @override
  String get autoCheckUpdates => 'Check automatically';

  @override
  String get autoCheckUpdatesHelp =>
      'Looks for a new version in the background about twice a day.';

  @override
  String get autoPlayNext => 'Auto-play next: ON';

  @override
  String get autoPlayOff => 'Auto-play next: OFF';

  @override
  String get autoRestoreSuccess => 'Data restored from backup successfully!';

  @override
  String get autoRetry => 'Retry when the network returns';

  @override
  String get autoRetryHelp =>
      'Anything that failed because the network dropped is retried on its own when it returns. Server refusals are not retried — repeating them unchanged just fails again.';

  @override
  String get autoSwitchDisabledHint =>
      'Auto-switching is off — the app uses the single Server URL from Settings.';

  @override
  String get autoUrlSwitching => 'Automatic URL switching';

  @override
  String get autoUrlSwitchingDesc =>
      'Connect through the local URL when it is reachable, and use external connections elsewhere';

  @override
  String get availability => 'Availability';

  @override
  String get availabilityOffline => 'Offline (local copy)';

  @override
  String get availabilityServer => 'Server (stream)';

  @override
  String get availableOfflineNow => 'Now available offline';

  @override
  String get backgroundDownload => 'Downloading files in background...';

  @override
  String get backgroundPlay => 'Background play';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get backupFileSaved => 'Encrypted backup saved';

  @override
  String get backupKeyMismatch =>
      'This backup is encrypted with a different key. Import the matching backup key first.';

  @override
  String get backupNote =>
      'Includes playlists, tags, the offline index, artwork links and settings. Passwords and usernames are never backed up, and media files are not included.';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get backupSettings => 'Backup All Data';

  @override
  String get backupSettingsSubtitle =>
      'Seven dated copies that refresh themselves — restore any of them, or export one to share';

  @override
  String backupSuccess(Object path) {
    return 'Backup saved to: $path';
  }

  @override
  String backupsKept(int count) {
    return '$count backups kept';
  }

  @override
  String get batchDownloadSelected => 'Download selected';

  @override
  String get batchFromPlaylistNote => 'This link came from inside a playlist';

  @override
  String get batchLoading => 'Reading the playlist…';

  @override
  String get batchNothingSelected => 'Select at least one item';

  @override
  String get batchSaveToDevice => 'Save a copy on the device';

  @override
  String batchSelectedOf(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get batchThisVideoOnly => 'Download this video only';

  @override
  String get batchTitle => 'Batch download';

  @override
  String get builtWith => 'Built with';

  @override
  String get cancel => 'Cancel';

  @override
  String get cardView => 'Card view';

  @override
  String get changeQuality => 'Change quality';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get chooseBackupFile => 'Choose the backup file';

  @override
  String get chooseOptions => 'Options';

  @override
  String get cleaningServer => 'Cleaning up the server...';

  @override
  String get clear => 'Clear';

  @override
  String get clearAllConfirm =>
      'This will remove all saved settings including credentials. Continue?';

  @override
  String get clearAllSettings => 'Clear All Settings';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get clearLogsConfirm => 'Delete all diagnostic logs?';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get clipboardFound => 'A link is ready in your clipboard';

  @override
  String get clipboardLinkReady => 'Paste link';

  @override
  String get closePlayer => 'Close player';

  @override
  String get comingSoonPhase =>
      'This screen is built in a later phase of the plan';

  @override
  String get compactView => 'Compact view';

  @override
  String get compatiblePlayback => 'Best playback compatibility';

  @override
  String get compatiblePlaybackHelp =>
      'Asks the server for H.264/AAC, which every phone decodes in hardware. Without it YouTube may deliver AV1, which many devices render as a garbled picture. Turning it off allows the highest resolution at the cost of compatibility.';

  @override
  String get completed => 'Completed';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get connectionSuccessful => 'Connected successfully — settings saved';

  @override
  String get contactDeveloper => 'Contact Developer';

  @override
  String get continueAsAudio => 'Continue as audio';

  @override
  String get continueAsAudioBody =>
      'Keep playing this as audio from the same second?';

  @override
  String get continueAsAudioNo => 'No, stop';

  @override
  String get continueAsAudioTitle => 'Continue in the background?';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get copyright => '© 2026 Yasir Sagheer';

  @override
  String get couldNotLoadPlaylist =>
      'Couldn\'t load this playlist. Check the URL and your connection.';

  @override
  String get create => 'Create';

  @override
  String get createPlaylist => 'Create Playlist';

  @override
  String get creator => 'Creator';

  @override
  String get credentialsRequired =>
      'Username and password are required to connect to the server.';

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
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String deleteTagConfirm(Object tag) {
    return 'Delete the tag \"$tag\" from all items? The videos themselves are not deleted.';
  }

  @override
  String get deleteVideo => 'Delete Video';

  @override
  String deleteVideoConfirm(Object title) {
    return 'Delete \"$title\"?\n\nThis will remove the file from your device.';
  }

  @override
  String deletedCount(Object count) {
    return '$count deleted';
  }

  @override
  String get deletedFromServer => 'Deleted from the server';

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
  String get diagnosticLogsSubtitle =>
      'View, search, and share app logs (redacted)';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get disclaimer => 'Disclaimer';

  @override
  String get disclaimerText =>
      'This app is a client for MeTube server. The developer is not responsible for how users utilize this tool. Please respect copyright laws and terms of service of content platforms.';

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
  String get downloadNow => 'Download';

  @override
  String get downloadQuality => 'Download Quality';

  @override
  String get downloadStarted => 'Download started...';

  @override
  String downloadStartedQuality(Object quality) {
    return 'Download started · $quality';
  }

  @override
  String downloadTracks(int count) {
    return 'Download $count Tracks';
  }

  @override
  String get downloadUrlUnavailable => 'Download URL not available';

  @override
  String get downloading => 'Downloading...';

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
  String get enterFullscreen => 'Fullscreen';

  @override
  String get enterUrl => 'Enter URL';

  @override
  String get enterUrlHint => 'Paste video URL here...';

  @override
  String get enterUrlPrompt => 'Enter a video URL to download:';

  @override
  String get errAuth => 'Wrong username or password';

  @override
  String get errNetwork => 'Cannot reach the server';

  @override
  String get errNoApi => 'The address responds but has no MeTube API';

  @override
  String get errNotMeTube => 'This address is not a MeTube server';

  @override
  String get errPlatformBlocked =>
      'The platform requires login — the server admin should refresh the cookies';

  @override
  String get errPollTimeout => 'The server took too long — try again';

  @override
  String errServer(Object message) {
    return 'Server error: $message';
  }

  @override
  String errorGeneric(Object message) {
    return 'Error: $message';
  }

  @override
  String get errorLogs => 'Error Logs';

  @override
  String get errorLogsSubtitle => 'View app logs for diagnostics';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String get exportKeySubtitle =>
      'Required to restore on a new phone or after reinstall';

  @override
  String get exportShare => 'Export & share';

  @override
  String get exportShareSubtitle => 'A dated copy to send or keep elsewhere';

  @override
  String get externalNetworkDesc =>
      'When the local URL can\'t be reached, the app connects through the first reachable URL below, from top to bottom.';

  @override
  String get externalNetworkSection => 'External network';

  @override
  String get externalPlayerLocalOnly =>
      'Local copy only — the server link is never handed to another app';

  @override
  String get externalPlayerShort => 'Another player';

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
  String get importBackup => 'Import a backup';

  @override
  String get inPlaylists => 'In playlists';

  @override
  String get invalidUrl => 'Enter a valid link';

  @override
  String get itemOptions => 'Item options';

  @override
  String get itemUnavailable => 'No longer available';

  @override
  String get keyExportFailed => 'Failed to export backup key';

  @override
  String keyExportedMessage(Object path) {
    return 'Saved to:\n$path\n\nUpload this file to Google Drive (or another safe place). You\'ll need it to restore your backup after Clear Data or on a new phone.';
  }

  @override
  String get keyExportedTitle => 'Backup key saved';

  @override
  String get keyImportConfirm => 'Replace key';

  @override
  String get keyImportConfirmMessage =>
      'This will replace the device\'s current encryption key.\n\nAny backup file already on disk that was encrypted with the previous key will become unreadable.\n\nContinue only if this key matches your backup file.';

  @override
  String get keyImportConfirmTitle => 'Replace current key?';

  @override
  String get keyImportInvalid => 'Invalid key file';

  @override
  String get keyImportNotFound =>
      'Key file not found at Downloads/MeTube_Super/metube_super_backup_key.txt';

  @override
  String get keyImportedMessage =>
      'Encryption key restored. You can now use Restore All Data to recover your backup.';

  @override
  String get keyImportedTitle => 'Key imported';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'System';

  @override
  String get languageSystemHint => 'Follows your phone\'s language';

  @override
  String lastBackup(String when) {
    return 'Last backup $when';
  }

  @override
  String lastCheckedAt(String when) {
    return 'Last checked $when';
  }

  @override
  String get latestAdditions => 'Latest additions';

  @override
  String get licensedUnder => 'Licensed under GPL-3.0';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get listenInBackground => 'Listen in the background';

  @override
  String get loadingVideo => 'Loading video...';

  @override
  String get localCopyRemoved => 'Local copy removed';

  @override
  String get localNetworkDesc =>
      'The app connects to the server through this URL when it can be reached.';

  @override
  String get localNetworkSection => 'Local network';

  @override
  String get localOnlyYoutubeMessage =>
      'Direct downloads support YouTube only.\nConfigure a MeTube server in Settings to download from other platforms.';

  @override
  String get localUrlLabel => 'Local server URL';

  @override
  String localVideos(int count) {
    return 'Library ($count)';
  }

  @override
  String get lockTouch => 'Lock touch';

  @override
  String get logsEmpty => 'The log is empty';

  @override
  String get logsSanitizedNote =>
      'Links, addresses and credentials are stripped before sharing';

  @override
  String get logsShareText =>
      'MeTube Super logs (URLs/IPs/credentials redacted)';

  @override
  String get madeOffline => 'Saved for offline';

  @override
  String get madeWithLove => 'Made with ❤️ By Yasir Sagheer';

  @override
  String get makeAvailableOffline => 'Make available offline';

  @override
  String get makeOffline => 'Make available offline';

  @override
  String get manageTags => 'Manage tags';

  @override
  String get metubeCredit => 'The self-hosted server this app is a client for';

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
  String get modeStopAtEnd => 'Stop at end';

  @override
  String get navLibrary => 'Library';

  @override
  String get navMyDownloads => 'My downloads';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Settings';

  @override
  String get needsAttention => 'Needs your attention';

  @override
  String get networkBackRetrying => 'Network is back — retrying';

  @override
  String get networkSettings => 'Networks';

  @override
  String get networkSettingsSubtitle =>
      'Auto-switch between local and external server URLs';

  @override
  String get newPlaylistAction => 'New playlist';

  @override
  String get newTagHint => 'New tag';

  @override
  String get next => 'Next';

  @override
  String get noBackupsYet => 'No backups yet';

  @override
  String get noDownloads => 'No Downloads';

  @override
  String get noDownloadsMessage =>
      'Downloaded videos will appear here.\nShare a video link or use the Add URL button.';

  @override
  String get noExternalPlayer => 'No external player on this device';

  @override
  String get noLogsFound => 'No logs found';

  @override
  String get noPasswordTip =>
      'No password? Leave auth fields empty for open servers!';

  @override
  String get noPlayableSource => 'This item has no playable source';

  @override
  String get noPlaylists => 'No playlists';

  @override
  String get noPlaylistsMessage => 'Create a playlist to organize your videos';

  @override
  String get noResults => 'No results';

  @override
  String get noResultsMessage => 'No items match your search.';

  @override
  String get noServerMessage =>
      'Enter your MeTube server address in Settings to start downloading';

  @override
  String get noServerTitle => 'No server yet';

  @override
  String get noTagsYet => 'No tags yet. Create one below.';

  @override
  String get noValidUrl => 'No valid video URL found';

  @override
  String get noVideosFound => 'Your library is empty';

  @override
  String get noVideosHint =>
      'Share a video URL from any app, or tap the + button to add one';

  @override
  String get noWarranty => 'Provided as is, without any warranty.';

  @override
  String get nonYoutubeQualityNote =>
      'Non-YouTube platforms only support best quality or audio';

  @override
  String get notAffiliated =>
      'Unofficial client — not affiliated with the MeTube project or yt-dlp, and not endorsed by them.';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get offlineSmartList => 'Offline';

  @override
  String get ok => 'OK';

  @override
  String get onServerPhase => 'On the server';

  @override
  String onServerProgress(Object percent) {
    return 'On the server · $percent%';
  }

  @override
  String get openGithub => 'Open MeTube on GitHub';

  @override
  String get openInExternalPlayer => 'Open in another player';

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
  String get pasteUrlHint => 'Paste the link here…';

  @override
  String get pause => 'Pause';

  @override
  String get pickAnotherFile => 'From another file…';

  @override
  String get pickAnotherFileSubtitle =>
      'A backup from another phone or an older version';

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
  String get playAll => 'Play all';

  @override
  String get playAllFavorites => 'Play all favorites';

  @override
  String get playModeLabel => 'Mode';

  @override
  String get playbackError => 'Playback Error';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get playerError => 'Couldn\'t play this file';

  @override
  String get playerLoading => 'Loading video...';

  @override
  String get playingFromDevice => 'Playing from your device';

  @override
  String get playlist => 'Playlist';

  @override
  String get playlistCreated => 'Playlist created';

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
  String get preferences => 'Preferences';

  @override
  String get preparingDownload => 'Preparing download...';

  @override
  String get preparingShare => 'Preparing the file for sharing…';

  @override
  String preparingToShare(String percent) {
    return 'Preparing to share… $percent%';
  }

  @override
  String get previous => 'Previous';

  @override
  String get pullingToDevice => 'Saving to device…';

  @override
  String pullingToDeviceProgress(Object percent) {
    return 'Saving to device · $percent%';
  }

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
  String get qualityBest => 'Best';

  @override
  String get qualityHelper =>
      'Used by quick download, by whole-playlist downloads, and by \"Download now\" in the clipboard bar — and it is the preselected option in the add-link sheet. So it matters whether or not quick download is on.';

  @override
  String queueItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get queueLabel => 'Queue';

  @override
  String queuePosition(int position) {
    return 'Queue position: $position';
  }

  @override
  String get queued => 'Queued';

  @override
  String get queuedSection => 'Waiting';

  @override
  String get quickDownload => 'Quick download';

  @override
  String get quickDownloadHelp =>
      'A shared or pasted link starts downloading immediately at the default quality, with no sheet. Numeric qualities are YouTube-only — anything else downloads at best quality, and an \"audio only\" default applies everywhere.';

  @override
  String get readyToShare => 'Ready to share!';

  @override
  String get reelsEndBack => 'Back to library';

  @override
  String get reelsEndContinue => 'Continue the rest of the list';

  @override
  String get reelsEndReplay => 'Replay from the start';

  @override
  String get reelsEndTitle => 'End of the shorts lane';

  @override
  String get reelsSwipeHint => 'Swipe up for the next short';

  @override
  String get refresh => 'Refresh';

  @override
  String get remove => 'Remove';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get removeLocalCopy => 'Remove local copy';

  @override
  String get removeOfflineConfirm =>
      'Delete the local copy from this device?\nThe video stays on the server and can be streamed again.';

  @override
  String get removeOfflineCopy => 'Remove offline copy';

  @override
  String get removeOfflineTitle => 'Remove Offline Copy';

  @override
  String removeUnavailable(int count) {
    return 'Remove $count unavailable';
  }

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get removedFromPlaylist => 'Removed from the playlist';

  @override
  String get rename => 'Rename';

  @override
  String get renameTag => 'Rename tag';

  @override
  String get reorderHint => 'Drag to reorder';

  @override
  String get reportBug => 'Report a Bug';

  @override
  String get restoreCancelled => 'Backup file not found in Downloads folder';

  @override
  String get restoreConfirm =>
      'Restore data from the backup file? This overwrites current playlists, tags and settings.';

  @override
  String get restoreData => 'Restore';

  @override
  String get restoreFailed => 'Restore failed — invalid backup file';

  @override
  String get restoreFromBackupSubtitle =>
      'Pick one of the saved backups, or a file';

  @override
  String get restoreNotFound =>
      'No backup file found in Downloads/MeTube_Super';

  @override
  String get restoreSettings => 'Restore All Data';

  @override
  String get restoreSettingsSubtitle =>
      'Import from Downloads/metube_lite_backup.json';

  @override
  String get restoreSuccess => 'Data restored successfully';

  @override
  String resultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get retry => 'Retry';

  @override
  String retryingAttempt(int attempt, int max) {
    return 'Retry $attempt/$max…';
  }

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get saveToDevice => 'Save to device';

  @override
  String get savedOnDevice => 'Saved on device';

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
  String get seekBackward10 => 'Back 10 seconds';

  @override
  String get seekForward10 => 'Forward 10 seconds';

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
  String get serverDownloadDesc =>
      'Videos will be sent to your MeTube Super/TrueNAS server';

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
  String get serverUrlHelpBody =>
      'The address of your MeTube server, e.g. http://192.168.1.10:8081. Use the LAN IP for plain HTTP at home, or an HTTPS address (e.g. a Cloudflare Tunnel) for access from outside.';

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
  String get setupServer => 'Set up the server';

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
  String get shortsFilter => 'Shorts';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get signInRequired => 'Sign-in required';

  @override
  String get signInRequiredHint =>
      'The server rejected the saved credentials. Update the username and password in settings.';

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
  String get sortedByLastPlayed => 'By last played';

  @override
  String get source => 'Source';

  @override
  String get sourceCode => 'Source code';

  @override
  String get speedNormal => 'Normal';

  @override
  String get startDownload => 'Start download';

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
  String get streamingFromServer => 'Streaming from the server';

  @override
  String get supportedPlatforms =>
      'Supported: YouTube, Twitter/X, Instagram, TikTok, Facebook, Vimeo & more';

  @override
  String get tagActionsHint => 'Long-press a tag to rename or delete it.';

  @override
  String get tagAudio => 'Audio';

  @override
  String get tagVideo => 'Video';

  @override
  String get tags => 'Tags';

  @override
  String get tagsOpenFiltered => 'Opens the library filtered';

  @override
  String get tapToCopy => 'Tap to copy';

  @override
  String get testingConnection => 'Testing connection…';

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
  String get titleLabel => 'Title';

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
  String get unlockTouch => 'Unlock';

  @override
  String get unpinPlaylist => 'Unpin';

  @override
  String get upNext => 'Up next';

  @override
  String upNextIn(String name) {
    return 'Up next in «$name»';
  }

  @override
  String get updateAllowInstallBody =>
      'Android needs your permission before the app can install its own updates. Grant it once in system settings, then tap Install again.';

  @override
  String get updateAllowInstallTitle => 'Allow installing updates';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get updateCheckFailed => 'Couldn\'t check for updates';

  @override
  String get updateChecking => 'Checking…';

  @override
  String get updateCredentials => 'Update credentials';

  @override
  String get updateDownloadFailed => 'Couldn\'t download the update';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String get updateFailedToStart => 'Couldn\'t open the installer';

  @override
  String get updateInstall => 'Install';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNever => 'Not yet';

  @override
  String get updateNow => 'Download update';

  @override
  String get updateOpenSystemSettings => 'Open settings';

  @override
  String get updateReady => 'Ready to install';

  @override
  String updateSizeMb(String size) {
    return '$size MB';
  }

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateUpToDate => 'You\'re on the latest version';

  @override
  String updateVersionAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateWhatsNew => 'What\'s new';

  @override
  String get updates => 'Updates';

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
  String get viewAll => 'View all';

  @override
  String get viewAllInPlaylists => 'View all';

  @override
  String get viewCards => 'Cards';

  @override
  String get viewGrid => 'Grid';

  @override
  String get viewList => 'List';

  @override
  String get viewMode => 'View';

  @override
  String get waiting => 'Waiting for server...';

  @override
  String get waitingForWifi => 'Waiting for Wi-Fi';

  @override
  String get wifiOnly => 'Download over Wi-Fi only';

  @override
  String get wifiOnlyHelp =>
      'Stops pulling files to your device over mobile data. Tasks wait and resume automatically on Wi-Fi.';

  @override
  String get yourPlaylists => 'Your playlists';

  @override
  String get yourTags => 'Your tags';

  @override
  String get youtubeDownloadStarting => 'Starting YouTube download...';

  @override
  String get ytdlpCredit => 'The downloader MeTube runs';
}
