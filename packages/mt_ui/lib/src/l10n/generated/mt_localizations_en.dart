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
  String get aboutApp => 'About the app';

  @override
  String get aboutDescriptionLite =>
      'A light, fast app that downloads videos from many platforms through your MeTube server, pulls them to your device and cleans the server afterwards. It has its own player and playlists.';

  @override
  String get aboutDescriptionSuper =>
      'The server owner\'s edition: one library across server and device, streaming, tags, offline availability, batch downloads and server address switching.';

  @override
  String get activeDownloads => 'Active downloads';

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
  String get addTo => 'Add to…';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get addToPlaylist => 'Add to playlist';

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
  String get addingToServer => 'Sending to the server…';

  @override
  String get allDownloadsFinished => 'All downloads finished.';

  @override
  String get allFolders => 'All folders';

  @override
  String get allPlatforms => 'All platforms';

  @override
  String get alreadyInPlaylist => 'Already added';

  @override
  String get alreadySubscribed => 'This channel is already followed';

  @override
  String get appTitle => 'MeTube Super';

  @override
  String get appearanceAndLanguage => 'Appearance & language';

  @override
  String audioChannels(int count) {
    return '$count channels';
  }

  @override
  String get audioMono => 'Mono';

  @override
  String get audioOnly => 'Audio only';

  @override
  String get audioStereo => 'Stereo';

  @override
  String get authHelper => 'Leave empty for open servers (no password)';

  @override
  String get authentication => 'Authentication (optional)';

  @override
  String get autoBuilt => 'Automatic';

  @override
  String get autoCheckUpdates => 'Check automatically';

  @override
  String get autoCheckUpdatesHelp =>
      'Looks for a new version in the background about twice a day.';

  @override
  String get autoRestoreSuccess => 'Data restored from the backup.';

  @override
  String get autoRetry => 'Retry when the network returns';

  @override
  String get autoRetryHelp =>
      'Anything that failed because the network dropped is retried on its own when it returns. Server refusals are not retried: repeating them unchanged just fails again.';

  @override
  String get autoSwitchDisabledHint =>
      'Auto-switching is off, so the app uses the single Server URL from Settings.';

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
  String get backupNote =>
      'Includes playlists, tags, the offline index, artwork links and settings. Passwords and usernames are never backed up, and media files are not included.';

  @override
  String get backupSettings => 'Back up all data';

  @override
  String get backupSettingsSubtitle =>
      'Seven dated copies that refresh themselves. Restore any of them, or export one to share';

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
  String bitrateKbps(String value) {
    return '$value kb/s';
  }

  @override
  String bitrateMbps(String value) {
    return '$value Mb/s';
  }

  @override
  String get builtWith => 'Built with';

  @override
  String get cancel => 'Cancel';

  @override
  String get cancelSaveToDevice => 'Stop saving to the phone';

  @override
  String get changeQuality => 'Change quality';

  @override
  String get channelNameFolder => 'Named after the channel';

  @override
  String get channelUrl => 'Channel or playlist link';

  @override
  String get channelUrlHint => 'https://www.youtube.com/@name';

  @override
  String chapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String chapterNumber(int number) {
    return 'Chapter $number';
  }

  @override
  String get chaptersFold => 'Hide chapters';

  @override
  String chaptersFromTranscript(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters from the transcript',
      one: '1 chapter from the transcript',
    );
    return '$_temp0';
  }

  @override
  String get chaptersShowAll => 'View all chapters';

  @override
  String get chaptersUnfold => 'Show chapters';

  @override
  String get checkEvery => 'How often to look';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkNow => 'Check now';

  @override
  String get checkQueued =>
      'Checking now. Anything new appears in the library.';

  @override
  String get chooseFolder => 'Choose a folder';

  @override
  String get chooseOptions => 'Options';

  @override
  String get cleaningServer => 'Cleaning up the server...';

  @override
  String get clear => 'Clear';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get clearLogsConfirm => 'Delete all diagnostic logs?';

  @override
  String get clipboardFound => 'A link is ready in your clipboard';

  @override
  String get clipboardLinkReady => 'Paste link';

  @override
  String get closePlayer => 'Close player';

  @override
  String get cloudflareAccess => 'Cloudflare Access (optional)';

  @override
  String get cloudflareAccessHelp =>
      'Only for a server behind Cloudflare Access. Create a service token in Cloudflare Zero Trust, allow it with a Service Auth policy on this server\'s address, and paste its two values here. They are sent to https addresses only.';

  @override
  String get cloudflareBothRequired =>
      'Enter both the Client ID and the Client Secret, or leave both empty';

  @override
  String get cloudflareClientId => 'Client ID';

  @override
  String get cloudflareClientSecret => 'Client Secret';

  @override
  String get cloudflareHideSecret => 'Hide the secret';

  @override
  String get cloudflareShowSecret => 'Show the secret';

  @override
  String get cloudflareTokenSaved => 'Service token saved';

  @override
  String get columnAdded => 'Added';

  @override
  String get columnLength => 'Length';

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
  String get connectionFailed => 'Connection failed';

  @override
  String get connectionSuccessful => 'Connected. Settings saved.';

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
  String get cookies => 'Cookies';

  @override
  String get cookiesAbsent => 'The server has no cookies';

  @override
  String get cookiesDelete => 'Delete the cookies';

  @override
  String get cookiesDeleteBody =>
      'The server stops using them, and the platforms that needed a login will refuse again.';

  @override
  String get cookiesDeleted => 'Cookies deleted from the server';

  @override
  String get cookiesHelp =>
      'In your browser, use an extension that exports cookies in the Netscape format (one file per platform) and pick the files here. The server then uses them for every download, and yt-dlp decides when it needs them. Cookies expire, so a download that starts failing again usually means a fresh export is due.';

  @override
  String get cookiesNotNetscape =>
      'None of these files holds cookies in the Netscape format';

  @override
  String get cookiesPresent => 'The server has cookies';

  @override
  String get cookiesPrivacy =>
      'The file is sent straight to your server and never stored on this phone. It is your accounts\' sign-in material, so only ever upload it to a server you own.';

  @override
  String get cookiesReplace => 'Replace the cookies files';

  @override
  String get cookiesReplaceNote =>
      'Each upload replaces the server\'s whole cookies file. To keep several platforms, pick all their files together every time, the ones you sent before too. To pick more than one, long-press the first file.';

  @override
  String cookiesSentFor(String sites) {
    return 'Cookies sent for: $sites';
  }

  @override
  String get cookiesSubtitle =>
      'For the platforms that will not download without a login';

  @override
  String get cookiesTooLarge =>
      'That file is larger than 1 MB, which is more than the server accepts.';

  @override
  String get cookiesUnknown => 'This MeTube cannot say whether it has cookies';

  @override
  String get cookiesUpload => 'Choose cookies files';

  @override
  String get cookiesUploaded => 'Cookies sent to the server';

  @override
  String get cookiesWhat =>
      'Some platforms refuse to hand a video over unless the request looks like a signed-in browser. A cookies file exported from your browser gives the server that.';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String copyingToPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips to this phone',
      one: '1 clip to this phone',
    );
    return '$_temp0';
  }

  @override
  String get copyright => '© 2026 Yasir Sagheer';

  @override
  String get couldNotLoadPlaylist =>
      'Couldn\'t load this playlist. Check the URL and your connection.';

  @override
  String get create => 'Create';

  @override
  String get createPlaylist => 'Create playlist';

  @override
  String get creator => 'Creator';

  @override
  String get defaultQuality => 'Default video quality';

  @override
  String get delete => 'Delete';

  @override
  String get deleteFromServer => 'Delete from server';

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
  String get deleteSelected => 'Delete selected';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String deleteTagConfirm(Object tag) {
    return 'Delete the tag \"$tag\" from all items? The videos themselves are not deleted.';
  }

  @override
  String get deleteVideo => 'Delete video';

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
  String get deselectAll => 'Deselect all';

  @override
  String desktopAddLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count links',
      one: 'Add 1 link',
      zero: 'Nothing to add',
    );
    return '$_temp0';
  }

  @override
  String get desktopAddressAdd => 'Add';

  @override
  String get desktopAddressInUse => 'In use';

  @override
  String get desktopAddressInvalid => 'Not an address, or already in the list';

  @override
  String get desktopAddressNew =>
      'New address, e.g. https://metube.example.com';

  @override
  String get desktopAddressStatusNotMeTube => 'Not a MeTube server';

  @override
  String get desktopAddressStatusOk => 'Answers';

  @override
  String get desktopAddressStatusRefused => 'Refuses the password';

  @override
  String get desktopAddressStatusUnreachable => 'Not reachable';

  @override
  String get desktopAddressTest => 'Test';

  @override
  String get desktopAddressUse => 'Use';

  @override
  String get desktopAddresses => 'Addresses';

  @override
  String get desktopAddressesHint =>
      'The app uses the address you choose and never switches by itself.';

  @override
  String get desktopAskEachTime => 'Ask me every time';

  @override
  String get desktopAskEachTimeHint =>
      'Windows asks for a folder at each download.';

  @override
  String get desktopBack => 'Back';

  @override
  String get desktopBackUpNow => 'Back up now';

  @override
  String get desktopBackupHint =>
      'This computer keeps its last seven backups, at least an hour apart, in its own folder.';

  @override
  String get desktopBackupsNone => 'No backup yet';

  @override
  String get desktopBrowserButton => '“To Ember” button in the browser';

  @override
  String get desktopBrowserButtonCopied =>
      'Code copied. Make a new bookmark and paste it as its address (URL).';

  @override
  String get desktopBrowserButtonCopy => 'Copy the code';

  @override
  String get desktopBrowserButtonFailed =>
      'The page could not be opened; copy the code instead.';

  @override
  String get desktopBrowserButtonHint =>
      'A button on your bookmarks bar: one click on any video\'s page opens the add dialog here with its link. Nothing is sent until you press Add.';

  @override
  String get desktopBrowserButtonName => 'To Ember';

  @override
  String get desktopBrowserButtonOpen => 'Open the setup page';

  @override
  String get desktopBrowserPageCopyInstead =>
      'If dragging does not work, make a new bookmark and paste this as its address:';

  @override
  String get desktopBrowserPageDragHint =>
      'Drag it to the bar; a click here does nothing.';

  @override
  String get desktopBrowserPageStep1 =>
      'Show the bookmarks bar if it is hidden:';

  @override
  String get desktopBrowserPageStep2 =>
      'Drag the button below onto the bar with the mouse.';

  @override
  String get desktopBrowserPageStep3 =>
      'On any video\'s page, click it: MeTube Ember opens its add dialog with the link. The first time, the browser asks whether to open the app; allow it.';

  @override
  String get desktopBrowserPageTitle =>
      'Add the “To Ember” button to your browser';

  @override
  String get desktopChangeFolder => 'Change…';

  @override
  String get desktopChannel => 'Channel';

  @override
  String get desktopChannelClips => 'In your library';

  @override
  String get desktopChannels => 'Channels';

  @override
  String get desktopChannelsInLibrary => 'Channels in your library';

  @override
  String get desktopChapters => 'Chapters';

  @override
  String get desktopCheckAll => 'Check all';

  @override
  String get desktopChooseClip => 'Select';

  @override
  String get desktopClearFilters => 'Clear filters';

  @override
  String get desktopClearFinished => 'Hide finished';

  @override
  String get desktopClearSelection => 'Clear selection';

  @override
  String get desktopCookiesPrivacy =>
      'The files go straight to your server and are never kept on this computer. They are your accounts\' sign-in material, so only ever send them to a server you own.';

  @override
  String get desktopCookiesReplaceNote =>
      'Each upload replaces the server\'s whole cookies file. To keep several platforms, choose all their files together every time, the ones you sent before too. Hold Ctrl to choose more than one.';

  @override
  String get desktopCopiedLinkAdd => 'Add…';

  @override
  String get desktopCopiedLinkTitle => 'Add this link to the server?';

  @override
  String get desktopCopyCancelled => 'Cancelled';

  @override
  String get desktopCopyFile => 'Copy file';

  @override
  String get desktopCopyFileFailed => 'The file could not be copied';

  @override
  String get desktopCopyFileLarge => 'A large file';

  @override
  String desktopCopyFileLargeMessage(String size) {
    return 'This clip is $size. It is saved to your download folder first, then copied; many chat apps refuse a file this big.';
  }

  @override
  String desktopCopyFileNoSpace(String needed, String free) {
    return 'Not enough space on the drive: the file is $needed and $free is free';
  }

  @override
  String get desktopCopyFilePreparing =>
      'Preparing the file to copy; its progress is in Downloads';

  @override
  String get desktopCopyLink => 'Copy link';

  @override
  String get desktopCopyOneClip => 'Copying takes one clip at a time';

  @override
  String get desktopCopyQueued => 'Waiting its turn';

  @override
  String get desktopCopyQuote => 'Copy with time and link';

  @override
  String get desktopDefaultQualityHint =>
      'What each add starts with; you can still change it for each link.';

  @override
  String desktopDeleteSelectedConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Delete $count clips from the server? Copies on this computer stay.',
      one: 'Delete 1 clip from the server? A copy on this computer stays.',
    );
    return '$_temp0';
  }

  @override
  String get desktopDesktopSection => 'Desktop';

  @override
  String get desktopDiscover => 'Discover MeTube Ember';

  @override
  String get desktopDiscoverAddLink => 'Paste or drop a link';

  @override
  String get desktopDiscoverAddLinkLine =>
      'Ctrl+V anywhere, or drop a link on the window, to add it.';

  @override
  String get desktopDiscoverAdding => 'Adding and sharing';

  @override
  String get desktopDiscoverBrowser => 'From the browser';

  @override
  String get desktopDiscoverBrowserLine =>
      'The “To Ember” button on your bookmarks bar opens the add dialog with the page you are on.';

  @override
  String get desktopDiscoverChapters => 'Chapters';

  @override
  String get desktopDiscoverChaptersLine =>
      'A clip\'s parts, from its transcript, on its page.';

  @override
  String get desktopDiscoverChoose => 'Choose many';

  @override
  String get desktopDiscoverChooseLine =>
      'The round mark, or Ctrl or Shift with a click; then add them to a list or delete them together.';

  @override
  String get desktopDiscoverDragOut => 'Drag a clip out';

  @override
  String get desktopDiscoverDragOutLine =>
      'Onto a folder or another app, as a file.';

  @override
  String get desktopDiscoverExport => 'Export a transcript';

  @override
  String get desktopDiscoverExportLine =>
      'As text, or as SRT subtitles for another player.';

  @override
  String get desktopDiscoverHint =>
      'Everything the app can do, a line each, with its keys.';

  @override
  String get desktopDiscoverLibrary => 'The library';

  @override
  String get desktopDiscoverListening =>
      'For sound: a quiet room with the cover large, in full screen.';

  @override
  String get desktopDiscoverMini => 'Small window';

  @override
  String get desktopDiscoverMiniLine =>
      'A small card above every other window, by the clock.';

  @override
  String get desktopDiscoverPhone => 'With your phone';

  @override
  String get desktopDiscoverPhoneLine =>
      'Tags, lists and resume points, shared with MeTube Super through a folder you choose.';

  @override
  String get desktopDiscoverReading =>
      'The transcript as an article: click a sentence to hear it from there.';

  @override
  String get desktopDiscoverSaid => 'What was said';

  @override
  String get desktopDiscoverSearch => 'Search what was said';

  @override
  String get desktopDiscoverSearchLine =>
      'Find the clips where a word was spoken, not only in titles.';

  @override
  String get desktopDiscoverShortcutsLine =>
      'Every key the window answers, on one sheet.';

  @override
  String get desktopDiscoverShow => 'Show';

  @override
  String get desktopDiscoverStatsLine =>
      'The library counted: by site, channel and month.';

  @override
  String get desktopDiscoverSubtitles =>
      'The transcript over the picture, the spoken word lit up.';

  @override
  String get desktopDiscoverTheater =>
      'A larger picture that takes the side panel\'s place.';

  @override
  String get desktopDiscoverTry => 'Try it';

  @override
  String get desktopDiscoverWatching => 'Watching and listening';

  @override
  String get desktopDownloadFolder => 'Download folder';

  @override
  String get desktopDownloadFolderHint =>
      'Your own files: saved here, then the app leaves them alone.';

  @override
  String get desktopDownloadTo => 'Download…';

  @override
  String desktopDownloading(int percent) {
    return 'Downloading · $percent%';
  }

  @override
  String get desktopDownloads => 'Downloads';

  @override
  String get desktopDownloadsEmpty =>
      'Nothing is downloading. Add a link, or make a clip available offline.';

  @override
  String get desktopDragToReorder => 'Drag to reorder';

  @override
  String get desktopDropLinks => 'Drop to add';

  @override
  String get desktopEmptyLibraryMessage =>
      'Add a link, and the clip appears here once the server has it.';

  @override
  String get desktopExport => 'Export';

  @override
  String get desktopExportForPhone => 'Export for the phone';

  @override
  String get desktopExportForPhoneHint =>
      'Saves this computer\'s tags, lists and resume points, and its transcripts, as two files the phone restores. Restoring on the phone replaces its own tags and lists.';

  @override
  String get desktopExportMarkdown => 'Text (Markdown)';

  @override
  String get desktopExportPdf => 'Document (PDF)';

  @override
  String get desktopExportPhone => 'For the phone (Super\'s import)';

  @override
  String get desktopExportSrt => 'Subtitles (SRT)';

  @override
  String desktopExported(String name) {
    return 'Saved $name';
  }

  @override
  String desktopFileReadyToPaste(String name, String size) {
    return 'Ready to paste: $name · $size';
  }

  @override
  String get desktopFolderUnavailable => 'No folder available';

  @override
  String get desktopFolders => 'Folders';

  @override
  String get desktopForward => 'Forward';

  @override
  String get desktopGlobalShortcut => 'Play and pause from any app';

  @override
  String desktopGlobalShortcutHint(String keys) {
    return '$keys plays and pauses while the window is behind other apps.';
  }

  @override
  String desktopGlobalShortcutTaken(String keys) {
    return 'Another app already uses $keys.';
  }

  @override
  String get desktopHidePanel => 'Hide side panel';

  @override
  String get desktopHintShortcuts =>
      'Press ? for the keyboard shortcuts. Space plays and pauses; the arrow keys seek.';

  @override
  String get desktopHintShortcutsAction => 'Shortcuts';

  @override
  String get desktopHintTrayBody =>
      'It keeps playing from its icon by the clock. To quit, right-click the icon.';

  @override
  String get desktopHintTrayTitle => 'MeTube Ember is still running';

  @override
  String get desktopHints => 'Show tips';

  @override
  String get desktopHintsAgain => 'Show them again';

  @override
  String get desktopHintsHint =>
      'Two short tips, each shown once: the shortcuts at the first clip, the icon by the clock at the first close.';

  @override
  String get desktopImportFromPhone => 'Import from the phone…';

  @override
  String get desktopImportHint =>
      'A backup or transcripts file from MeTube Super or Lite, chosen here or dropped on the window. It is added to what is here; nothing is replaced.';

  @override
  String desktopImportedBackup(int tagged, int lists, int positions) {
    return 'Added from the phone. Tags: $tagged · lists: $lists · resume points: $positions';
  }

  @override
  String get desktopImportedNothing =>
      'Nothing new: this computer already had all of it.';

  @override
  String desktopImportedTranscripts(int count) {
    return 'Transcripts added: $count';
  }

  @override
  String desktopInLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in your library',
      one: '1 in your library',
    );
    return '$_temp0';
  }

  @override
  String get desktopKeyAddLink => 'Add the link you copied';

  @override
  String get desktopKeyFavorite => 'Add to favorites or remove';

  @override
  String get desktopKeyFullScreen =>
      'Full screen; for sound, the listening room';

  @override
  String get desktopKeyMenu => 'The clip\'s menu';

  @override
  String get desktopKeyMini => 'Small window above the others, and back';

  @override
  String get desktopKeyPlayPause => 'Play or pause';

  @override
  String get desktopKeyRepeat => 'Change repeat';

  @override
  String get desktopKeySearch => 'Search titles and what was said';

  @override
  String get desktopKeySeek => 'Back or forward 10 seconds';

  @override
  String get desktopKeyShortcuts => 'This list';

  @override
  String get desktopKeyVolume =>
      'Louder or quieter; in shorts, the previous or next one';

  @override
  String get desktopKeyZoomIn => 'Larger interface';

  @override
  String get desktopKeyZoomOut => 'Smaller interface';

  @override
  String get desktopKeyZoomReset => 'Interface at its usual size';

  @override
  String get desktopLanguageSystemHint => 'Follows the language of Windows.';

  @override
  String desktopLastArrival(String when) {
    return 'Last arrival $when';
  }

  @override
  String get desktopLess => 'Less';

  @override
  String get desktopLibraryLoading => 'Loading the library…';

  @override
  String get desktopLinkCopied => 'Link copied';

  @override
  String get desktopLinkDuplicate => 'Repeated above';

  @override
  String get desktopLinkInLibrary => 'Already in your library';

  @override
  String get desktopLinkPlaylist => 'A playlist: choose its clips';

  @override
  String get desktopLinkReady => 'Ready';

  @override
  String get desktopLinkUnsupported => 'A site this app doesn\'t know';

  @override
  String desktopLinksDropped(int count, int limit) {
    return 'Only the first $limit links are taken; $count more were left out.';
  }

  @override
  String desktopLinksFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
    );
    return '$_temp0';
  }

  @override
  String get desktopListeningClose => 'Close the listening room';

  @override
  String get desktopListeningRoom => 'Listening room';

  @override
  String get desktopLocalCopyRemoved => 'Local copy removed';

  @override
  String get desktopLogsCopied => 'Log copied, without links or addresses';

  @override
  String get desktopLogsCopy => 'Copy';

  @override
  String get desktopLogsSave => 'Save to a file';

  @override
  String get desktopMiniRestore => 'Back to the full window';

  @override
  String get desktopMiniWindow => 'Small window';

  @override
  String get desktopMore => 'More';

  @override
  String get desktopNarrowSidebar => 'Collapse sidebar';

  @override
  String get desktopNoChannelNames =>
      'Your server doesn\'t record which channel each clip came from, so this channel\'s clips can\'t be picked out. Follow it with its own folder, and whatever arrives there shows here.';

  @override
  String get desktopNoFavoritesMessage =>
      'Mark a clip as a favorite and it waits for you here.';

  @override
  String get desktopNoFavoritesTitle => 'No favorites yet';

  @override
  String get desktopNoMatchMessage => 'Clear a filter to see more.';

  @override
  String get desktopNoMatchTitle => 'Nothing matches these filters';

  @override
  String get desktopNoOfflineMessage =>
      'Choose “Make available offline” from a clip\'s menu, and it plays here without the server.';

  @override
  String get desktopNoOfflineTitle => 'Nothing kept on this computer yet';

  @override
  String get desktopNoServerMessage =>
      'Set up your MeTube server and its library appears here.';

  @override
  String get desktopNoTags =>
      'No tags yet. Tag a clip from its page and it appears here.';

  @override
  String get desktopNoTranscriptMessage =>
      'It shows here once the server has the clip\'s subtitles.';

  @override
  String get desktopNoTranscriptTitle => 'No transcript for this clip';

  @override
  String get desktopNotABackup =>
      'This file is not a MeTube backup or transcripts file.';

  @override
  String desktopNotWatched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count not watched',
      one: '1 not watched',
    );
    return '$_temp0';
  }

  @override
  String get desktopNothingPlaying => 'Nothing playing';

  @override
  String get desktopNothingPlayingHint =>
      'Play a clip and its transcript, what comes next and its details appear here.';

  @override
  String get desktopNoticeSaved => 'Saved to this computer';

  @override
  String get desktopNotifyArrivalsHint =>
      'A Windows notice when new clips from the channels you follow reach the server.';

  @override
  String get desktopOfferCopiedLinks => 'Offer links I copy';

  @override
  String get desktopOfferCopiedLinksHint =>
      'When you copy a video link in another app, a notification offers to add it. Only links are looked at, and none is saved.';

  @override
  String desktopOfflineCount(int count) {
    return '$count offline';
  }

  @override
  String get desktopOfflineFolder => 'Offline folder';

  @override
  String get desktopOfflineFolderHint =>
      'Copies the app knows and plays without the server; \"Remove local copy\" deletes them.';

  @override
  String desktopOfflineProgress(int percent) {
    return 'Offline · $percent%';
  }

  @override
  String get desktopOpenChannels => 'Open channels';

  @override
  String get desktopOpenInExplorer => 'Open in Explorer';

  @override
  String get desktopPaletteClose => 'to close';

  @override
  String get desktopPaletteCommands => 'Commands';

  @override
  String get desktopPaletteHint =>
      'Search titles and what was said, or type > for commands';

  @override
  String desktopPaletteList(String name) {
    return 'List: $name';
  }

  @override
  String get desktopPaletteMove => 'to move';

  @override
  String get desktopPaletteOpen => 'to open';

  @override
  String get desktopPaletteSaid => 'Said inside clips';

  @override
  String get desktopPaletteSave => 'Save this search';

  @override
  String desktopPaletteSettings(String section) {
    return 'Settings: $section';
  }

  @override
  String get desktopPaletteTitles => 'Titles';

  @override
  String get desktopPinned => 'Pinned';

  @override
  String get desktopPlayNext => 'Play next';

  @override
  String get desktopPlaysNext => 'Plays next, after this one';

  @override
  String get desktopPullAfter => 'Then download it to this computer';

  @override
  String get desktopQueueEnd => 'Nothing comes after this one';

  @override
  String desktopQuote(String text, String title, String time, String link) {
    return '“$text”\n— $title, $time\n$link';
  }

  @override
  String get desktopQuoteCopied => 'Copied with its time and link';

  @override
  String get desktopReadingBack => 'Back to the clip';

  @override
  String get desktopReadingCloseFind => 'Close the search';

  @override
  String get desktopReadingFind => 'Find in the text';

  @override
  String desktopReadingFound(int at, int count) {
    return '$at of $count';
  }

  @override
  String get desktopReadingHint =>
      'Click a sentence to hear it from there · Ctrl+F finds a word · select to copy with its time';

  @override
  String get desktopReadingNextMatch => 'Next match';

  @override
  String get desktopReadingPreviousMatch => 'Previous match';

  @override
  String get desktopReadingRoom => 'Reading room';

  @override
  String get desktopRemoveFromList => 'Remove from the list';

  @override
  String get desktopRestore => 'Restore';

  @override
  String get desktopRestoreBody =>
      'This computer\'s tags, lists and settings become what the backup holds. The server is not touched.';

  @override
  String get desktopRestoreTitle => 'Restore this backup?';

  @override
  String get desktopRestored => 'Backup restored';

  @override
  String get desktopRevealAfterDownload => 'Show in Explorer when done';

  @override
  String get desktopRevealAfterDownloadHint =>
      'When a file downloaded to this computer is done, its folder opens with the file chosen.';

  @override
  String desktopSavedIn(String folder) {
    return 'Saved in $folder';
  }

  @override
  String desktopSavedSearchDelete(String name) {
    return 'Delete the saved search “$name”? Nothing in the library changes.';
  }

  @override
  String get desktopSavedSearchName => 'Search name';

  @override
  String desktopSavingOffline(int percent) {
    return 'Saving offline · $percent%';
  }

  @override
  String desktopSavingTo(String folder) {
    return 'Saving to $folder';
  }

  @override
  String get desktopSearch => 'Search';

  @override
  String get desktopSearchHint => 'Search titles and what was said…';

  @override
  String get desktopSearchSaved => 'Saved in the sidebar';

  @override
  String get desktopSeekBar => 'Position in the clip';

  @override
  String desktopSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get desktopServerFolders => 'Same folders as on the server';

  @override
  String get desktopServerFoldersHint =>
      'For example, a clip in a folder called “Kids” on the server is saved in a folder of the same name here.';

  @override
  String get desktopServerPartMissing =>
      'The server isn\'t answering, so this is what it held last time.';

  @override
  String get desktopServerVersion => 'Server version';

  @override
  String get desktopSetupAgain => 'Set up again';

  @override
  String get desktopSetupChooseFile => 'Choose a file…';

  @override
  String get desktopSetupConnect => 'Connect';

  @override
  String get desktopSetupEnter => 'Enter the address';

  @override
  String get desktopSetupFoundNone =>
      'No MeTube server answered on these ports.';

  @override
  String get desktopSetupImport => 'Import from the phone';

  @override
  String get desktopSetupImportHint =>
      'Choose a MeTube Super backup: its server address is offered here, and its tags and lists are added.';

  @override
  String get desktopSetupLater => 'Later';

  @override
  String get desktopSetupNeedsPassword => 'Needs a password';

  @override
  String get desktopSetupNoServer => 'No server yet?';

  @override
  String get desktopSetupPorts => 'Ports';

  @override
  String get desktopSetupSearch => 'Search my network';

  @override
  String get desktopSetupSearchHint =>
      'Looks for MeTube on this computer\'s network, only when you click.';

  @override
  String desktopSetupSearching(int percent) {
    return 'Searching… $percent%';
  }

  @override
  String get desktopSetupTitle => 'Connect to your MeTube server';

  @override
  String get desktopShortcutsApp => 'App';

  @override
  String get desktopShortcutsClip => 'On a chosen clip';

  @override
  String get desktopShortcutsPlayback => 'Playing';

  @override
  String get desktopShortcutsTitle => 'Keyboard shortcuts';

  @override
  String get desktopShortcutsWindow => 'Window';

  @override
  String get desktopShortsHint =>
      '↑ ↓ or the wheel for the next short · double-click to favorite';

  @override
  String get desktopShowInFolder => 'Show in folder';

  @override
  String get desktopShowPanel => 'Show side panel';

  @override
  String get desktopStartWithWindows => 'Start with Windows';

  @override
  String get desktopStartWithWindowsHint =>
      'Opens when you sign in: in the tray when it keeps playing there, otherwise minimized.';

  @override
  String get desktopStartWithWindowsRefused =>
      'Windows did not let the app start with it.';

  @override
  String get desktopStats => 'Library statistics';

  @override
  String get desktopStatsByChannel => 'By channel';

  @override
  String get desktopStatsByMonth => 'By month added';

  @override
  String get desktopStatsBySite => 'By site';

  @override
  String get desktopStatsClips => 'Clips';

  @override
  String get desktopStatsHint =>
      'What the library holds, and what may deserve a look. Nothing is deleted from here.';

  @override
  String desktopStatsHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
      zero: 'Under an hour',
    );
    return '$_temp0';
  }

  @override
  String get desktopStatsLargest => 'The largest:';

  @override
  String get desktopStatsLength => 'Running time';

  @override
  String get desktopStatsLink => 'Statistics';

  @override
  String get desktopStatsNeverPlayed => 'Never played here';

  @override
  String get desktopStatsNewest => 'The newest:';

  @override
  String get desktopStatsOtherChannels => 'Other channels';

  @override
  String get desktopStatsRoom => 'Room taken';

  @override
  String get desktopStatsUnnamed => 'No channel named';

  @override
  String get desktopStatsWithText => 'With a transcript';

  @override
  String get desktopStatsWithoutText => 'Without a transcript';

  @override
  String get desktopStatsWorthALook => 'Worth a look';

  @override
  String get desktopSubtitleOptions => 'Subtitle options';

  @override
  String get desktopSync => 'Sync';

  @override
  String get desktopSyncCameBack =>
      'This computer was away for more than 90 days, so your other devices\' data was taken first.';

  @override
  String get desktopSyncChoose => 'Choose a folder';

  @override
  String desktopSyncComputer(String name) {
    return 'Computer $name';
  }

  @override
  String get desktopSyncFailed =>
      'The sync folder could not be read. Check that its drive is there.';

  @override
  String get desktopSyncFolder => 'Sync folder';

  @override
  String get desktopSyncForget => 'Forget this device';

  @override
  String desktopSyncForgetBody(String device) {
    return '$device will no longer be read. Its transcripts move to this computer\'s folder first, so none is lost. Use this for a device that was lost or sold.';
  }

  @override
  String desktopSyncFrom(String device, String ago) {
    return 'Last from $device: $ago';
  }

  @override
  String get desktopSyncGuide =>
      'At home: Syncthing on this computer and Syncthing‑Fork (from F-Droid) on the phone, sharing one folder; set Syncthing‑Fork to Wi‑Fi only to spare the phone\'s battery. Through a cloud: the cloud app\'s folder on this computer (OneDrive, Google Drive, Dropbox), and FolderSync on the phone with the same folder.';

  @override
  String get desktopSyncHint =>
      'Mirrors tags, favorites, lists, positions, saved searches and transcripts with your phone and other computers, through a folder a sync app keeps in step (Syncthing at home, or a cloud folder). Nothing goes to any service from here.';

  @override
  String desktopSyncLast(String ago) {
    return 'Last synced $ago';
  }

  @override
  String get desktopSyncNoOthers =>
      'No other device in this folder yet. Turn sync on in MeTube Super with the same folder.';

  @override
  String get desktopSyncNotBackup =>
      'Sync is not a backup: it mirrors a mistake as faithfully as anything else. Your dated backups stay apart from it.';

  @override
  String get desktopSyncOff => 'Off. Nothing leaves this computer.';

  @override
  String desktopSyncPhone(String name) {
    return 'Phone $name';
  }

  @override
  String desktopSyncThisComputer(String name) {
    return 'This computer: $name';
  }

  @override
  String get desktopSyncTurnOff => 'Turn off';

  @override
  String get desktopTheater => 'Theater';

  @override
  String get desktopToThisComputer => 'To this computer';

  @override
  String get desktopTranscriptFirst => 'Fetch its transcript first';

  @override
  String get desktopTranscriptHint => 'Follows playback · click a line to jump';

  @override
  String get desktopTranscriptsDeleteBody =>
      'They are removed from this computer. Only a file you exported, or another device through sync, can bring them back.';

  @override
  String get desktopTranscriptsExportHint =>
      'All of them in one file a phone can import.';

  @override
  String get desktopTranscriptsHelp =>
      'Ember keeps the words said in each YouTube clip you add, so a search (Ctrl+K) also finds what was said inside your clips, not only their titles. They stay on this computer.';

  @override
  String get desktopTranscriptsImportHint =>
      'A transcripts file from a phone. It adds what is missing here and deletes nothing.';

  @override
  String get desktopTrayOnClose =>
      'Keep playing in the tray when the window closes';

  @override
  String get desktopTrayOnCloseHint =>
      'Closing the window keeps the sound playing; quit from the icon by the clock.';

  @override
  String get desktopTrayOpen => 'Open MeTube Ember';

  @override
  String get desktopTrayQuit => 'Quit';

  @override
  String get desktopUiSize => 'Interface size';

  @override
  String desktopUiSizeHint(String bigger, String smaller, String reset) {
    return '$bigger and $smaller change it from anywhere, and $reset returns to 100%.';
  }

  @override
  String get desktopUiSizeTooLarge => 'Too large for this screen';

  @override
  String get desktopUpdateInstall => 'Install and restart';

  @override
  String get desktopUpdateRestartHint =>
      'Ember closes, installs the update and opens again. Your settings and library stay as they are.';

  @override
  String get desktopViewCompact => 'Compact';

  @override
  String get desktopViewTable => 'Table';

  @override
  String get desktopVolume => 'Volume';

  @override
  String desktopVolumeLevel(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get desktopWhatsNewAllFeatures => 'Everything Ember can do';

  @override
  String get desktopWidenSidebar => 'Expand sidebar';

  @override
  String get desktopWindowClose => 'Close';

  @override
  String get desktopWindowMaximize => 'Maximize';

  @override
  String get desktopWindowMinimize => 'Minimize';

  @override
  String get desktopWindowRestore => 'Restore down';

  @override
  String get desktopZoomChange => 'Change';

  @override
  String desktopZoomLowered(String percent) {
    return 'The interface is now $percent so it fits this screen.';
  }

  @override
  String get details => 'Details';

  @override
  String get developer => 'Developer';

  @override
  String get developerName => 'Yasir Sagheer';

  @override
  String get diagnosticLogs => 'Diagnostic logs';

  @override
  String get diagnosticLogsSubtitle =>
      'View, search, and share app logs (redacted)';

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
  String get downloadComplete => 'Download complete';

  @override
  String get downloadCompleteTitle => 'Complete';

  @override
  String get downloadDate => 'Download date';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadFailedTitle => 'Download failed';

  @override
  String get downloadNow => 'Download';

  @override
  String get downloadStarted => 'Download started…';

  @override
  String downloadStartedQuality(Object quality) {
    return 'Download started · $quality';
  }

  @override
  String get downloading => 'Downloading…';

  @override
  String get downloadingTitle => 'Downloading';

  @override
  String get editSubscription => 'Edit';

  @override
  String get emptyFilteredMessage =>
      'Clear a filter above to see your whole library.';

  @override
  String get emptyFilteredTitle => 'Nothing matches these filters';

  @override
  String get emptyLibraryMessage => 'Add a video link, or pull to refresh.';

  @override
  String get emptyOfflineMessage =>
      'Choose “Make available offline” on a clip, and it plays here without the server.';

  @override
  String get emptyOfflineTitle => 'Nothing saved on this phone yet';

  @override
  String get emptyPlaylist => 'Empty playlist';

  @override
  String get emptyPlaylistMessage => 'Add videos from the library';

  @override
  String get endpointUrl => 'Endpoint URL';

  @override
  String get enterFullscreen => 'Fullscreen';

  @override
  String get errAccessRejected =>
      'Cloudflare refused the Client ID or the Client Secret';

  @override
  String get errAuth => 'Wrong username or password';

  @override
  String get errFileGone =>
      'The file is no longer on the server. Try again to download it anew.';

  @override
  String get errNetwork => 'Cannot reach the server';

  @override
  String get errNoApi => 'The address responds but has no MeTube API';

  @override
  String get errNotMeTube => 'This address is not a MeTube server';

  @override
  String get errPlatformBlocked =>
      'The platform requires login. The server admin should refresh the cookies';

  @override
  String get errPlatformBlockedCookies =>
      'The platform requires login. Send it a cookies file from Settings → Cookies';

  @override
  String get errPollTimeout => 'The server took too long. Try again.';

  @override
  String errServer(Object message) {
    return 'Server error: $message';
  }

  @override
  String errorGeneric(Object message) {
    return 'Error: $message';
  }

  @override
  String get every30Minutes => 'Every 30 minutes';

  @override
  String everyHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count hours',
      one: 'Every hour',
    );
    return '$_temp0';
  }

  @override
  String get exitFullscreen => 'Exit fullscreen';

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
  String get externalPlayerShort => 'Another player';

  @override
  String get failed => 'Failed';

  @override
  String get failedToLoadPlaylist => 'Failed to load playlist';

  @override
  String get favorites => 'Favorites';

  @override
  String get file => 'File';

  @override
  String get fileName => 'File name';

  @override
  String get fileSize => 'File size';

  @override
  String get filterAll => 'All';

  @override
  String get filterAudio => 'Audio';

  @override
  String get filterOffline => 'Offline';

  @override
  String get filterServer => 'Server';

  @override
  String get filterVideo => 'Video';

  @override
  String get filtersOn => 'Filters on';

  @override
  String get folder => 'Folder';

  @override
  String get foldersDisabled =>
      'This server does not allow folders: CUSTOM_DIRS is off in its settings.';

  @override
  String get foldersHelp =>
      'A folder is made on the server, inside its downloads, and the clip is saved straight into it, where the network share and any other app see it. Leave it at \"No folder\" and nothing changes. For folders to work the server needs two things: CUSTOM_DIRS on, which is MeTube\'s default, and no outtmpl in YTDL_OPTIONS, which would save every file at the top whatever folder is chosen. To name files your way, use OUTPUT_TEMPLATE instead. The setup guide shows the lines.';

  @override
  String get foldersIgnored =>
      'This server saves every file at the top of the downloads, whatever folder is chosen: its YTDL_OPTIONS has an outtmpl. The setup guide says how to move it to OUTPUT_TEMPLATE.';

  @override
  String get follow => 'Follow';

  @override
  String get followChannel => 'Follow a channel';

  @override
  String get followingChannel => 'Following';

  @override
  String get format => 'Format';

  @override
  String framesPerSecond(int count) {
    return '$count fps';
  }

  @override
  String get helpAboutField => 'About this field';

  @override
  String get inPlaylists => 'In playlists';

  @override
  String get invalidUrl => 'Enter a valid link';

  @override
  String get itemOptions => 'Item options';

  @override
  String get itemUnavailable => 'No longer available';

  @override
  String get jumpToNewest => 'Go to the newest';

  @override
  String knownVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos known',
      one: '1 video known',
      zero: 'Nothing known yet',
    );
    return '$_temp0';
  }

  @override
  String get language => 'Language';

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
  String get listSeparator => ', ';

  @override
  String get listenInBackground => 'Listen in the background';

  @override
  String get localCopyRemoved => 'Local copy removed';

  @override
  String get localNetworkDesc =>
      'The app connects to the server through this URL when it can be reached.';

  @override
  String get localNetworkSection => 'Local network';

  @override
  String get localUrlLabel => 'Local server URL';

  @override
  String get lockTouch => 'Lock touch';

  @override
  String get logsEmpty => 'The log is empty';

  @override
  String get logsSanitizedNote =>
      'Links, addresses and credentials are stripped before sharing';

  @override
  String get madeOffline => 'Saved for offline';

  @override
  String get makeOffline => 'Make available offline';

  @override
  String get manageTags => 'Manage tags';

  @override
  String get mediaAccessBlockedMessage =>
      'Android will not ask again. Turn on photos and videos for this app in the system settings, then come back.';

  @override
  String get mediaAccessGrant => 'Allow';

  @override
  String get mediaAccessMessage =>
      'Your downloads are kept in the phone\'s Download folder, and Android needs your permission before the app can list them.';

  @override
  String get mediaAccessOpenSettings => 'Open settings';

  @override
  String get mediaAccessTitle => 'Allow access to your media';

  @override
  String get metubeCredit => 'The self-hosted server this app is a client for';

  @override
  String get modeAutoNext => 'Auto';

  @override
  String get modeRepeatAll => 'Repeat all';

  @override
  String get modeRepeatOne => 'Repeat one';

  @override
  String get modeStopAtEnd => 'Stop at end';

  @override
  String moreChips(int count) {
    return 'More · $count';
  }

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
  String get networkSettings => 'Networks';

  @override
  String get networkSettingsSubtitle =>
      'Auto-switch between local and external server URLs';

  @override
  String get neverChecked => 'Not checked yet';

  @override
  String get newFolder => 'New folder…';

  @override
  String get newFolderHint => 'e.g. Ai/Lessons';

  @override
  String newFromSubscriptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new from the channels you follow',
      one: '1 new from a channel you follow',
    );
    return '$_temp0';
  }

  @override
  String get newPlaylistAction => 'New playlist';

  @override
  String get newTagHint => 'New tag';

  @override
  String get next => 'Next';

  @override
  String get noBackupsYet => 'No backups yet';

  @override
  String get noDownloads => 'No downloads';

  @override
  String get noDownloadsMessage =>
      'Downloaded videos will appear here.\nShare a video link or use the Add URL button.';

  @override
  String get noExternalPlayer => 'No external player on this device';

  @override
  String get noFolder => 'No folder';

  @override
  String get noFolderHint => 'At the top of the downloads';

  @override
  String get noLogsFound => 'No logs found';

  @override
  String get noPlayableSource => 'This item has no playable source';

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
  String get noVideosFound => 'Your library is empty';

  @override
  String get noWarranty => 'Provided as is, without any warranty.';

  @override
  String get notAffiliated =>
      'Unofficial client, not affiliated with the MeTube project or yt-dlp, and not endorsed by them.';

  @override
  String notEnoughSpace(String needed, String free) {
    return 'Not enough room on the phone: needs $needed, $free free';
  }

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get notifyArrivals => 'Tell me what arrives by itself';

  @override
  String get notifyArrivalsDesc =>
      'One notice when a followed channel\'s new videos land on the server. It appears when you open the app, return to it, or refresh the library, not while the app is in the background.';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get nowPlayingCollapse => 'Fold the player panel';

  @override
  String get nowPlayingExpand => 'Show the player panel';

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
  String get onlyNewVideos =>
      'Only what appears from now on is downloaded. The videos already on the channel are left where they are.';

  @override
  String get openChannel => 'Open channel';

  @override
  String get openInExternalPlayer => 'Open in another player';

  @override
  String get openOriginalLink => 'Open original link';

  @override
  String get ownFolder => 'Save in its own folder';

  @override
  String get ownFolderNote =>
      'A folder in the server\'s downloads, which the network share and other apps see too. Only what arrives from now on goes there; what is already downloaded stays where it is.';

  @override
  String get password => 'Password';

  @override
  String get pasteUrlHint => 'Paste the link here…';

  @override
  String get pause => 'Pause';

  @override
  String get pauseSubscription => 'Pause';

  @override
  String percentValue(Object percent) {
    return '$percent%';
  }

  @override
  String get phoneCopiesSection => 'To this phone';

  @override
  String get pickAnotherFile => 'From another file…';

  @override
  String get pickAnotherFileSubtitle =>
      'A backup from another phone or an older version';

  @override
  String get pictureInPicture => 'Picture in picture';

  @override
  String get pictureInPictureHelp =>
      'When you leave the app while a video plays, it stays in a corner of the screen';

  @override
  String get pinPlaylist => 'Pin to top';

  @override
  String get platform => 'Platform';

  @override
  String platformCount(Object name, int count) {
    return '$name · $count';
  }

  @override
  String get platformOther => 'Other';

  @override
  String get play => 'Play';

  @override
  String get playAll => 'Play all';

  @override
  String get playModeLabel => 'Mode';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get playerError => 'Couldn\'t play this file';

  @override
  String get playingFromDevice => 'Playing from your device';

  @override
  String get playlist => 'Playlist';

  @override
  String get playlistCreated => 'Playlist created';

  @override
  String get playlistDeleted => 'Playlist deleted';

  @override
  String get playlistDetails => 'Playlist details';

  @override
  String get playlistEditHint =>
      'Long-press a clip to move it. Swipe it aside to remove it.';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get playlistNameHint => 'My playlist';

  @override
  String playlistOf(int current, int total) {
    return '$current / $total';
  }

  @override
  String get playlists => 'Playlists';

  @override
  String get preferences => 'Preferences';

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
  String get quality1080 => 'Up to 1080p';

  @override
  String get quality360 => 'Up to 360p';

  @override
  String get quality480 => 'Up to 480p';

  @override
  String get quality720 => 'Up to 720p';

  @override
  String get qualityAudio => 'Audio';

  @override
  String get qualityBest => 'Best';

  @override
  String get qualityHelper =>
      'Used by quick download, by whole-playlist downloads, and by \"Download now\" in the clipboard bar, and it is the preselected option in the add-link sheet. So it matters whether or not quick download is on.';

  @override
  String get qualityReading => 'Reading the file…';

  @override
  String get qualityUnavailable => 'Unavailable';

  @override
  String get qualityVideo => 'Video';

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
    return 'Number $position in line';
  }

  @override
  String get queued => 'Queued';

  @override
  String get queuedSection => 'Waiting';

  @override
  String get quickDownload => 'Quick download';

  @override
  String get quickDownloadHelp =>
      'A shared or pasted link starts downloading immediately at the default quality, with no sheet. Numeric qualities are YouTube-only: anything else downloads at best quality, and an \"audio only\" default applies everywhere.';

  @override
  String get quoteExtendHint => 'Touch another line to take it in';

  @override
  String get quoteMomentLink => 'Copy link to this moment';

  @override
  String get quotePlayFrom => 'Play from here';

  @override
  String get quoteTitle => 'Quote';

  @override
  String get readingAsMarkdownHint =>
      'Each paragraph with its time, linked to its moment';

  @override
  String get readingAsPdfHint => 'To print or keep';

  @override
  String get readingAsSrtHint => 'Line by line with its times, for any player';

  @override
  String get readingAsText => 'Text to read';

  @override
  String get readingAsTextHint => 'Paragraphs without times, to paste anywhere';

  @override
  String get readingHint => 'Tap a sentence to hear it from there';

  @override
  String readingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'About $count minutes to read',
      one: 'About a minute to read',
    );
    return '$_temp0';
  }

  @override
  String get readingRead => 'Read';

  @override
  String get readingShare => 'Share the text';

  @override
  String get readingTextSize => 'Text size';

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
  String removedFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count failed downloads',
      one: 'Removed 1 failed download',
      zero: 'Nothing to remove: they are no longer failed',
    );
    return '$_temp0';
  }

  @override
  String get removeFailed => 'Remove the failed';

  @override
  String get removeFailedBody =>
      'Only downloads that failed leave the server\'s list. Everything that finished, which is what your library shows, stays exactly as it is.';

  @override
  String removeFailedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count failed downloads?',
      one: 'Remove 1 failed download?',
    );
    return '$_temp0';
  }

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get removeLocalCopy => 'Remove local copy';

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
  String get reportBug => 'Report a bug';

  @override
  String get restoreConfirm =>
      'Restore data from the backup file? This overwrites current playlists, tags and settings.';

  @override
  String get restoreData => 'Restore';

  @override
  String get restoreFailed => 'Restore failed: the backup file is not valid';

  @override
  String get restoreSettings => 'Restore all data';

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
  String get resumeSubscription => 'Resume';

  @override
  String get retry => 'Retry';

  @override
  String get retryAll => 'Retry all';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get saveToDevice => 'Save to device';

  @override
  String get savedOnDevice => 'Saved on device';

  @override
  String get searchLogs => 'Search logs…';

  @override
  String get searchVideos => 'Search videos...';

  @override
  String get seekBackward10 => 'Back 10 seconds';

  @override
  String get seekForward10 => 'Forward 10 seconds';

  @override
  String get selectAll => 'Select all';

  @override
  String selected(int count) {
    return '$count selected';
  }

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get serverConfiguration => 'Server configuration';

  @override
  String serverFailuresLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads didn\'t finish on the server',
      one: '1 download didn\'t finish on the server',
    );
    return '$_temp0';
  }

  @override
  String get serverFailuresNote =>
      'Stopped by the server with an error, whether added from this phone, a subscription or MeTube\'s own page.';

  @override
  String get serverFailuresTitle => 'Didn\'t finish on the server';

  @override
  String serverFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files on the server',
      one: '1 file on the server',
      zero: 'No files on the server',
    );
    return '$_temp0';
  }

  @override
  String get serverHttpWarning =>
      'An http:// address outside your home network sends the password unencrypted. From outside, use an https:// address.';

  @override
  String get serverKeepsFilesBody =>
      'The history entry is removed but the file stays on disk, so the server fills up. Set DELETE_FILE_ON_TRASHCAN=true on the MeTube container.';

  @override
  String get serverKeepsFilesTitle => 'Your server is not deleting the files';

  @override
  String serverQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in the queue',
      one: '1 in the queue',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get serverSearchHint =>
      'Looks for MeTube on the Wi-Fi this phone is on, only when you tap.';

  @override
  String get serverStatusChecking => 'Checking connection…';

  @override
  String get serverStatusConnected => 'Connected to server';

  @override
  String get serverStatusOffline => 'Server unreachable';

  @override
  String get serverStatusUnconfigured => 'No server configured';

  @override
  String get serverUnreachableLocalHint =>
      'Videos saved on this phone still play.';

  @override
  String get serverUrl => 'Server URL (MeTube)';

  @override
  String get serverUrlHelpBody =>
      'The address of your MeTube server, e.g. http://192.168.1.10:8081. Use the LAN IP for plain HTTP at home, or an HTTPS address (e.g. a Cloudflare Tunnel) for access from outside.';

  @override
  String get serverUrlHelpTitle => 'About the server URL';

  @override
  String get serverUrlHint => 'http://192.168.1.5:8086 or https://domain.com';

  @override
  String get serverUrlRequired => 'Server URL is required';

  @override
  String serverVersionLabel(String version) {
    return 'MeTube $version';
  }

  @override
  String serverVersionOutdated(String latest) {
    return 'Update available: $latest';
  }

  @override
  String get serverVersionUnknown => 'Version unknown';

  @override
  String get settings => 'Settings';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsDownloads => 'Downloads';

  @override
  String get settingsGroupApp => 'App';

  @override
  String get settingsGroupData => 'Data';

  @override
  String get settingsGroupServer => 'Server';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsSaved => 'Settings saved successfully';

  @override
  String get settingsTranscripts => 'Transcripts & subtitles';

  @override
  String get settingsValueArrivals => 'tells you what arrives';

  @override
  String get settingsValueAuto => 'Automatic';

  @override
  String settingsValueChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '1 channel',
      zero: 'No channels yet',
    );
    return '$_temp0';
  }

  @override
  String get settingsValueCloudflare => 'Cloudflare Access';

  @override
  String get settingsValueCompatOff => 'Best compatibility: off';

  @override
  String get settingsValueCompatOn => 'Best compatibility: on';

  @override
  String get settingsValueExternalNow => 'external now';

  @override
  String get settingsValueLocalNow => 'local now';

  @override
  String get settingsValueManual => 'Manual';

  @override
  String get settingsValueNoPassword => 'no password';

  @override
  String get settingsValueNotSet => 'Not set up yet';

  @override
  String get settingsValueOff => 'Off';

  @override
  String get settingsValueOn => 'On';

  @override
  String get settingsValueQuick => 'quick';

  @override
  String get settingsValueSubtitlesShown => 'subtitles shown';

  @override
  String get settingsValueWifiOnly => 'Wi‑Fi only';

  @override
  String get setupServer => 'Set up the server';

  @override
  String get share => 'Share';

  @override
  String get shareGoesOn =>
      'Still preparing in the background. The share menu opens when it is ready; its progress is in Downloads.';

  @override
  String get shareLargeBody =>
      'It downloads to this phone first, then the share menu opens.';

  @override
  String shareLargeTitle(String size) {
    return 'Download $size to share?';
  }

  @override
  String get shareLogs => 'Share logs';

  @override
  String get shareMessagingLimit =>
      'WhatsApp and Telegram take up to 2 GB; for larger files use Drive or Quick Share.';

  @override
  String get shareOpening => 'Opening the share menu…';

  @override
  String get shareOpeningHint =>
      'A large file takes a few seconds to hand over.';

  @override
  String get sharePreparing => 'Preparing to share';

  @override
  String shareProgressOf(String received, String total) {
    return '$received of $total';
  }

  @override
  String get shareReady => 'Ready to share';

  @override
  String get shareSelected => 'Share selected';

  @override
  String get shortsFilter => 'Shorts';

  @override
  String showChannel(String channel) {
    return 'Everything from $channel';
  }

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
  String get sortAndFilter => 'Sort and filter';

  @override
  String get sortAndPlatform => 'Sort and platform';

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
  String get startDownload => 'Start download';

  @override
  String get status => 'Status';

  @override
  String get streamingFromServer => 'Streaming from the server';

  @override
  String subscriptionAdded(String name) {
    return 'Now following $name';
  }

  @override
  String get subscriptionName => 'Name';

  @override
  String get subscriptionPaused => 'Paused';

  @override
  String get subscriptionQuality => 'Quality for this channel';

  @override
  String get subscriptionQualityHelp =>
      'The server keeps the quality chosen when you follow, and does not let it be changed. To change it: Check now, then unfollow and follow again.\n\n\"Best\" can mean 4K in the AV1 format. Recent phones play it smoothly; if you see stuttering, your phone does not decode AV1 in hardware: choose 1080p, or turn on \"Best playback compatibility\" before following.';

  @override
  String get subscriptionQualityNote => 'Can\'t be changed after following.';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get subscriptionsEmpty => 'No channels followed yet';

  @override
  String get subscriptionsEmptyBody =>
      'Follow a channel and the server downloads each new video by itself, straight into your library. What is already on the channel stays where it is.';

  @override
  String get subscriptionsSubtitle => 'Channels the server follows for you';

  @override
  String get subscriptionsUnsupported =>
      'This MeTube is older than subscriptions';

  @override
  String get subscriptionsUnsupportedBody =>
      'Update the MeTube container to a release that has channel subscriptions, then come back here. Nothing else in the app is affected.';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitlesBackground => 'Background';

  @override
  String get subtitlesBackgroundFaint => 'Light';

  @override
  String get subtitlesBackgroundHelp =>
      'What sits behind the words. With none, each letter keeps a dark edge so it still reads over a bright picture.';

  @override
  String get subtitlesBackgroundNone => 'None';

  @override
  String get subtitlesBackgroundSolid => 'Dark';

  @override
  String get subtitlesHide => 'Hide subtitles';

  @override
  String get subtitlesInShorts => 'Subtitles in shorts';

  @override
  String get subtitlesInShortsHelp =>
      'Off unless you turn it on: many shorts already carry their words in the picture.';

  @override
  String get subtitlesLanguage => 'Subtitle language';

  @override
  String get subtitlesShow => 'Show subtitles';

  @override
  String get subtitlesShowHelp =>
      'Over the video, for clips that have a transcript. The CC button in the player does the same.';

  @override
  String get subtitlesSize => 'Text size';

  @override
  String get subtitlesSizeLarge => 'Large';

  @override
  String get subtitlesSizeMedium => 'Medium';

  @override
  String get subtitlesSizeSmall => 'Small';

  @override
  String get subtitlesStyleTip =>
      'To change the size and background while you watch, long-press CC in the player.';

  @override
  String get syncDeviceQuiet =>
      'Nothing has come from it for over two days. If it was in use, a sync app is probably paused or asleep, there or here: phones put apps they think unused to sleep.';

  @override
  String get syncPhoneCameBack =>
      'This phone was away for more than 90 days, so your other devices\' data was taken first.';

  @override
  String get syncPhoneFailed =>
      'The sync folder could not be read. Choose it again if it moved or its permission was taken back.';

  @override
  String syncPhoneForgetBody(String device) {
    return '$device will no longer be read. Its transcripts move to this phone\'s folder first, so none is lost. Use this for a device that was lost or sold.';
  }

  @override
  String get syncPhoneGuide =>
      'At home: Syncthing-Fork (from F-Droid) on this phone and Syncthing on the computer, sharing one folder; set it to Wi‑Fi only to spare the battery. Through a cloud: FolderSync with the cloud folder the computer uses.';

  @override
  String get syncPhoneHint =>
      'Mirrors tags, favorites, lists, resume positions and transcripts with MeTube Ember on your computer, through a folder a sync app keeps in step. Nothing goes to any service from here.';

  @override
  String get syncPhoneNoOthers =>
      'No other device in this folder yet. Turn sync on in MeTube Ember with the same folder.';

  @override
  String get syncPhoneOff => 'Off. Nothing leaves this phone.';

  @override
  String syncPhoneThisDevice(String name) {
    return 'This phone: $name';
  }

  @override
  String get syncTitle => 'Sync with the computer';

  @override
  String get tagActionsHint => 'Long-press a tag to rename or delete it.';

  @override
  String get tagFilterHint =>
      'Tap a tag to show its clips, again to hide them, and once more to let it go.';

  @override
  String tagLimitReached(int max) {
    return 'You can have up to $max tags. Remove one in Manage tags to add another.';
  }

  @override
  String get tags => 'Tags';

  @override
  String get tagsOpenFiltered => 'Opens the library filtered';

  @override
  String get testingConnection => 'Testing connection…';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get titleFilter => 'Only download titles containing';

  @override
  String get titleFilterHelp =>
      'The server downloads a new video from this channel only if its title contains what you write here.\n\n• A plain word is enough: Episode\n• Any of several words: Episode|Part (the | means \"or\")\n• English is case-sensitive: episode does not match Episode. Write [Ee]pisode, or both words.\n\nA video the filter skips counts as seen for good: removing the filter later downloads what comes after, not what was skipped.';

  @override
  String get titleFilterHelper =>
      'Several words: separate them with | . Leave empty for everything.';

  @override
  String get titleFilterHint => 'e.g. Episode';

  @override
  String get titleLabel => 'Title';

  @override
  String totalDuration(Object duration) {
    return 'Total: $duration';
  }

  @override
  String get transcript => 'Transcript';

  @override
  String get transcriptFind => 'Search the transcript';

  @override
  String get transcriptFull => 'Full transcript';

  @override
  String transcriptMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String get transcriptNextMatch => 'Next match';

  @override
  String get transcriptPeekHint => 'Tap for the whole text';

  @override
  String get transcriptPreviousMatch => 'Previous match';

  @override
  String transcriptSaidMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Said $count more times',
      one: 'Said once more',
    );
    return '$_temp0';
  }

  @override
  String get transcriptSwitchLanguage => 'Switch the transcript language';

  @override
  String transcriptsClips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
      zero: 'No clips yet',
    );
    return '$_temp0';
  }

  @override
  String get transcriptsDeleteAll => 'Delete all';

  @override
  String get transcriptsDeleteBody =>
      'They are removed from this phone. Only a file you exported can bring them back.';

  @override
  String get transcriptsDeleteTitle => 'Delete every transcript?';

  @override
  String transcriptsDisableBody(String size) {
    return 'The saved transcripts ($size) stay on this phone unless you delete them.';
  }

  @override
  String get transcriptsDisableTitle => 'Stop searching inside clips?';

  @override
  String get transcriptsEnable => 'Turn on';

  @override
  String get transcriptsEnableBody =>
      'Before each YouTube clip you add is downloaded, the app fetches its words from your server, in the app\'s language and in English (up to 40 seconds), and keeps them on this phone only. Clips already in your library are included only if your server saved their subtitles beside them (the setup guide shows how). You can turn this off at any time.';

  @override
  String get transcriptsExport => 'Export';

  @override
  String transcriptsExported(Object path) {
    return 'Transcripts saved to: $path';
  }

  @override
  String get transcriptsHelp =>
      'The app keeps the words said in each YouTube clip you add, so a library search also finds what was said inside your clips, not only their titles.\n\nThe words are fetched from your server just before the download and kept on this phone; the full backup does not include them. To move them to another phone, use Export here and Import there. An import adds to what is already here and deletes nothing.\n\nA server set to write subtitles beside each clip (one line in its configuration; the setup guide shows it) covers everything it downloads from then on, subscriptions and other sites included: the app reads those files on its own, in the app\'s language and in English.';

  @override
  String get transcriptsImport => 'Import';

  @override
  String get transcriptsImportInvalid => 'This file holds no transcripts.';

  @override
  String transcriptsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count transcripts',
      one: 'Imported 1 transcript',
    );
    return '$_temp0';
  }

  @override
  String get transcriptsKeep => 'Stop and keep';

  @override
  String get transcriptsSaidInside => 'Said inside clips';

  @override
  String get transcriptsSearch => 'Search inside clips';

  @override
  String get transcriptsSearchHelp =>
      'Keeps the words of every YouTube clip you add, so you can search what was said.';

  @override
  String get transcriptsStopAndDelete => 'Stop and delete';

  @override
  String get tryAgain => 'Try again';

  @override
  String get undo => 'Undo';

  @override
  String get unfollow => 'Unfollow';

  @override
  String unfollowConfirm(String name) {
    return 'Unfollow $name?';
  }

  @override
  String get unfollowConfirmBody =>
      'The server forgets which videos it has already seen. If you follow this channel again later, everything on it by then counts as seen, and what you missed is not filled in. Pausing keeps that memory.';

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
  String get username => 'Username';

  @override
  String get version => 'Version';

  @override
  String get videoAdded => 'Added to playlist';

  @override
  String get videoPlayer => 'Video player';

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
  String get waitingForWifi => 'Waiting for Wi-Fi';

  @override
  String get whatsNewGotIt => 'Got it';

  @override
  String get whatsNewReleasePage => 'Release page';

  @override
  String get whatsNewThisVersion => 'What\'s new in this version';

  @override
  String whatsNewTitle(String version) {
    return 'What\'s new in $version';
  }

  @override
  String get whatsNewUnavailable =>
      'What changed in this version is on the release page.';

  @override
  String get wifiOnly => 'Download over Wi-Fi only';

  @override
  String get wifiOnlyHelp =>
      'Stops pulling files to your device over mobile data. Tasks wait and resume automatically on Wi-Fi.';

  @override
  String get yourChannels => 'Your channels';

  @override
  String get yourChannelsHint => 'Followed in Settings or the player';

  @override
  String get yourLibrary => 'Your library';

  @override
  String get yourPlaylists => 'Your playlists';

  @override
  String get yourTags => 'Your tags';

  @override
  String get ytdlpCredit => 'The downloader MeTube runs';
}
