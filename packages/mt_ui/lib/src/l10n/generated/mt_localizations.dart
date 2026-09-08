import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'mt_localizations_ar.dart';
import 'mt_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MTLocalizations
/// returned by `MTLocalizations.of(context)`.
///
/// Applications need to include `MTLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/mt_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MTLocalizations.localizationsDelegates,
///   supportedLocales: MTLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the MTLocalizations.supportedLocales
/// property.
abstract class MTLocalizations {
  MTLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MTLocalizations of(BuildContext context) {
    return Localizations.of<MTLocalizations>(context, MTLocalizations)!;
  }

  static const LocalizationsDelegate<MTLocalizations> delegate =
      _MTLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @externalPlayerLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Local copy only — the server link is never handed to another app'**
  String get externalPlayerLocalOnly;

  /// No description provided for @externalPlayerShort.
  ///
  /// In en, this message translates to:
  /// **'Another player'**
  String get externalPlayerShort;

  /// No description provided for @noExternalPlayer.
  ///
  /// In en, this message translates to:
  /// **'No external player on this device'**
  String get noExternalPlayer;

  /// No description provided for @openInExternalPlayer.
  ///
  /// In en, this message translates to:
  /// **'Open in another player'**
  String get openInExternalPlayer;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// No description provided for @activeDownloads.
  ///
  /// In en, this message translates to:
  /// **'Active Downloads'**
  String get activeDownloads;

  /// No description provided for @activeDownloadsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 download in progress} other{{count} downloads in progress}}'**
  String activeDownloadsCount(int count);

  /// No description provided for @activeDownloadsSheet.
  ///
  /// In en, this message translates to:
  /// **'Active downloads'**
  String get activeDownloadsSheet;

  /// No description provided for @activeNow.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get activeNow;

  /// No description provided for @addEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Add endpoint'**
  String get addEndpoint;

  /// No description provided for @addLinkFab.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get addLinkFab;

  /// No description provided for @addNToServer.
  ///
  /// In en, this message translates to:
  /// **'Add {count} to server'**
  String addNToServer(int count);

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @addTo.
  ///
  /// In en, this message translates to:
  /// **'Add to…'**
  String get addTo;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get addToPlaylist;

  /// No description provided for @addUrl.
  ///
  /// In en, this message translates to:
  /// **'Add URL'**
  String get addUrl;

  /// No description provided for @addedNToServer.
  ///
  /// In en, this message translates to:
  /// **'Added {count} to server'**
  String addedNToServer(int count);

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get addedToFavorites;

  /// No description provided for @addedToPlaylistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} added to the playlist'**
  String addedToPlaylistCount(int count);

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to download queue'**
  String get addedToQueue;

  /// No description provided for @addingToServer.
  ///
  /// In en, this message translates to:
  /// **'Sending to the server…'**
  String get addingToServer;

  /// No description provided for @allDownloadsFinished.
  ///
  /// In en, this message translates to:
  /// **'All downloads finished!'**
  String get allDownloadsFinished;

  /// No description provided for @alreadyInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get alreadyInPlaylist;

  /// No description provided for @allPlatforms.
  ///
  /// In en, this message translates to:
  /// **'All platforms'**
  String get allPlatforms;

  /// No description provided for @allRightsReserved.
  ///
  /// In en, this message translates to:
  /// **'All rights reserved'**
  String get allRightsReserved;

  /// No description provided for @allTagsFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTagsFilter;

  /// No description provided for @appFeatures.
  ///
  /// In en, this message translates to:
  /// **'App Features'**
  String get appFeatures;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MeTube Super'**
  String get appTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @audioOnly.
  ///
  /// In en, this message translates to:
  /// **'Audio Only'**
  String get audioOnly;

  /// No description provided for @authHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for open servers (no password)'**
  String get authHelper;

  /// No description provided for @authentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication (Optional)'**
  String get authentication;

  /// No description provided for @autoBackgroundAudio.
  ///
  /// In en, this message translates to:
  /// **'Auto Background Audio'**
  String get autoBackgroundAudio;

  /// No description provided for @autoBackgroundAudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play audio in background when pressing back button'**
  String get autoBackgroundAudioSubtitle;

  /// No description provided for @autoBuilt.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get autoBuilt;

  /// No description provided for @autoPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Auto-play next: ON'**
  String get autoPlayNext;

  /// No description provided for @autoPlayOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-play next: OFF'**
  String get autoPlayOff;

  /// No description provided for @autoRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data restored from backup successfully!'**
  String get autoRestoreSuccess;

  /// No description provided for @autoRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry when the network returns'**
  String get autoRetry;

  /// No description provided for @autoRetryHelp.
  ///
  /// In en, this message translates to:
  /// **'Anything that failed because the network dropped is retried on its own when it returns. Server refusals are not retried — repeating them unchanged just fails again.'**
  String get autoRetryHelp;

  /// No description provided for @autoSwitchDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-switching is off — the app uses the single Server URL from Settings.'**
  String get autoSwitchDisabledHint;

  /// No description provided for @autoUrlSwitching.
  ///
  /// In en, this message translates to:
  /// **'Automatic URL switching'**
  String get autoUrlSwitching;

  /// No description provided for @autoUrlSwitchingDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect through the local URL when it is reachable, and use external connections elsewhere'**
  String get autoUrlSwitchingDesc;

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @availabilityOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline (local copy)'**
  String get availabilityOffline;

  /// No description provided for @availabilityServer.
  ///
  /// In en, this message translates to:
  /// **'Server (stream)'**
  String get availabilityServer;

  /// No description provided for @availableOfflineNow.
  ///
  /// In en, this message translates to:
  /// **'Now available offline'**
  String get availableOfflineNow;

  /// No description provided for @backgroundDownload.
  ///
  /// In en, this message translates to:
  /// **'Downloading files in background...'**
  String get backgroundDownload;

  /// No description provided for @backgroundPlay.
  ///
  /// In en, this message translates to:
  /// **'Background play'**
  String get backgroundPlay;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get backupFailed;

  /// No description provided for @backupFileSaved.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup saved'**
  String get backupFileSaved;

  /// No description provided for @backupKeyMismatch.
  ///
  /// In en, this message translates to:
  /// **'This backup is encrypted with a different key. Import the matching backup key first.'**
  String get backupKeyMismatch;

  /// No description provided for @backupNote.
  ///
  /// In en, this message translates to:
  /// **'Includes playlists, tags, the offline index, artwork links and settings. Passwords and usernames are never backed up, and media files are not included.'**
  String get backupNote;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @backupSettings.
  ///
  /// In en, this message translates to:
  /// **'Backup All Data'**
  String get backupSettings;

  /// No description provided for @backupSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Seven dated copies that refresh themselves — restore any of them, or export one to share'**
  String get backupSettingsSubtitle;

  /// No description provided for @backupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to: {path}'**
  String backupSuccess(Object path);

  /// No description provided for @batchDownloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download selected'**
  String get batchDownloadSelected;

  /// No description provided for @batchFromPlaylistNote.
  ///
  /// In en, this message translates to:
  /// **'This link came from inside a playlist'**
  String get batchFromPlaylistNote;

  /// No description provided for @batchThisVideoOnly.
  ///
  /// In en, this message translates to:
  /// **'Download this video only'**
  String get batchThisVideoOnly;

  /// No description provided for @batchLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading the playlist…'**
  String get batchLoading;

  /// No description provided for @batchNothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Select at least one item'**
  String get batchNothingSelected;

  /// No description provided for @batchSaveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save a copy on the device'**
  String get batchSaveToDevice;

  /// No description provided for @batchSelectedOf.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} selected'**
  String batchSelectedOf(int selected, int total);

  /// No description provided for @batchTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch download'**
  String get batchTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cardView.
  ///
  /// In en, this message translates to:
  /// **'Card view'**
  String get cardView;

  /// No description provided for @changeQuality.
  ///
  /// In en, this message translates to:
  /// **'Change quality'**
  String get changeQuality;

  /// No description provided for @chooseBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Choose the backup file'**
  String get chooseBackupFile;

  /// No description provided for @chooseOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get chooseOptions;

  /// No description provided for @cleaningServer.
  ///
  /// In en, this message translates to:
  /// **'Cleaning up the server...'**
  String get cleaningServer;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove all saved settings including credentials. Continue?'**
  String get clearAllConfirm;

  /// No description provided for @clearAllSettings.
  ///
  /// In en, this message translates to:
  /// **'Clear All Settings'**
  String get clearAllSettings;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogs;

  /// No description provided for @clearLogsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all diagnostic logs?'**
  String get clearLogsConfirm;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @clipboardFound.
  ///
  /// In en, this message translates to:
  /// **'A link is ready in your clipboard'**
  String get clipboardFound;

  /// No description provided for @clipboardLinkReady.
  ///
  /// In en, this message translates to:
  /// **'Paste link'**
  String get clipboardLinkReady;

  /// No description provided for @closePlayer.
  ///
  /// In en, this message translates to:
  /// **'Close player'**
  String get closePlayer;

  /// No description provided for @comingSoonPhase.
  ///
  /// In en, this message translates to:
  /// **'This screen is built in a later phase of the plan'**
  String get comingSoonPhase;

  /// No description provided for @compactView.
  ///
  /// In en, this message translates to:
  /// **'Compact view'**
  String get compactView;

  /// No description provided for @compatiblePlayback.
  ///
  /// In en, this message translates to:
  /// **'Best playback compatibility'**
  String get compatiblePlayback;

  /// No description provided for @compatiblePlaybackHelp.
  ///
  /// In en, this message translates to:
  /// **'Asks the server for H.264/AAC, which every phone decodes in hardware. Without it YouTube may deliver AV1, which many devices render as a garbled picture. Turning it off allows the highest resolution at the cost of compatibility.'**
  String get compatiblePlaybackHelp;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connected successfully — settings saved'**
  String get connectionSuccessful;

  /// No description provided for @contactDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Contact Developer'**
  String get contactDeveloper;

  /// No description provided for @continueAsAudio.
  ///
  /// In en, this message translates to:
  /// **'Continue as audio'**
  String get continueAsAudio;

  /// No description provided for @continueAsAudioBody.
  ///
  /// In en, this message translates to:
  /// **'Keep playing this as audio from the same second?'**
  String get continueAsAudioBody;

  /// No description provided for @continueAsAudioNo.
  ///
  /// In en, this message translates to:
  /// **'No, stop'**
  String get continueAsAudioNo;

  /// No description provided for @continueAsAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue in the background?'**
  String get continueAsAudioTitle;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @couldNotLoadPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this playlist. Check the URL and your connection.'**
  String get couldNotLoadPlaylist;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// No description provided for @creator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get creator;

  /// No description provided for @credentialsRequired.
  ///
  /// In en, this message translates to:
  /// **'Username and password are required to connect to the server.'**
  String get credentialsRequired;

  /// No description provided for @currentServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Current server address'**
  String get currentServerAddress;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @defaultQuality.
  ///
  /// In en, this message translates to:
  /// **'Default Video Quality'**
  String get defaultQuality;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFromServer.
  ///
  /// In en, this message translates to:
  /// **'Delete From Server'**
  String get deleteFromServer;

  /// No description provided for @deleteFromServerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this item from the server?'**
  String get deleteFromServerConfirm;

  /// No description provided for @deleteMultipleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} video(s)?\n\nThis will remove the files from your device.'**
  String deleteMultipleConfirm(int count);

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deletePlaylistConfirm(Object name);

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get deleteSelected;

  /// No description provided for @deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get deleteTag;

  /// No description provided for @deleteTagConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the tag \"{tag}\" from all items? The videos themselves are not deleted.'**
  String deleteTagConfirm(Object tag);

  /// No description provided for @deleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete Video'**
  String get deleteVideo;

  /// No description provided for @deleteVideoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?\n\nThis will remove the file from your device.'**
  String deleteVideoConfirm(Object title);

  /// No description provided for @deletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} deleted'**
  String deletedCount(Object count);

  /// No description provided for @deletedFromServer.
  ///
  /// In en, this message translates to:
  /// **'Deleted from the server'**
  String get deletedFromServer;

  /// No description provided for @deletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted: {title}'**
  String deletedTitle(Object title);

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get detailTitle;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @developerName.
  ///
  /// In en, this message translates to:
  /// **'Yasir Sagheer'**
  String get developerName;

  /// No description provided for @diagnosticLogs.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Logs'**
  String get diagnosticLogs;

  /// No description provided for @diagnosticLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View, search, and share app logs (redacted)'**
  String get diagnosticLogsSubtitle;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get disclaimer;

  /// No description provided for @disclaimerText.
  ///
  /// In en, this message translates to:
  /// **'This app is a client for MeTube server. The developer is not responsible for how users utilize this tool. Please respect copyright laws and terms of service of content platforms.'**
  String get disclaimerText;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadAndShare.
  ///
  /// In en, this message translates to:
  /// **'Download & Share'**
  String get downloadAndShare;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download Complete'**
  String get downloadComplete;

  /// No description provided for @downloadCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete!'**
  String get downloadCompleteTitle;

  /// No description provided for @downloadDate.
  ///
  /// In en, this message translates to:
  /// **'Download Date'**
  String get downloadDate;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get downloadFailed;

  /// No description provided for @downloadFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailedStatus;

  /// No description provided for @downloadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get downloadFailedTitle;

  /// No description provided for @downloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadNow;

  /// No description provided for @downloadQuality.
  ///
  /// In en, this message translates to:
  /// **'Download Quality'**
  String get downloadQuality;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started...'**
  String get downloadStarted;

  /// No description provided for @downloadStartedQuality.
  ///
  /// In en, this message translates to:
  /// **'Download started · {quality}'**
  String downloadStartedQuality(Object quality);

  /// No description provided for @downloadTracks.
  ///
  /// In en, this message translates to:
  /// **'Download {count} Tracks'**
  String downloadTracks(int count);

  /// No description provided for @downloadUrlUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Download URL not available'**
  String get downloadUrlUnavailable;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @downloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadingTitle;

  /// No description provided for @downloadsTab.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTab;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emptyLibraryMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a video link, or pull to refresh.'**
  String get emptyLibraryMessage;

  /// No description provided for @emptyPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Empty playlist'**
  String get emptyPlaylist;

  /// No description provided for @emptyPlaylistMessage.
  ///
  /// In en, this message translates to:
  /// **'Add videos from the library'**
  String get emptyPlaylistMessage;

  /// No description provided for @endpointReachable.
  ///
  /// In en, this message translates to:
  /// **'Reachable'**
  String get endpointReachable;

  /// No description provided for @endpointUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get endpointUnreachable;

  /// No description provided for @endpointUrl.
  ///
  /// In en, this message translates to:
  /// **'Endpoint URL'**
  String get endpointUrl;

  /// No description provided for @enterFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get enterFullscreen;

  /// No description provided for @enterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter URL'**
  String get enterUrl;

  /// No description provided for @enterUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Paste video URL here...'**
  String get enterUrlHint;

  /// No description provided for @enterUrlPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a video URL to download:'**
  String get enterUrlPrompt;

  /// No description provided for @errAuth.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password'**
  String get errAuth;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server'**
  String get errNetwork;

  /// No description provided for @errNoApi.
  ///
  /// In en, this message translates to:
  /// **'The address responds but has no MeTube API'**
  String get errNoApi;

  /// No description provided for @errNotMeTube.
  ///
  /// In en, this message translates to:
  /// **'This address is not a MeTube server'**
  String get errNotMeTube;

  /// No description provided for @errPlatformBlocked.
  ///
  /// In en, this message translates to:
  /// **'The platform requires login — the server admin should refresh the cookies'**
  String get errPlatformBlocked;

  /// No description provided for @errPollTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long — try again'**
  String get errPollTimeout;

  /// No description provided for @errServer.
  ///
  /// In en, this message translates to:
  /// **'Server error: {message}'**
  String errServer(Object message);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorGeneric(Object message);

  /// No description provided for @errorLogs.
  ///
  /// In en, this message translates to:
  /// **'Error Logs'**
  String get errorLogs;

  /// No description provided for @errorLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View app logs for diagnostics'**
  String get errorLogsSubtitle;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get exitFullscreen;

  /// No description provided for @exportKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required to restore on a new phone or after reinstall'**
  String get exportKeySubtitle;

  /// No description provided for @externalNetworkDesc.
  ///
  /// In en, this message translates to:
  /// **'When the local URL can\'t be reached, the app connects through the first reachable URL below, from top to bottom.'**
  String get externalNetworkDesc;

  /// No description provided for @externalNetworkSection.
  ///
  /// In en, this message translates to:
  /// **'External network'**
  String get externalNetworkSection;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @failedToLoadPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlist'**
  String get failedToLoadPlaylist;

  /// No description provided for @failedToLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get failedToLoadVideo;

  /// No description provided for @failedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Failed to add to queue'**
  String get failedToQueue;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @featureBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup and restore'**
  String get featureBackup;

  /// No description provided for @featureBilingual.
  ///
  /// In en, this message translates to:
  /// **'Arabic and English language support'**
  String get featureBilingual;

  /// No description provided for @featureDownload.
  ///
  /// In en, this message translates to:
  /// **'Download videos from YouTube and other platforms'**
  String get featureDownload;

  /// No description provided for @featurePlayer.
  ///
  /// In en, this message translates to:
  /// **'Direct download by sharing links from any app'**
  String get featurePlayer;

  /// No description provided for @featurePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Create and manage playlists'**
  String get featurePlaylists;

  /// No description provided for @featureThemes.
  ///
  /// In en, this message translates to:
  /// **'Dark and light themes'**
  String get featureThemes;

  /// No description provided for @fieldHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get fieldHelp;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get fileSize;

  /// No description provided for @fileSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String fileSizeBytes(Object value);

  /// No description provided for @fileSizeGB.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String fileSizeGB(Object value);

  /// No description provided for @fileSizeKB.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String fileSizeKB(Object value);

  /// No description provided for @fileSizeMB.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String fileSizeMB(Object value);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get filterAudio;

  /// No description provided for @filterOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get filterOffline;

  /// No description provided for @filterPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get filterPlaylists;

  /// No description provided for @filterServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get filterServer;

  /// No description provided for @filterVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get filterVideo;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @helpAboutField.
  ///
  /// In en, this message translates to:
  /// **'About this field'**
  String get helpAboutField;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorks;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import a backup'**
  String get importBackup;

  /// No description provided for @inPlaylists.
  ///
  /// In en, this message translates to:
  /// **'In playlists'**
  String get inPlaylists;

  /// No description provided for @backupsKept.
  ///
  /// In en, this message translates to:
  /// **'{count} backups kept'**
  String backupsKept(int count);

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup {when}'**
  String lastBackup(String when);

  /// No description provided for @noBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get noBackupsYet;

  /// No description provided for @restoreFromBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick one of the saved backups, or a file'**
  String get restoreFromBackupSubtitle;

  /// No description provided for @exportShare.
  ///
  /// In en, this message translates to:
  /// **'Export & share'**
  String get exportShare;

  /// No description provided for @exportShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A dated copy to send or keep elsewhere'**
  String get exportShareSubtitle;

  /// No description provided for @pickAnotherFile.
  ///
  /// In en, this message translates to:
  /// **'From another file…'**
  String get pickAnotherFile;

  /// No description provided for @pickAnotherFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A backup from another phone or an older version'**
  String get pickAnotherFileSubtitle;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid link'**
  String get invalidUrl;

  /// No description provided for @itemOptions.
  ///
  /// In en, this message translates to:
  /// **'Item options'**
  String get itemOptions;

  /// No description provided for @itemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get itemUnavailable;

  /// No description provided for @keyExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export backup key'**
  String get keyExportFailed;

  /// No description provided for @keyExportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Saved to:\n{path}\n\nUpload this file to Google Drive (or another safe place). You\'ll need it to restore your backup after Clear Data or on a new phone.'**
  String keyExportedMessage(Object path);

  /// No description provided for @keyExportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup key saved'**
  String get keyExportedTitle;

  /// No description provided for @keyImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace key'**
  String get keyImportConfirm;

  /// No description provided for @keyImportConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will replace the device\'s current encryption key.\n\nAny backup file already on disk that was encrypted with the previous key will become unreadable.\n\nContinue only if this key matches your backup file.'**
  String get keyImportConfirmMessage;

  /// No description provided for @keyImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace current key?'**
  String get keyImportConfirmTitle;

  /// No description provided for @keyImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid key file'**
  String get keyImportInvalid;

  /// No description provided for @keyImportNotFound.
  ///
  /// In en, this message translates to:
  /// **'Key file not found at Downloads/MeTube_Super/metube_super_backup_key.txt'**
  String get keyImportNotFound;

  /// No description provided for @keyImportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Encryption key restored. You can now use Restore All Data to recover your backup.'**
  String get keyImportedMessage;

  /// No description provided for @keyImportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Key imported'**
  String get keyImportedTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone\'s language'**
  String get languageSystemHint;

  /// No description provided for @latestAdditions.
  ///
  /// In en, this message translates to:
  /// **'Latest additions'**
  String get latestAdditions;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @listenInBackground.
  ///
  /// In en, this message translates to:
  /// **'Listen in the background'**
  String get listenInBackground;

  /// No description provided for @loadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get loadingVideo;

  /// No description provided for @localCopyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Local copy removed'**
  String get localCopyRemoved;

  /// No description provided for @localNetworkDesc.
  ///
  /// In en, this message translates to:
  /// **'The app connects to the server through this URL when it can be reached.'**
  String get localNetworkDesc;

  /// No description provided for @localNetworkSection.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get localNetworkSection;

  /// No description provided for @localOnlyYoutubeMessage.
  ///
  /// In en, this message translates to:
  /// **'Direct downloads support YouTube only.\nConfigure a MeTube server in Settings to download from other platforms.'**
  String get localOnlyYoutubeMessage;

  /// No description provided for @localUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Local server URL'**
  String get localUrlLabel;

  /// No description provided for @localVideos.
  ///
  /// In en, this message translates to:
  /// **'Library ({count})'**
  String localVideos(int count);

  /// No description provided for @lockTouch.
  ///
  /// In en, this message translates to:
  /// **'Lock touch'**
  String get lockTouch;

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The log is empty'**
  String get logsEmpty;

  /// No description provided for @logsSanitizedNote.
  ///
  /// In en, this message translates to:
  /// **'Links, addresses and credentials are stripped before sharing'**
  String get logsSanitizedNote;

  /// No description provided for @logsShareText.
  ///
  /// In en, this message translates to:
  /// **'MeTube Super logs (URLs/IPs/credentials redacted)'**
  String get logsShareText;

  /// No description provided for @madeOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved for offline'**
  String get madeOffline;

  /// No description provided for @madeWithLove.
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ By Yasir Sagheer'**
  String get madeWithLove;

  /// No description provided for @makeAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'Make available offline'**
  String get makeAvailableOffline;

  /// No description provided for @makeOffline.
  ///
  /// In en, this message translates to:
  /// **'Make available offline'**
  String get makeOffline;

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage tags'**
  String get manageTags;

  /// No description provided for @modeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modeAuto;

  /// No description provided for @modeAutoNext.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modeAutoNext;

  /// No description provided for @modeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get modeOff;

  /// No description provided for @modeRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get modeRepeat;

  /// No description provided for @modeRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get modeRepeatAll;

  /// No description provided for @modeRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get modeRepeatOne;

  /// No description provided for @modeStopAtEnd.
  ///
  /// In en, this message translates to:
  /// **'Stop at end'**
  String get modeStopAtEnd;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navMyDownloads.
  ///
  /// In en, this message translates to:
  /// **'My downloads'**
  String get navMyDownloads;

  /// No description provided for @navPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get navPlaylists;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs your attention'**
  String get needsAttention;

  /// No description provided for @networkBackRetrying.
  ///
  /// In en, this message translates to:
  /// **'Network is back — retrying'**
  String get networkBackRetrying;

  /// No description provided for @networkSettings.
  ///
  /// In en, this message translates to:
  /// **'Networks'**
  String get networkSettings;

  /// No description provided for @networkSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-switch between local and external server URLs'**
  String get networkSettingsSubtitle;

  /// No description provided for @newPlaylistAction.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylistAction;

  /// No description provided for @newTagHint.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get newTagHint;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noDownloads.
  ///
  /// In en, this message translates to:
  /// **'No Downloads'**
  String get noDownloads;

  /// No description provided for @noDownloadsMessage.
  ///
  /// In en, this message translates to:
  /// **'Downloaded videos will appear here.\nShare a video link or use the Add URL button.'**
  String get noDownloadsMessage;

  /// No description provided for @noLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No logs found'**
  String get noLogsFound;

  /// No description provided for @noPasswordTip.
  ///
  /// In en, this message translates to:
  /// **'No password? Leave auth fields empty for open servers!'**
  String get noPasswordTip;

  /// No description provided for @noPlayableSource.
  ///
  /// In en, this message translates to:
  /// **'This item has no playable source'**
  String get noPlayableSource;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists'**
  String get noPlaylists;

  /// No description provided for @noPlaylistsMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a playlist to organize your videos'**
  String get noPlaylistsMessage;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @noResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'No items match your search.'**
  String get noResultsMessage;

  /// No description provided for @noServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your MeTube server address in Settings to start downloading'**
  String get noServerMessage;

  /// No description provided for @noServerTitle.
  ///
  /// In en, this message translates to:
  /// **'No server yet'**
  String get noServerTitle;

  /// No description provided for @noTagsYet.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Create one below.'**
  String get noTagsYet;

  /// No description provided for @noValidUrl.
  ///
  /// In en, this message translates to:
  /// **'No valid video URL found'**
  String get noValidUrl;

  /// No description provided for @noVideosFound.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get noVideosFound;

  /// No description provided for @noVideosHint.
  ///
  /// In en, this message translates to:
  /// **'Share a video URL from any app, or tap the + button to add one'**
  String get noVideosHint;

  /// No description provided for @nonYoutubeQualityNote.
  ///
  /// In en, this message translates to:
  /// **'Non-YouTube platforms only support best quality or audio'**
  String get nonYoutubeQualityNote;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @offlineSmartList.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineSmartList;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @onServerPhase.
  ///
  /// In en, this message translates to:
  /// **'On the server'**
  String get onServerPhase;

  /// No description provided for @onServerProgress.
  ///
  /// In en, this message translates to:
  /// **'On the server · {percent}%'**
  String onServerProgress(Object percent);

  /// No description provided for @openGithub.
  ///
  /// In en, this message translates to:
  /// **'Open MeTube on GitHub'**
  String get openGithub;

  /// No description provided for @openOriginalLink.
  ///
  /// In en, this message translates to:
  /// **'Open Original Link'**
  String get openOriginalLink;

  /// No description provided for @originalUrl.
  ///
  /// In en, this message translates to:
  /// **'Original URL'**
  String get originalUrl;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get pasteFromClipboard;

  /// No description provided for @pasteUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the link here…'**
  String get pasteUrlHint;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @pinPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get pinPlaylist;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @platformCount.
  ///
  /// In en, this message translates to:
  /// **'{name} · {count}'**
  String platformCount(Object name, int count);

  /// No description provided for @platformFilter.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platformFilter;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @playAllFavorites.
  ///
  /// In en, this message translates to:
  /// **'Play all favorites'**
  String get playAllFavorites;

  /// No description provided for @playModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get playModeLabel;

  /// No description provided for @playbackError.
  ///
  /// In en, this message translates to:
  /// **'Playback Error'**
  String get playbackError;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @playerError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play this file'**
  String get playerError;

  /// No description provided for @playerLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get playerLoading;

  /// No description provided for @playingFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Playing from your device'**
  String get playingFromDevice;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @playlistCreated.
  ///
  /// In en, this message translates to:
  /// **'Playlist created'**
  String get playlistCreated;

  /// No description provided for @playlistDeleted.
  ///
  /// In en, this message translates to:
  /// **'Playlist deleted'**
  String get playlistDeleted;

  /// No description provided for @playlistDetails.
  ///
  /// In en, this message translates to:
  /// **'Playlist Details'**
  String get playlistDetails;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'My Playlist'**
  String get playlistNameHint;

  /// No description provided for @playlistOf.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String playlistOf(int current, int total);

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @playlistsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} playlists'**
  String playlistsCount(int count);

  /// No description provided for @pleaseEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL'**
  String get pleaseEnterUrl;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @preparingDownload.
  ///
  /// In en, this message translates to:
  /// **'Preparing download...'**
  String get preparingDownload;

  /// No description provided for @preparingShare.
  ///
  /// In en, this message translates to:
  /// **'Preparing the file for sharing…'**
  String get preparingShare;

  /// No description provided for @preparingToShare.
  ///
  /// In en, this message translates to:
  /// **'Preparing to share… {percent}%'**
  String preparingToShare(String percent);

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @pullingToDevice.
  ///
  /// In en, this message translates to:
  /// **'Saving to device…'**
  String get pullingToDevice;

  /// No description provided for @pullingToDeviceProgress.
  ///
  /// In en, this message translates to:
  /// **'Saving to device · {percent}%'**
  String pullingToDeviceProgress(Object percent);

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @quality1080.
  ///
  /// In en, this message translates to:
  /// **'1080p'**
  String get quality1080;

  /// No description provided for @quality480.
  ///
  /// In en, this message translates to:
  /// **'480p'**
  String get quality480;

  /// No description provided for @quality720.
  ///
  /// In en, this message translates to:
  /// **'720p'**
  String get quality720;

  /// No description provided for @qualityAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get qualityAudio;

  /// No description provided for @qualityBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get qualityBest;

  /// No description provided for @qualityHelper.
  ///
  /// In en, this message translates to:
  /// **'Used by quick download, by whole-playlist downloads, and by \"Download now\" in the clipboard bar — and it is the preselected option in the add-link sheet. So it matters whether or not quick download is on.'**
  String get qualityHelper;

  /// No description provided for @queueItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String queueItemsCount(int count);

  /// No description provided for @queueLabel.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueLabel;

  /// No description provided for @queuePosition.
  ///
  /// In en, this message translates to:
  /// **'Queue position: {position}'**
  String queuePosition(int position);

  /// No description provided for @queued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get queued;

  /// No description provided for @queuedSection.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get queuedSection;

  /// No description provided for @quickDownload.
  ///
  /// In en, this message translates to:
  /// **'Quick download'**
  String get quickDownload;

  /// No description provided for @quickDownloadHelp.
  ///
  /// In en, this message translates to:
  /// **'A shared or pasted link starts downloading immediately at the default quality, with no sheet. Numeric qualities are YouTube-only — anything else downloads at best quality, and an \"audio only\" default applies everywhere.'**
  String get quickDownloadHelp;

  /// No description provided for @readyToShare.
  ///
  /// In en, this message translates to:
  /// **'Ready to share!'**
  String get readyToShare;

  /// No description provided for @reelsEndBack.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get reelsEndBack;

  /// No description provided for @reelsEndContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue the rest of the list'**
  String get reelsEndContinue;

  /// No description provided for @reelsEndReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay from the start'**
  String get reelsEndReplay;

  /// No description provided for @reelsEndTitle.
  ///
  /// In en, this message translates to:
  /// **'End of the shorts lane'**
  String get reelsEndTitle;

  /// No description provided for @reelsSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe up for the next short'**
  String get reelsSwipeHint;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Remove {count} unavailable'**
  String removeUnavailable(int count);

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylist;

  /// No description provided for @removeLocalCopy.
  ///
  /// In en, this message translates to:
  /// **'Remove local copy'**
  String get removeLocalCopy;

  /// No description provided for @removeOfflineConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the local copy from this device?\nThe video stays on the server and can be streamed again.'**
  String get removeOfflineConfirm;

  /// No description provided for @removeOfflineCopy.
  ///
  /// In en, this message translates to:
  /// **'Remove offline copy'**
  String get removeOfflineCopy;

  /// No description provided for @removeOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Offline Copy'**
  String get removeOfflineTitle;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get removedFromFavorites;

  /// No description provided for @removedFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Removed from the playlist'**
  String get removedFromPlaylist;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameTag.
  ///
  /// In en, this message translates to:
  /// **'Rename tag'**
  String get renameTag;

  /// No description provided for @reorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get reorderHint;

  /// No description provided for @reportBug.
  ///
  /// In en, this message translates to:
  /// **'Report a Bug'**
  String get reportBug;

  /// No description provided for @restoreCancelled.
  ///
  /// In en, this message translates to:
  /// **'Backup file not found in Downloads folder'**
  String get restoreCancelled;

  /// No description provided for @restoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore data from the backup file? This overwrites current playlists, tags and settings.'**
  String get restoreConfirm;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreData;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed — invalid backup file'**
  String get restoreFailed;

  /// No description provided for @restoreNotFound.
  ///
  /// In en, this message translates to:
  /// **'No backup file found in Downloads/MeTube_Super'**
  String get restoreNotFound;

  /// No description provided for @restoreSettings.
  ///
  /// In en, this message translates to:
  /// **'Restore All Data'**
  String get restoreSettings;

  /// No description provided for @restoreSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Downloads/metube_lite_backup.json'**
  String get restoreSettingsSubtitle;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data restored successfully'**
  String get restoreSuccess;

  /// No description provided for @resultsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String resultsFound(int count);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @retryingAttempt.
  ///
  /// In en, this message translates to:
  /// **'Retry {attempt}/{max}…'**
  String retryingAttempt(int attempt, int max);

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @saveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get saveToDevice;

  /// No description provided for @savedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on device'**
  String get savedOnDevice;

  /// No description provided for @savedPartial.
  ///
  /// In en, this message translates to:
  /// **'Saved (Server delete failed)'**
  String get savedPartial;

  /// No description provided for @savedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get savedSuccess;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to Downloads/MeTube_Lite'**
  String get savedTo;

  /// No description provided for @savedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Saved to Downloads/MeTube_Super'**
  String get savedToDownloads;

  /// No description provided for @scanningVideos.
  ///
  /// In en, this message translates to:
  /// **'Scanning videos...'**
  String get scanningVideos;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchHint;

  /// No description provided for @searchLogs.
  ///
  /// In en, this message translates to:
  /// **'Search logs…'**
  String get searchLogs;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Results: {found} of {total}'**
  String searchResults(int found, int total);

  /// No description provided for @searchVideos.
  ///
  /// In en, this message translates to:
  /// **'Search videos...'**
  String get searchVideos;

  /// No description provided for @seekBackward10.
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get seekBackward10;

  /// No description provided for @seekForward10.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get seekForward10;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selected(int count);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @serverConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Server Configuration'**
  String get serverConfiguration;

  /// No description provided for @serverDownload.
  ///
  /// In en, this message translates to:
  /// **'Server Download'**
  String get serverDownload;

  /// No description provided for @serverDownloadDesc.
  ///
  /// In en, this message translates to:
  /// **'Videos will be sent to your MeTube Super/TrueNAS server'**
  String get serverDownloadDesc;

  /// No description provided for @serverStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking connection…'**
  String get serverStatusChecking;

  /// No description provided for @serverStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to server'**
  String get serverStatusConnected;

  /// No description provided for @serverStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get serverStatusOffline;

  /// No description provided for @serverStatusUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'No server configured'**
  String get serverStatusUnconfigured;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL (MeTube)'**
  String get serverUrl;

  /// No description provided for @serverUrlHelpBody.
  ///
  /// In en, this message translates to:
  /// **'The address of your MeTube server, e.g. http://192.168.1.10:8081. Use the LAN IP for plain HTTP at home, or an HTTPS address (e.g. a Cloudflare Tunnel) for access from outside.'**
  String get serverUrlHelpBody;

  /// No description provided for @serverUrlHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'About the Server URL'**
  String get serverUrlHelpTitle;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'http://192.168.1.5:8086 or https://domain.com'**
  String get serverUrlHint;

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL (MeTube Super)'**
  String get serverUrlLabel;

  /// No description provided for @serverUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Server URL is required'**
  String get serverUrlRequired;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsCleared.
  ///
  /// In en, this message translates to:
  /// **'Settings cleared'**
  String get settingsCleared;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settingsSaved;

  /// No description provided for @setupServer.
  ///
  /// In en, this message translates to:
  /// **'Set up the server'**
  String get setupServer;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share: {message}'**
  String shareFailed(Object message);

  /// No description provided for @shareKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Share key file'**
  String get shareKeyFile;

  /// No description provided for @shareLogs.
  ///
  /// In en, this message translates to:
  /// **'Share Logs'**
  String get shareLogs;

  /// No description provided for @shareRedacted.
  ///
  /// In en, this message translates to:
  /// **'Share (redacted)'**
  String get shareRedacted;

  /// No description provided for @shareSelected.
  ///
  /// In en, this message translates to:
  /// **'Share Selected'**
  String get shareSelected;

  /// No description provided for @shareVia.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareVia;

  /// No description provided for @shortsFilter.
  ///
  /// In en, this message translates to:
  /// **'Shorts'**
  String get shortsFilter;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @signInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get signInRequired;

  /// No description provided for @signInRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the saved credentials. Update the username and password in settings.'**
  String get signInRequiredHint;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @smartPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Smart playlists'**
  String get smartPlaylists;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get sortLargest;

  /// No description provided for @sortNameAZ.
  ///
  /// In en, this message translates to:
  /// **'Name A–Z'**
  String get sortNameAZ;

  /// No description provided for @sortNameZA.
  ///
  /// In en, this message translates to:
  /// **'Name Z–A'**
  String get sortNameZA;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get sortOldest;

  /// No description provided for @sortSmallest.
  ///
  /// In en, this message translates to:
  /// **'Smallest'**
  String get sortSmallest;

  /// No description provided for @sortedByLastPlayed.
  ///
  /// In en, this message translates to:
  /// **'By last played'**
  String get sortedByLastPlayed;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @speedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get speedNormal;

  /// No description provided for @startDownload.
  ///
  /// In en, this message translates to:
  /// **'Start download'**
  String get startDownload;

  /// No description provided for @startingDownload.
  ///
  /// In en, this message translates to:
  /// **'Starting download via server...'**
  String get startingDownload;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get statusDownloading;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @statusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get statusQueued;

  /// No description provided for @statusQueuing.
  ///
  /// In en, this message translates to:
  /// **'Adding to queue...'**
  String get statusQueuing;

  /// No description provided for @statusServerDownloading.
  ///
  /// In en, this message translates to:
  /// **'Server downloading...'**
  String get statusServerDownloading;

  /// No description provided for @statusStream.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get statusStream;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get statusWaiting;

  /// No description provided for @streamUrlUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stream URL not available'**
  String get streamUrlUnavailable;

  /// No description provided for @streamingFromServer.
  ///
  /// In en, this message translates to:
  /// **'Streaming from the server'**
  String get streamingFromServer;

  /// No description provided for @supportedPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Supported: YouTube, Twitter/X, Instagram, TikTok, Facebook, Vimeo & more'**
  String get supportedPlatforms;

  /// No description provided for @tagActionsHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a tag to rename or delete it.'**
  String get tagActionsHint;

  /// No description provided for @tagAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get tagAudio;

  /// No description provided for @tagVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get tagVideo;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @tagsOpenFiltered.
  ///
  /// In en, this message translates to:
  /// **'Opens the library filtered'**
  String get tagsOpenFiltered;

  /// No description provided for @tapToCopy.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy'**
  String get tapToCopy;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing connection…'**
  String get testingConnection;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get themeDarkMode;

  /// No description provided for @themeFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system settings'**
  String get themeFollowSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get themeLightMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @totalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total: {duration}'**
  String totalDuration(Object duration);

  /// No description provided for @tracksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String tracksCount(int count);

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @unlockTouch.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockTouch;

  /// No description provided for @unpinPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinPlaylist;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get upNext;

  /// No description provided for @upNextIn.
  ///
  /// In en, this message translates to:
  /// **'Up next in «{name}»'**
  String upNextIn(String name);

  /// No description provided for @updateCredentials.
  ///
  /// In en, this message translates to:
  /// **'Update credentials'**
  String get updateCredentials;

  /// No description provided for @urlMustStartWith.
  ///
  /// In en, this message translates to:
  /// **'URL must start with http:// or https://'**
  String get urlMustStartWith;

  /// No description provided for @urlRequiredField.
  ///
  /// In en, this message translates to:
  /// **'Enter a URL'**
  String get urlRequiredField;

  /// No description provided for @useCurrentConnection.
  ///
  /// In en, this message translates to:
  /// **'Use current connection'**
  String get useCurrentConnection;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @videoAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to playlist'**
  String get videoAdded;

  /// No description provided for @videoDetails.
  ///
  /// In en, this message translates to:
  /// **'Video details'**
  String get videoDetails;

  /// No description provided for @videoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoLabel;

  /// No description provided for @videoPlayer.
  ///
  /// In en, this message translates to:
  /// **'Video Player'**
  String get videoPlayer;

  /// No description provided for @videoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from playlist'**
  String get videoRemoved;

  /// No description provided for @videosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String videosCount(int count);

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @viewAllInPlaylists.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAllInPlaylists;

  /// No description provided for @viewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get viewGrid;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewMode.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewMode;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for server...'**
  String get waiting;

  /// No description provided for @waitingForWifi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi'**
  String get waitingForWifi;

  /// No description provided for @wifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Download over Wi-Fi only'**
  String get wifiOnly;

  /// No description provided for @wifiOnlyHelp.
  ///
  /// In en, this message translates to:
  /// **'Stops pulling files to your device over mobile data. Tasks wait and resume automatically on Wi-Fi.'**
  String get wifiOnlyHelp;

  /// No description provided for @yourPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Your playlists'**
  String get yourPlaylists;

  /// No description provided for @yourTags.
  ///
  /// In en, this message translates to:
  /// **'Your tags'**
  String get yourTags;

  /// No description provided for @youtubeDownloadStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting YouTube download...'**
  String get youtubeDownloadStarting;

  /// No description provided for @aboutDescriptionLite.
  ///
  /// In en, this message translates to:
  /// **'A light, fast app that downloads videos from many platforms through your MeTube server, pulls them to your device and cleans the server afterwards — with a built-in player and playlists.'**
  String get aboutDescriptionLite;

  /// No description provided for @aboutDescriptionSuper.
  ///
  /// In en, this message translates to:
  /// **'The server owner\'s edition: one library across server and device, streaming, tags, offline availability, batch downloads and server address switching.'**
  String get aboutDescriptionSuper;
}

class _MTLocalizationsDelegate extends LocalizationsDelegate<MTLocalizations> {
  const _MTLocalizationsDelegate();

  @override
  Future<MTLocalizations> load(Locale locale) {
    return SynchronousFuture<MTLocalizations>(lookupMTLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_MTLocalizationsDelegate old) => false;
}

MTLocalizations lookupMTLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return MTLocalizationsAr();
    case 'en':
      return MTLocalizationsEn();
  }

  throw FlutterError(
    'MTLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
