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

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About the app'**
  String get aboutApp;

  /// No description provided for @aboutDescriptionLite.
  ///
  /// In en, this message translates to:
  /// **'A light, fast app that downloads videos from many platforms through your MeTube server, pulls them to your device and cleans the server afterwards. It has its own player and playlists.'**
  String get aboutDescriptionLite;

  /// No description provided for @aboutDescriptionSuper.
  ///
  /// In en, this message translates to:
  /// **'The server owner\'s edition: one library across server and device, streaming, tags, offline availability, batch downloads and server address switching.'**
  String get aboutDescriptionSuper;

  /// No description provided for @activeDownloads.
  ///
  /// In en, this message translates to:
  /// **'Active downloads'**
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

  /// No description provided for @addTo.
  ///
  /// In en, this message translates to:
  /// **'Add to…'**
  String get addTo;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
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

  /// No description provided for @addingToServer.
  ///
  /// In en, this message translates to:
  /// **'Sending to the server…'**
  String get addingToServer;

  /// No description provided for @allDownloadsFinished.
  ///
  /// In en, this message translates to:
  /// **'All downloads finished.'**
  String get allDownloadsFinished;

  /// No description provided for @allFolders.
  ///
  /// In en, this message translates to:
  /// **'All folders'**
  String get allFolders;

  /// No description provided for @allPlatforms.
  ///
  /// In en, this message translates to:
  /// **'All platforms'**
  String get allPlatforms;

  /// No description provided for @alreadyInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get alreadyInPlaylist;

  /// No description provided for @alreadySubscribed.
  ///
  /// In en, this message translates to:
  /// **'This channel is already followed'**
  String get alreadySubscribed;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MeTube Super'**
  String get appTitle;

  /// No description provided for @appearanceAndLanguage.
  ///
  /// In en, this message translates to:
  /// **'Appearance & language'**
  String get appearanceAndLanguage;

  /// No description provided for @audioChannels.
  ///
  /// In en, this message translates to:
  /// **'{count} channels'**
  String audioChannels(int count);

  /// No description provided for @audioMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get audioMono;

  /// No description provided for @audioOnly.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get audioOnly;

  /// No description provided for @audioStereo.
  ///
  /// In en, this message translates to:
  /// **'Stereo'**
  String get audioStereo;

  /// No description provided for @authHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for open servers (no password)'**
  String get authHelper;

  /// No description provided for @authentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication (optional)'**
  String get authentication;

  /// No description provided for @autoBuilt.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get autoBuilt;

  /// No description provided for @autoCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check automatically'**
  String get autoCheckUpdates;

  /// No description provided for @autoCheckUpdatesHelp.
  ///
  /// In en, this message translates to:
  /// **'Looks for a new version in the background about twice a day.'**
  String get autoCheckUpdatesHelp;

  /// No description provided for @autoRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data restored from the backup.'**
  String get autoRestoreSuccess;

  /// No description provided for @autoRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry when the network returns'**
  String get autoRetry;

  /// No description provided for @autoRetryHelp.
  ///
  /// In en, this message translates to:
  /// **'Anything that failed because the network dropped is retried on its own when it returns. Server refusals are not retried: repeating them unchanged just fails again.'**
  String get autoRetryHelp;

  /// No description provided for @autoSwitchDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-switching is off, so the app uses the single Server URL from Settings.'**
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

  /// No description provided for @backupNote.
  ///
  /// In en, this message translates to:
  /// **'Includes playlists, tags, the offline index, artwork links and settings. Passwords and usernames are never backed up, and media files are not included.'**
  String get backupNote;

  /// No description provided for @backupSettings.
  ///
  /// In en, this message translates to:
  /// **'Back up all data'**
  String get backupSettings;

  /// No description provided for @backupSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Seven dated copies that refresh themselves. Restore any of them, or export one to share'**
  String get backupSettingsSubtitle;

  /// No description provided for @backupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to: {path}'**
  String backupSuccess(Object path);

  /// No description provided for @backupsKept.
  ///
  /// In en, this message translates to:
  /// **'{count} backups kept'**
  String backupsKept(int count);

  /// No description provided for @batchDownloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download selected'**
  String get batchDownloadSelected;

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

  /// No description provided for @batchThisVideoOnly.
  ///
  /// In en, this message translates to:
  /// **'Download this video only'**
  String get batchThisVideoOnly;

  /// No description provided for @batchTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch download'**
  String get batchTitle;

  /// No description provided for @bitrateKbps.
  ///
  /// In en, this message translates to:
  /// **'{value} kb/s'**
  String bitrateKbps(String value);

  /// No description provided for @bitrateMbps.
  ///
  /// In en, this message translates to:
  /// **'{value} Mb/s'**
  String bitrateMbps(String value);

  /// No description provided for @builtWith.
  ///
  /// In en, this message translates to:
  /// **'Built with'**
  String get builtWith;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancelSaveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Stop saving to the phone'**
  String get cancelSaveToDevice;

  /// No description provided for @changeQuality.
  ///
  /// In en, this message translates to:
  /// **'Change quality'**
  String get changeQuality;

  /// No description provided for @channelNameFolder.
  ///
  /// In en, this message translates to:
  /// **'Named after the channel'**
  String get channelNameFolder;

  /// No description provided for @channelUrl.
  ///
  /// In en, this message translates to:
  /// **'Channel or playlist link'**
  String get channelUrl;

  /// No description provided for @channelUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://www.youtube.com/@name'**
  String get channelUrlHint;

  /// No description provided for @chapterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chapter} other{{count} chapters}}'**
  String chapterCount(int count);

  /// No description provided for @chapterNumber.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterNumber(int number);

  /// No description provided for @chaptersFold.
  ///
  /// In en, this message translates to:
  /// **'Hide chapters'**
  String get chaptersFold;

  /// No description provided for @chaptersFromTranscript.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chapter from the transcript} other{{count} chapters from the transcript}}'**
  String chaptersFromTranscript(int count);

  /// No description provided for @chaptersShowAll.
  ///
  /// In en, this message translates to:
  /// **'View all chapters'**
  String get chaptersShowAll;

  /// No description provided for @chaptersUnfold.
  ///
  /// In en, this message translates to:
  /// **'Show chapters'**
  String get chaptersUnfold;

  /// No description provided for @checkEvery.
  ///
  /// In en, this message translates to:
  /// **'How often to look'**
  String get checkEvery;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get checkNow;

  /// No description provided for @checkQueued.
  ///
  /// In en, this message translates to:
  /// **'Checking now. Anything new appears in the library.'**
  String get checkQueued;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get chooseFolder;

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

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get clearLogs;

  /// No description provided for @clearLogsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all diagnostic logs?'**
  String get clearLogsConfirm;

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

  /// No description provided for @cloudflareAccess.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare Access (optional)'**
  String get cloudflareAccess;

  /// No description provided for @cloudflareAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'Only for a server behind Cloudflare Access. Create a service token in Cloudflare Zero Trust, allow it with a Service Auth policy on this server\'s address, and paste its two values here. They are sent to https addresses only.'**
  String get cloudflareAccessHelp;

  /// No description provided for @cloudflareBothRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter both the Client ID and the Client Secret, or leave both empty'**
  String get cloudflareBothRequired;

  /// No description provided for @cloudflareClientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get cloudflareClientId;

  /// No description provided for @cloudflareClientSecret.
  ///
  /// In en, this message translates to:
  /// **'Client Secret'**
  String get cloudflareClientSecret;

  /// No description provided for @cloudflareHideSecret.
  ///
  /// In en, this message translates to:
  /// **'Hide the secret'**
  String get cloudflareHideSecret;

  /// No description provided for @cloudflareShowSecret.
  ///
  /// In en, this message translates to:
  /// **'Show the secret'**
  String get cloudflareShowSecret;

  /// No description provided for @cloudflareTokenSaved.
  ///
  /// In en, this message translates to:
  /// **'Service token saved'**
  String get cloudflareTokenSaved;

  /// No description provided for @columnAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get columnAdded;

  /// No description provided for @columnLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get columnLength;

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

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connected. Settings saved.'**
  String get connectionSuccessful;

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

  /// No description provided for @cookies.
  ///
  /// In en, this message translates to:
  /// **'Cookies'**
  String get cookies;

  /// No description provided for @cookiesAbsent.
  ///
  /// In en, this message translates to:
  /// **'The server has no cookies'**
  String get cookiesAbsent;

  /// No description provided for @cookiesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the cookies'**
  String get cookiesDelete;

  /// No description provided for @cookiesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The server stops using them, and the platforms that needed a login will refuse again.'**
  String get cookiesDeleteBody;

  /// No description provided for @cookiesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Cookies deleted from the server'**
  String get cookiesDeleted;

  /// No description provided for @cookiesHelp.
  ///
  /// In en, this message translates to:
  /// **'In your browser, use an extension that exports cookies in the Netscape format (one file per platform) and pick the files here. The server then uses them for every download, and yt-dlp decides when it needs them. Cookies expire, so a download that starts failing again usually means a fresh export is due.'**
  String get cookiesHelp;

  /// No description provided for @cookiesNotNetscape.
  ///
  /// In en, this message translates to:
  /// **'None of these files holds cookies in the Netscape format'**
  String get cookiesNotNetscape;

  /// No description provided for @cookiesPresent.
  ///
  /// In en, this message translates to:
  /// **'The server has cookies'**
  String get cookiesPresent;

  /// No description provided for @cookiesPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The file is sent straight to your server and never stored on this phone. It is your accounts\' sign-in material, so only ever upload it to a server you own.'**
  String get cookiesPrivacy;

  /// No description provided for @cookiesReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace the cookies files'**
  String get cookiesReplace;

  /// No description provided for @cookiesReplaceNote.
  ///
  /// In en, this message translates to:
  /// **'Each upload replaces the server\'s whole cookies file. To keep several platforms, pick all their files together every time, the ones you sent before too. To pick more than one, long-press the first file.'**
  String get cookiesReplaceNote;

  /// No description provided for @cookiesSentFor.
  ///
  /// In en, this message translates to:
  /// **'Cookies sent for: {sites}'**
  String cookiesSentFor(String sites);

  /// No description provided for @cookiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For the platforms that will not download without a login'**
  String get cookiesSubtitle;

  /// No description provided for @cookiesTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is larger than 1 MB, which is more than the server accepts.'**
  String get cookiesTooLarge;

  /// No description provided for @cookiesUnknown.
  ///
  /// In en, this message translates to:
  /// **'This MeTube cannot say whether it has cookies'**
  String get cookiesUnknown;

  /// No description provided for @cookiesUpload.
  ///
  /// In en, this message translates to:
  /// **'Choose cookies files'**
  String get cookiesUpload;

  /// No description provided for @cookiesUploaded.
  ///
  /// In en, this message translates to:
  /// **'Cookies sent to the server'**
  String get cookiesUploaded;

  /// No description provided for @cookiesWhat.
  ///
  /// In en, this message translates to:
  /// **'Some platforms refuse to hand a video over unless the request looks like a signed-in browser. A cookies file exported from your browser gives the server that.'**
  String get cookiesWhat;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copyingToPhone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clip to this phone} other{{count} clips to this phone}}'**
  String copyingToPhone(int count);

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Yasir Sagheer'**
  String get copyright;

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
  /// **'Create playlist'**
  String get createPlaylist;

  /// No description provided for @creator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get creator;

  /// No description provided for @defaultQuality.
  ///
  /// In en, this message translates to:
  /// **'Default video quality'**
  String get defaultQuality;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFromServer.
  ///
  /// In en, this message translates to:
  /// **'Delete from server'**
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
  /// **'Delete selected'**
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
  /// **'Delete video'**
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
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @desktopAddLinks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to add} =1{Add 1 link} other{Add {count} links}}'**
  String desktopAddLinks(int count);

  /// No description provided for @desktopAddressAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get desktopAddressAdd;

  /// No description provided for @desktopAddressInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get desktopAddressInUse;

  /// No description provided for @desktopAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not an address, or already in the list'**
  String get desktopAddressInvalid;

  /// No description provided for @desktopAddressNew.
  ///
  /// In en, this message translates to:
  /// **'New address, e.g. https://metube.example.com'**
  String get desktopAddressNew;

  /// No description provided for @desktopAddressStatusNotMeTube.
  ///
  /// In en, this message translates to:
  /// **'Not a MeTube server'**
  String get desktopAddressStatusNotMeTube;

  /// No description provided for @desktopAddressStatusOk.
  ///
  /// In en, this message translates to:
  /// **'Answers'**
  String get desktopAddressStatusOk;

  /// No description provided for @desktopAddressStatusRefused.
  ///
  /// In en, this message translates to:
  /// **'Refuses the password'**
  String get desktopAddressStatusRefused;

  /// No description provided for @desktopAddressStatusUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Not reachable'**
  String get desktopAddressStatusUnreachable;

  /// No description provided for @desktopAddressTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get desktopAddressTest;

  /// No description provided for @desktopAddressUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get desktopAddressUse;

  /// No description provided for @desktopAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get desktopAddresses;

  /// No description provided for @desktopAddressesHint.
  ///
  /// In en, this message translates to:
  /// **'The app uses the address you choose and never switches by itself.'**
  String get desktopAddressesHint;

  /// No description provided for @desktopAskEachTime.
  ///
  /// In en, this message translates to:
  /// **'Ask me every time'**
  String get desktopAskEachTime;

  /// No description provided for @desktopAskEachTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Windows asks for a folder at each download.'**
  String get desktopAskEachTimeHint;

  /// No description provided for @desktopBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get desktopBack;

  /// No description provided for @desktopBackUpNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get desktopBackUpNow;

  /// No description provided for @desktopBackupHint.
  ///
  /// In en, this message translates to:
  /// **'This computer keeps its last seven backups, at least an hour apart, in its own folder.'**
  String get desktopBackupHint;

  /// No description provided for @desktopBackupsNone.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get desktopBackupsNone;

  /// No description provided for @desktopBrowserButton.
  ///
  /// In en, this message translates to:
  /// **'“To Ember” button in the browser'**
  String get desktopBrowserButton;

  /// No description provided for @desktopBrowserButtonCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied. Make a new bookmark and paste it as its address (URL).'**
  String get desktopBrowserButtonCopied;

  /// No description provided for @desktopBrowserButtonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy the code'**
  String get desktopBrowserButtonCopy;

  /// No description provided for @desktopBrowserButtonFailed.
  ///
  /// In en, this message translates to:
  /// **'The page could not be opened; copy the code instead.'**
  String get desktopBrowserButtonFailed;

  /// No description provided for @desktopBrowserButtonHint.
  ///
  /// In en, this message translates to:
  /// **'A button on your bookmarks bar: one click on any video\'s page opens the add dialog here with its link. Nothing is sent until you press Add.'**
  String get desktopBrowserButtonHint;

  /// No description provided for @desktopBrowserButtonName.
  ///
  /// In en, this message translates to:
  /// **'To Ember'**
  String get desktopBrowserButtonName;

  /// No description provided for @desktopBrowserButtonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the setup page'**
  String get desktopBrowserButtonOpen;

  /// No description provided for @desktopBrowserPageCopyInstead.
  ///
  /// In en, this message translates to:
  /// **'If dragging does not work, make a new bookmark and paste this as its address:'**
  String get desktopBrowserPageCopyInstead;

  /// No description provided for @desktopBrowserPageDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag it to the bar; a click here does nothing.'**
  String get desktopBrowserPageDragHint;

  /// No description provided for @desktopBrowserPageStep1.
  ///
  /// In en, this message translates to:
  /// **'Show the bookmarks bar if it is hidden:'**
  String get desktopBrowserPageStep1;

  /// No description provided for @desktopBrowserPageStep2.
  ///
  /// In en, this message translates to:
  /// **'Drag the button below onto the bar with the mouse.'**
  String get desktopBrowserPageStep2;

  /// No description provided for @desktopBrowserPageStep3.
  ///
  /// In en, this message translates to:
  /// **'On any video\'s page, click it: MeTube Ember opens its add dialog with the link. The first time, the browser asks whether to open the app; allow it.'**
  String get desktopBrowserPageStep3;

  /// No description provided for @desktopBrowserPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add the “To Ember” button to your browser'**
  String get desktopBrowserPageTitle;

  /// No description provided for @desktopChangeFolder.
  ///
  /// In en, this message translates to:
  /// **'Change…'**
  String get desktopChangeFolder;

  /// No description provided for @desktopChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get desktopChannel;

  /// No description provided for @desktopChannelClips.
  ///
  /// In en, this message translates to:
  /// **'In your library'**
  String get desktopChannelClips;

  /// No description provided for @desktopChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get desktopChannels;

  /// No description provided for @desktopChannelsInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Channels in your library'**
  String get desktopChannelsInLibrary;

  /// No description provided for @desktopChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get desktopChapters;

  /// No description provided for @desktopCheckAll.
  ///
  /// In en, this message translates to:
  /// **'Check all'**
  String get desktopCheckAll;

  /// No description provided for @desktopChooseClip.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get desktopChooseClip;

  /// No description provided for @desktopClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get desktopClearFilters;

  /// No description provided for @desktopClearFinished.
  ///
  /// In en, this message translates to:
  /// **'Hide finished'**
  String get desktopClearFinished;

  /// No description provided for @desktopClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get desktopClearSelection;

  /// No description provided for @desktopCookiesPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The files go straight to your server and are never kept on this computer. They are your accounts\' sign-in material, so only ever send them to a server you own.'**
  String get desktopCookiesPrivacy;

  /// No description provided for @desktopCookiesReplaceNote.
  ///
  /// In en, this message translates to:
  /// **'Each upload replaces the server\'s whole cookies file. To keep several platforms, choose all their files together every time, the ones you sent before too. Hold Ctrl to choose more than one.'**
  String get desktopCookiesReplaceNote;

  /// No description provided for @desktopCopiedLinkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add…'**
  String get desktopCopiedLinkAdd;

  /// No description provided for @desktopCopiedLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add this link to the server?'**
  String get desktopCopiedLinkTitle;

  /// No description provided for @desktopCopyCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get desktopCopyCancelled;

  /// No description provided for @desktopCopyFile.
  ///
  /// In en, this message translates to:
  /// **'Copy file'**
  String get desktopCopyFile;

  /// No description provided for @desktopCopyFileFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be copied'**
  String get desktopCopyFileFailed;

  /// No description provided for @desktopCopyFileLarge.
  ///
  /// In en, this message translates to:
  /// **'A large file'**
  String get desktopCopyFileLarge;

  /// No description provided for @desktopCopyFileLargeMessage.
  ///
  /// In en, this message translates to:
  /// **'This clip is {size}. It is saved to your download folder first, then copied; many chat apps refuse a file this big.'**
  String desktopCopyFileLargeMessage(String size);

  /// No description provided for @desktopCopyFileNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough space on the drive: the file is {needed} and {free} is free'**
  String desktopCopyFileNoSpace(String needed, String free);

  /// No description provided for @desktopCopyFilePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the file to copy; its progress is in Downloads'**
  String get desktopCopyFilePreparing;

  /// No description provided for @desktopCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get desktopCopyLink;

  /// No description provided for @desktopCopyOneClip.
  ///
  /// In en, this message translates to:
  /// **'Copying takes one clip at a time'**
  String get desktopCopyOneClip;

  /// No description provided for @desktopCopyQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting its turn'**
  String get desktopCopyQueued;

  /// No description provided for @desktopCopyQuote.
  ///
  /// In en, this message translates to:
  /// **'Copy with time and link'**
  String get desktopCopyQuote;

  /// No description provided for @desktopDefaultQualityHint.
  ///
  /// In en, this message translates to:
  /// **'What each add starts with; you can still change it for each link.'**
  String get desktopDefaultQualityHint;

  /// No description provided for @desktopDeleteSelectedConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 clip from the server? A copy on this computer stays.} other{Delete {count} clips from the server? Copies on this computer stay.}}'**
  String desktopDeleteSelectedConfirm(int count);

  /// No description provided for @desktopDesktopSection.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get desktopDesktopSection;

  /// No description provided for @desktopDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover MeTube Ember'**
  String get desktopDiscover;

  /// No description provided for @desktopDiscoverAddLink.
  ///
  /// In en, this message translates to:
  /// **'Paste or drop a link'**
  String get desktopDiscoverAddLink;

  /// No description provided for @desktopDiscoverAddLinkLine.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+V anywhere, or drop a link on the window, to add it.'**
  String get desktopDiscoverAddLinkLine;

  /// No description provided for @desktopDiscoverAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding and sharing'**
  String get desktopDiscoverAdding;

  /// No description provided for @desktopDiscoverBrowser.
  ///
  /// In en, this message translates to:
  /// **'From the browser'**
  String get desktopDiscoverBrowser;

  /// No description provided for @desktopDiscoverBrowserLine.
  ///
  /// In en, this message translates to:
  /// **'The “To Ember” button on your bookmarks bar opens the add dialog with the page you are on.'**
  String get desktopDiscoverBrowserLine;

  /// No description provided for @desktopDiscoverChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get desktopDiscoverChapters;

  /// No description provided for @desktopDiscoverChaptersLine.
  ///
  /// In en, this message translates to:
  /// **'A clip\'s parts, from its transcript, on its page.'**
  String get desktopDiscoverChaptersLine;

  /// No description provided for @desktopDiscoverChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose many'**
  String get desktopDiscoverChoose;

  /// No description provided for @desktopDiscoverChooseLine.
  ///
  /// In en, this message translates to:
  /// **'The round mark, or Ctrl or Shift with a click; then add them to a list or delete them together.'**
  String get desktopDiscoverChooseLine;

  /// No description provided for @desktopDiscoverDragOut.
  ///
  /// In en, this message translates to:
  /// **'Drag a clip out'**
  String get desktopDiscoverDragOut;

  /// No description provided for @desktopDiscoverDragOutLine.
  ///
  /// In en, this message translates to:
  /// **'Onto a folder or another app, as a file.'**
  String get desktopDiscoverDragOutLine;

  /// No description provided for @desktopDiscoverExport.
  ///
  /// In en, this message translates to:
  /// **'Export a transcript'**
  String get desktopDiscoverExport;

  /// No description provided for @desktopDiscoverExportLine.
  ///
  /// In en, this message translates to:
  /// **'As text, or as SRT subtitles for another player.'**
  String get desktopDiscoverExportLine;

  /// No description provided for @desktopDiscoverHint.
  ///
  /// In en, this message translates to:
  /// **'Everything the app can do, a line each, with its keys.'**
  String get desktopDiscoverHint;

  /// No description provided for @desktopDiscoverLibrary.
  ///
  /// In en, this message translates to:
  /// **'The library'**
  String get desktopDiscoverLibrary;

  /// No description provided for @desktopDiscoverListening.
  ///
  /// In en, this message translates to:
  /// **'For sound: a quiet room with the cover large, in full screen.'**
  String get desktopDiscoverListening;

  /// No description provided for @desktopDiscoverMini.
  ///
  /// In en, this message translates to:
  /// **'Small window'**
  String get desktopDiscoverMini;

  /// No description provided for @desktopDiscoverMiniLine.
  ///
  /// In en, this message translates to:
  /// **'A small card above every other window, by the clock.'**
  String get desktopDiscoverMiniLine;

  /// No description provided for @desktopDiscoverPhone.
  ///
  /// In en, this message translates to:
  /// **'With your phone'**
  String get desktopDiscoverPhone;

  /// No description provided for @desktopDiscoverPhoneLine.
  ///
  /// In en, this message translates to:
  /// **'Tags, lists and resume points, shared with MeTube Super through a folder you choose.'**
  String get desktopDiscoverPhoneLine;

  /// No description provided for @desktopDiscoverReading.
  ///
  /// In en, this message translates to:
  /// **'The transcript as an article: click a sentence to hear it from there.'**
  String get desktopDiscoverReading;

  /// No description provided for @desktopDiscoverSaid.
  ///
  /// In en, this message translates to:
  /// **'What was said'**
  String get desktopDiscoverSaid;

  /// No description provided for @desktopDiscoverSearch.
  ///
  /// In en, this message translates to:
  /// **'Search what was said'**
  String get desktopDiscoverSearch;

  /// No description provided for @desktopDiscoverSearchLine.
  ///
  /// In en, this message translates to:
  /// **'Find the clips where a word was spoken, not only in titles.'**
  String get desktopDiscoverSearchLine;

  /// No description provided for @desktopDiscoverShortcutsLine.
  ///
  /// In en, this message translates to:
  /// **'Every key the window answers, on one sheet.'**
  String get desktopDiscoverShortcutsLine;

  /// No description provided for @desktopDiscoverShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get desktopDiscoverShow;

  /// No description provided for @desktopDiscoverStatsLine.
  ///
  /// In en, this message translates to:
  /// **'The library counted: by site, channel and month.'**
  String get desktopDiscoverStatsLine;

  /// No description provided for @desktopDiscoverSubtitles.
  ///
  /// In en, this message translates to:
  /// **'The transcript over the picture, the spoken word lit up.'**
  String get desktopDiscoverSubtitles;

  /// No description provided for @desktopDiscoverTheater.
  ///
  /// In en, this message translates to:
  /// **'A larger picture that takes the side panel\'s place.'**
  String get desktopDiscoverTheater;

  /// No description provided for @desktopDiscoverTry.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get desktopDiscoverTry;

  /// No description provided for @desktopDiscoverWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching and listening'**
  String get desktopDiscoverWatching;

  /// No description provided for @desktopDownloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get desktopDownloadFolder;

  /// No description provided for @desktopDownloadFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Your own files: saved here, then the app leaves them alone.'**
  String get desktopDownloadFolderHint;

  /// No description provided for @desktopDownloadTo.
  ///
  /// In en, this message translates to:
  /// **'Download…'**
  String get desktopDownloadTo;

  /// No description provided for @desktopDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading · {percent}%'**
  String desktopDownloading(int percent);

  /// No description provided for @desktopDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get desktopDownloads;

  /// No description provided for @desktopDownloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is downloading. Add a link, or make a clip available offline.'**
  String get desktopDownloadsEmpty;

  /// No description provided for @desktopDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get desktopDragToReorder;

  /// No description provided for @desktopDropLinks.
  ///
  /// In en, this message translates to:
  /// **'Drop to add'**
  String get desktopDropLinks;

  /// No description provided for @desktopEmptyLibraryMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a link, and the clip appears here once the server has it.'**
  String get desktopEmptyLibraryMessage;

  /// No description provided for @desktopExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get desktopExport;

  /// No description provided for @desktopExportForPhone.
  ///
  /// In en, this message translates to:
  /// **'Export for the phone'**
  String get desktopExportForPhone;

  /// No description provided for @desktopExportForPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Saves this computer\'s tags, lists and resume points, and its transcripts, as two files the phone restores. Restoring on the phone replaces its own tags and lists.'**
  String get desktopExportForPhoneHint;

  /// No description provided for @desktopExportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Text (Markdown)'**
  String get desktopExportMarkdown;

  /// No description provided for @desktopExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Document (PDF)'**
  String get desktopExportPdf;

  /// No description provided for @desktopExportPhone.
  ///
  /// In en, this message translates to:
  /// **'For the phone (Super\'s import)'**
  String get desktopExportPhone;

  /// No description provided for @desktopExportSrt.
  ///
  /// In en, this message translates to:
  /// **'Subtitles (SRT)'**
  String get desktopExportSrt;

  /// No description provided for @desktopExported.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String desktopExported(String name);

  /// No description provided for @desktopFileReadyToPaste.
  ///
  /// In en, this message translates to:
  /// **'Ready to paste: {name} · {size}'**
  String desktopFileReadyToPaste(String name, String size);

  /// No description provided for @desktopFolderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No folder available'**
  String get desktopFolderUnavailable;

  /// No description provided for @desktopFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get desktopFolders;

  /// No description provided for @desktopForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get desktopForward;

  /// No description provided for @desktopGlobalShortcut.
  ///
  /// In en, this message translates to:
  /// **'Play and pause from any app'**
  String get desktopGlobalShortcut;

  /// No description provided for @desktopGlobalShortcutHint.
  ///
  /// In en, this message translates to:
  /// **'{keys} plays and pauses while the window is behind other apps.'**
  String desktopGlobalShortcutHint(String keys);

  /// No description provided for @desktopGlobalShortcutTaken.
  ///
  /// In en, this message translates to:
  /// **'Another app already uses {keys}.'**
  String desktopGlobalShortcutTaken(String keys);

  /// No description provided for @desktopHidePanel.
  ///
  /// In en, this message translates to:
  /// **'Hide side panel'**
  String get desktopHidePanel;

  /// No description provided for @desktopHintShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Press ? for the keyboard shortcuts. Space plays and pauses; the arrow keys seek.'**
  String get desktopHintShortcuts;

  /// No description provided for @desktopHintShortcutsAction.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get desktopHintShortcutsAction;

  /// No description provided for @desktopHintTrayBody.
  ///
  /// In en, this message translates to:
  /// **'It keeps playing from its icon by the clock. To quit, right-click the icon.'**
  String get desktopHintTrayBody;

  /// No description provided for @desktopHintTrayTitle.
  ///
  /// In en, this message translates to:
  /// **'MeTube Ember is still running'**
  String get desktopHintTrayTitle;

  /// No description provided for @desktopHints.
  ///
  /// In en, this message translates to:
  /// **'Show tips'**
  String get desktopHints;

  /// No description provided for @desktopHintsAgain.
  ///
  /// In en, this message translates to:
  /// **'Show them again'**
  String get desktopHintsAgain;

  /// No description provided for @desktopHintsHint.
  ///
  /// In en, this message translates to:
  /// **'Two short tips, each shown once: the shortcuts at the first clip, the icon by the clock at the first close.'**
  String get desktopHintsHint;

  /// No description provided for @desktopImportFromPhone.
  ///
  /// In en, this message translates to:
  /// **'Import from the phone…'**
  String get desktopImportFromPhone;

  /// No description provided for @desktopImportHint.
  ///
  /// In en, this message translates to:
  /// **'A backup or transcripts file from MeTube Super or Lite, chosen here or dropped on the window. It is added to what is here; nothing is replaced.'**
  String get desktopImportHint;

  /// No description provided for @desktopImportedBackup.
  ///
  /// In en, this message translates to:
  /// **'Added from the phone. Tags: {tagged} · lists: {lists} · resume points: {positions}'**
  String desktopImportedBackup(int tagged, int lists, int positions);

  /// No description provided for @desktopImportedNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing new: this computer already had all of it.'**
  String get desktopImportedNothing;

  /// No description provided for @desktopImportedTranscripts.
  ///
  /// In en, this message translates to:
  /// **'Transcripts added: {count}'**
  String desktopImportedTranscripts(int count);

  /// No description provided for @desktopInLibrary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 in your library} other{{count} in your library}}'**
  String desktopInLibrary(int count);

  /// No description provided for @desktopKeyAddLink.
  ///
  /// In en, this message translates to:
  /// **'Add the link you copied'**
  String get desktopKeyAddLink;

  /// No description provided for @desktopKeyFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites or remove'**
  String get desktopKeyFavorite;

  /// No description provided for @desktopKeyFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen; for sound, the listening room'**
  String get desktopKeyFullScreen;

  /// No description provided for @desktopKeyMenu.
  ///
  /// In en, this message translates to:
  /// **'The clip\'s menu'**
  String get desktopKeyMenu;

  /// No description provided for @desktopKeyMini.
  ///
  /// In en, this message translates to:
  /// **'Small window above the others, and back'**
  String get desktopKeyMini;

  /// No description provided for @desktopKeyPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play or pause'**
  String get desktopKeyPlayPause;

  /// No description provided for @desktopKeyRepeat.
  ///
  /// In en, this message translates to:
  /// **'Change repeat'**
  String get desktopKeyRepeat;

  /// No description provided for @desktopKeySearch.
  ///
  /// In en, this message translates to:
  /// **'Search titles and what was said'**
  String get desktopKeySearch;

  /// No description provided for @desktopKeySeek.
  ///
  /// In en, this message translates to:
  /// **'Back or forward 10 seconds'**
  String get desktopKeySeek;

  /// No description provided for @desktopKeyShortcuts.
  ///
  /// In en, this message translates to:
  /// **'This list'**
  String get desktopKeyShortcuts;

  /// No description provided for @desktopKeyVolume.
  ///
  /// In en, this message translates to:
  /// **'Louder or quieter; in shorts, the previous or next one'**
  String get desktopKeyVolume;

  /// No description provided for @desktopKeyZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Larger interface'**
  String get desktopKeyZoomIn;

  /// No description provided for @desktopKeyZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Smaller interface'**
  String get desktopKeyZoomOut;

  /// No description provided for @desktopKeyZoomReset.
  ///
  /// In en, this message translates to:
  /// **'Interface at its usual size'**
  String get desktopKeyZoomReset;

  /// No description provided for @desktopLanguageSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Follows the language of Windows.'**
  String get desktopLanguageSystemHint;

  /// No description provided for @desktopLastArrival.
  ///
  /// In en, this message translates to:
  /// **'Last arrival {when}'**
  String desktopLastArrival(String when);

  /// No description provided for @desktopLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get desktopLess;

  /// No description provided for @desktopLibraryLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the library…'**
  String get desktopLibraryLoading;

  /// No description provided for @desktopLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get desktopLinkCopied;

  /// No description provided for @desktopLinkDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Repeated above'**
  String get desktopLinkDuplicate;

  /// No description provided for @desktopLinkInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Already in your library'**
  String get desktopLinkInLibrary;

  /// No description provided for @desktopLinkPlaylist.
  ///
  /// In en, this message translates to:
  /// **'A playlist: choose its clips'**
  String get desktopLinkPlaylist;

  /// No description provided for @desktopLinkReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get desktopLinkReady;

  /// No description provided for @desktopLinkUnsupported.
  ///
  /// In en, this message translates to:
  /// **'A site this app doesn\'t know'**
  String get desktopLinkUnsupported;

  /// No description provided for @desktopLinksDropped.
  ///
  /// In en, this message translates to:
  /// **'Only the first {limit} links are taken; {count} more were left out.'**
  String desktopLinksDropped(int count, int limit);

  /// No description provided for @desktopLinksFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 link} other{{count} links}}'**
  String desktopLinksFound(int count);

  /// No description provided for @desktopListeningClose.
  ///
  /// In en, this message translates to:
  /// **'Close the listening room'**
  String get desktopListeningClose;

  /// No description provided for @desktopListeningRoom.
  ///
  /// In en, this message translates to:
  /// **'Listening room'**
  String get desktopListeningRoom;

  /// No description provided for @desktopLocalCopyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Local copy removed'**
  String get desktopLocalCopyRemoved;

  /// No description provided for @desktopLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Log copied, without links or addresses'**
  String get desktopLogsCopied;

  /// No description provided for @desktopLogsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get desktopLogsCopy;

  /// No description provided for @desktopLogsSave.
  ///
  /// In en, this message translates to:
  /// **'Save to a file'**
  String get desktopLogsSave;

  /// No description provided for @desktopMiniRestore.
  ///
  /// In en, this message translates to:
  /// **'Back to the full window'**
  String get desktopMiniRestore;

  /// No description provided for @desktopMiniWindow.
  ///
  /// In en, this message translates to:
  /// **'Small window'**
  String get desktopMiniWindow;

  /// No description provided for @desktopMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get desktopMore;

  /// No description provided for @desktopNarrowSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get desktopNarrowSidebar;

  /// No description provided for @desktopNoChannelNames.
  ///
  /// In en, this message translates to:
  /// **'Your server doesn\'t record which channel each clip came from, so this channel\'s clips can\'t be picked out. Follow it with its own folder, and whatever arrives there shows here.'**
  String get desktopNoChannelNames;

  /// No description provided for @desktopNoFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'Mark a clip as a favorite and it waits for you here.'**
  String get desktopNoFavoritesMessage;

  /// No description provided for @desktopNoFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get desktopNoFavoritesTitle;

  /// No description provided for @desktopNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear a filter to see more.'**
  String get desktopNoMatchMessage;

  /// No description provided for @desktopNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters'**
  String get desktopNoMatchTitle;

  /// No description provided for @desktopNoOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose “Make available offline” from a clip\'s menu, and it plays here without the server.'**
  String get desktopNoOfflineMessage;

  /// No description provided for @desktopNoOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing kept on this computer yet'**
  String get desktopNoOfflineTitle;

  /// No description provided for @desktopNoServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Set up your MeTube server and its library appears here.'**
  String get desktopNoServerMessage;

  /// No description provided for @desktopNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Tag a clip from its page and it appears here.'**
  String get desktopNoTags;

  /// No description provided for @desktopNoTranscriptMessage.
  ///
  /// In en, this message translates to:
  /// **'It shows here once the server has the clip\'s subtitles.'**
  String get desktopNoTranscriptMessage;

  /// No description provided for @desktopNoTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'No transcript for this clip'**
  String get desktopNoTranscriptTitle;

  /// No description provided for @desktopNotABackup.
  ///
  /// In en, this message translates to:
  /// **'This file is not a MeTube backup or transcripts file.'**
  String get desktopNotABackup;

  /// No description provided for @desktopNotWatched.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 not watched} other{{count} not watched}}'**
  String desktopNotWatched(int count);

  /// No description provided for @desktopNothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get desktopNothingPlaying;

  /// No description provided for @desktopNothingPlayingHint.
  ///
  /// In en, this message translates to:
  /// **'Play a clip and its transcript, what comes next and its details appear here.'**
  String get desktopNothingPlayingHint;

  /// No description provided for @desktopNoticeSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to this computer'**
  String get desktopNoticeSaved;

  /// No description provided for @desktopNotifyArrivalsHint.
  ///
  /// In en, this message translates to:
  /// **'A Windows notice when new clips from the channels you follow reach the server.'**
  String get desktopNotifyArrivalsHint;

  /// No description provided for @desktopOfferCopiedLinks.
  ///
  /// In en, this message translates to:
  /// **'Offer links I copy'**
  String get desktopOfferCopiedLinks;

  /// No description provided for @desktopOfferCopiedLinksHint.
  ///
  /// In en, this message translates to:
  /// **'When you copy a video link in another app, a notification offers to add it. Only links are looked at, and none is saved.'**
  String get desktopOfferCopiedLinksHint;

  /// No description provided for @desktopOfflineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} offline'**
  String desktopOfflineCount(int count);

  /// No description provided for @desktopOfflineFolder.
  ///
  /// In en, this message translates to:
  /// **'Offline folder'**
  String get desktopOfflineFolder;

  /// No description provided for @desktopOfflineFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Copies the app knows and plays without the server; \"Remove local copy\" deletes them.'**
  String get desktopOfflineFolderHint;

  /// No description provided for @desktopOfflineProgress.
  ///
  /// In en, this message translates to:
  /// **'Offline · {percent}%'**
  String desktopOfflineProgress(int percent);

  /// No description provided for @desktopOpenChannels.
  ///
  /// In en, this message translates to:
  /// **'Open channels'**
  String get desktopOpenChannels;

  /// No description provided for @desktopOpenInExplorer.
  ///
  /// In en, this message translates to:
  /// **'Open in Explorer'**
  String get desktopOpenInExplorer;

  /// No description provided for @desktopOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Open in another player…'**
  String get desktopOpenWith;

  /// No description provided for @desktopPaletteClose.
  ///
  /// In en, this message translates to:
  /// **'to close'**
  String get desktopPaletteClose;

  /// No description provided for @desktopPaletteCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get desktopPaletteCommands;

  /// No description provided for @desktopPaletteHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles and what was said, or type > for commands'**
  String get desktopPaletteHint;

  /// No description provided for @desktopPaletteList.
  ///
  /// In en, this message translates to:
  /// **'List: {name}'**
  String desktopPaletteList(String name);

  /// No description provided for @desktopPaletteMove.
  ///
  /// In en, this message translates to:
  /// **'to move'**
  String get desktopPaletteMove;

  /// No description provided for @desktopPaletteOpen.
  ///
  /// In en, this message translates to:
  /// **'to open'**
  String get desktopPaletteOpen;

  /// No description provided for @desktopPaletteSaid.
  ///
  /// In en, this message translates to:
  /// **'Said inside clips'**
  String get desktopPaletteSaid;

  /// No description provided for @desktopPaletteSave.
  ///
  /// In en, this message translates to:
  /// **'Save this search'**
  String get desktopPaletteSave;

  /// No description provided for @desktopPaletteSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings: {section}'**
  String desktopPaletteSettings(String section);

  /// No description provided for @desktopPaletteTitles.
  ///
  /// In en, this message translates to:
  /// **'Titles'**
  String get desktopPaletteTitles;

  /// No description provided for @desktopPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get desktopPinned;

  /// No description provided for @desktopPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get desktopPlayNext;

  /// No description provided for @desktopPlaysNext.
  ///
  /// In en, this message translates to:
  /// **'Plays next, after this one'**
  String get desktopPlaysNext;

  /// No description provided for @desktopPullAfter.
  ///
  /// In en, this message translates to:
  /// **'Then download it to this computer'**
  String get desktopPullAfter;

  /// No description provided for @desktopQueueEnd.
  ///
  /// In en, this message translates to:
  /// **'Nothing comes after this one'**
  String get desktopQueueEnd;

  /// No description provided for @desktopQuote.
  ///
  /// In en, this message translates to:
  /// **'“{text}”\n— {title}, {time}\n{link}'**
  String desktopQuote(String text, String title, String time, String link);

  /// No description provided for @desktopQuoteCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied with its time and link'**
  String get desktopQuoteCopied;

  /// No description provided for @desktopReadingBack.
  ///
  /// In en, this message translates to:
  /// **'Back to the clip'**
  String get desktopReadingBack;

  /// No description provided for @desktopReadingCloseFind.
  ///
  /// In en, this message translates to:
  /// **'Close the search'**
  String get desktopReadingCloseFind;

  /// No description provided for @desktopReadingFind.
  ///
  /// In en, this message translates to:
  /// **'Find in the text'**
  String get desktopReadingFind;

  /// No description provided for @desktopReadingFound.
  ///
  /// In en, this message translates to:
  /// **'{at} of {count}'**
  String desktopReadingFound(int at, int count);

  /// No description provided for @desktopReadingHint.
  ///
  /// In en, this message translates to:
  /// **'Click a sentence to hear it from there · Ctrl+F finds a word · select to copy with its time'**
  String get desktopReadingHint;

  /// No description provided for @desktopReadingNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get desktopReadingNextMatch;

  /// No description provided for @desktopReadingPreviousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get desktopReadingPreviousMatch;

  /// No description provided for @desktopReadingRoom.
  ///
  /// In en, this message translates to:
  /// **'Reading room'**
  String get desktopReadingRoom;

  /// No description provided for @desktopRemoveFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from the list'**
  String get desktopRemoveFromList;

  /// No description provided for @desktopRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get desktopRestore;

  /// No description provided for @desktopRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'This computer\'s tags, lists and settings become what the backup holds. The server is not touched.'**
  String get desktopRestoreBody;

  /// No description provided for @desktopRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get desktopRestoreTitle;

  /// No description provided for @desktopRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get desktopRestored;

  /// No description provided for @desktopRevealAfterDownload.
  ///
  /// In en, this message translates to:
  /// **'Show in Explorer when done'**
  String get desktopRevealAfterDownload;

  /// No description provided for @desktopRevealAfterDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'When a file downloaded to this computer is done, its folder opens with the file chosen.'**
  String get desktopRevealAfterDownloadHint;

  /// No description provided for @desktopSavedIn.
  ///
  /// In en, this message translates to:
  /// **'Saved in {folder}'**
  String desktopSavedIn(String folder);

  /// No description provided for @desktopSavedSearchDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the saved search “{name}”? Nothing in the library changes.'**
  String desktopSavedSearchDelete(String name);

  /// No description provided for @desktopSavedSearchName.
  ///
  /// In en, this message translates to:
  /// **'Search name'**
  String get desktopSavedSearchName;

  /// No description provided for @desktopSavingOffline.
  ///
  /// In en, this message translates to:
  /// **'Saving offline · {percent}%'**
  String desktopSavingOffline(int percent);

  /// No description provided for @desktopSavingTo.
  ///
  /// In en, this message translates to:
  /// **'Saving to {folder}'**
  String desktopSavingTo(String folder);

  /// No description provided for @desktopSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get desktopSearch;

  /// No description provided for @desktopSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles and what was said…'**
  String get desktopSearchHint;

  /// No description provided for @desktopSearchSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved in the sidebar'**
  String get desktopSearchSaved;

  /// No description provided for @desktopSeekBar.
  ///
  /// In en, this message translates to:
  /// **'Position in the clip'**
  String get desktopSeekBar;

  /// No description provided for @desktopSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String desktopSelectedCount(int count);

  /// No description provided for @desktopServerFolders.
  ///
  /// In en, this message translates to:
  /// **'Same folders as on the server'**
  String get desktopServerFolders;

  /// No description provided for @desktopServerFoldersHint.
  ///
  /// In en, this message translates to:
  /// **'For example, a clip in a folder called “Kids” on the server is saved in a folder of the same name here.'**
  String get desktopServerFoldersHint;

  /// No description provided for @desktopServerPartMissing.
  ///
  /// In en, this message translates to:
  /// **'The server isn\'t answering, so this is what it held last time.'**
  String get desktopServerPartMissing;

  /// No description provided for @desktopServerVersion.
  ///
  /// In en, this message translates to:
  /// **'Server version'**
  String get desktopServerVersion;

  /// No description provided for @desktopSetupAgain.
  ///
  /// In en, this message translates to:
  /// **'Set up again'**
  String get desktopSetupAgain;

  /// No description provided for @desktopSetupChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file…'**
  String get desktopSetupChooseFile;

  /// No description provided for @desktopSetupConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get desktopSetupConnect;

  /// No description provided for @desktopSetupEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter the address'**
  String get desktopSetupEnter;

  /// No description provided for @desktopSetupFoundNone.
  ///
  /// In en, this message translates to:
  /// **'No MeTube server answered on these ports.'**
  String get desktopSetupFoundNone;

  /// No description provided for @desktopSetupImport.
  ///
  /// In en, this message translates to:
  /// **'Import from the phone'**
  String get desktopSetupImport;

  /// No description provided for @desktopSetupImportHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a MeTube Super backup: its server address is offered here, and its tags and lists are added.'**
  String get desktopSetupImportHint;

  /// No description provided for @desktopSetupLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get desktopSetupLater;

  /// No description provided for @desktopSetupNeedsPassword.
  ///
  /// In en, this message translates to:
  /// **'Needs a password'**
  String get desktopSetupNeedsPassword;

  /// No description provided for @desktopSetupNoServer.
  ///
  /// In en, this message translates to:
  /// **'No server yet?'**
  String get desktopSetupNoServer;

  /// No description provided for @desktopSetupPorts.
  ///
  /// In en, this message translates to:
  /// **'Ports'**
  String get desktopSetupPorts;

  /// No description provided for @desktopSetupSearch.
  ///
  /// In en, this message translates to:
  /// **'Search my network'**
  String get desktopSetupSearch;

  /// No description provided for @desktopSetupSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Looks for MeTube on this computer\'s network, only when you click.'**
  String get desktopSetupSearchHint;

  /// No description provided for @desktopSetupSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching… {percent}%'**
  String desktopSetupSearching(int percent);

  /// No description provided for @desktopSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to your MeTube server'**
  String get desktopSetupTitle;

  /// No description provided for @desktopShortcutsApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get desktopShortcutsApp;

  /// No description provided for @desktopShortcutsClip.
  ///
  /// In en, this message translates to:
  /// **'On a chosen clip'**
  String get desktopShortcutsClip;

  /// No description provided for @desktopShortcutsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get desktopShortcutsPlayback;

  /// No description provided for @desktopShortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get desktopShortcutsTitle;

  /// No description provided for @desktopShortcutsWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get desktopShortcutsWindow;

  /// No description provided for @desktopShortsHint.
  ///
  /// In en, this message translates to:
  /// **'↑ ↓ or the wheel for the next short · double-click to favorite'**
  String get desktopShortsHint;

  /// No description provided for @desktopShowInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get desktopShowInFolder;

  /// No description provided for @desktopShowPanel.
  ///
  /// In en, this message translates to:
  /// **'Show side panel'**
  String get desktopShowPanel;

  /// No description provided for @desktopStartWithWindows.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get desktopStartWithWindows;

  /// No description provided for @desktopStartWithWindowsHint.
  ///
  /// In en, this message translates to:
  /// **'Opens when you sign in: in the tray when it keeps playing there, otherwise minimized.'**
  String get desktopStartWithWindowsHint;

  /// No description provided for @desktopStartWithWindowsRefused.
  ///
  /// In en, this message translates to:
  /// **'Windows did not let the app start with it.'**
  String get desktopStartWithWindowsRefused;

  /// No description provided for @desktopStats.
  ///
  /// In en, this message translates to:
  /// **'Library statistics'**
  String get desktopStats;

  /// No description provided for @desktopStatsByChannel.
  ///
  /// In en, this message translates to:
  /// **'By channel'**
  String get desktopStatsByChannel;

  /// No description provided for @desktopStatsByMonth.
  ///
  /// In en, this message translates to:
  /// **'By month added'**
  String get desktopStatsByMonth;

  /// No description provided for @desktopStatsBySite.
  ///
  /// In en, this message translates to:
  /// **'By site'**
  String get desktopStatsBySite;

  /// No description provided for @desktopStatsClips.
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get desktopStatsClips;

  /// No description provided for @desktopStatsHint.
  ///
  /// In en, this message translates to:
  /// **'What the library holds, and what may deserve a look. Nothing is deleted from here.'**
  String get desktopStatsHint;

  /// No description provided for @desktopStatsHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Under an hour} =1{1 hour} other{{count} hours}}'**
  String desktopStatsHours(int count);

  /// No description provided for @desktopStatsLargest.
  ///
  /// In en, this message translates to:
  /// **'The largest:'**
  String get desktopStatsLargest;

  /// No description provided for @desktopStatsLength.
  ///
  /// In en, this message translates to:
  /// **'Running time'**
  String get desktopStatsLength;

  /// No description provided for @desktopStatsLink.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get desktopStatsLink;

  /// No description provided for @desktopStatsNeverPlayed.
  ///
  /// In en, this message translates to:
  /// **'Never played here'**
  String get desktopStatsNeverPlayed;

  /// No description provided for @desktopStatsNewest.
  ///
  /// In en, this message translates to:
  /// **'The newest:'**
  String get desktopStatsNewest;

  /// No description provided for @desktopStatsOtherChannels.
  ///
  /// In en, this message translates to:
  /// **'Other channels'**
  String get desktopStatsOtherChannels;

  /// No description provided for @desktopStatsRoom.
  ///
  /// In en, this message translates to:
  /// **'Room taken'**
  String get desktopStatsRoom;

  /// No description provided for @desktopStatsUnnamed.
  ///
  /// In en, this message translates to:
  /// **'No channel named'**
  String get desktopStatsUnnamed;

  /// No description provided for @desktopStatsWithText.
  ///
  /// In en, this message translates to:
  /// **'With a transcript'**
  String get desktopStatsWithText;

  /// No description provided for @desktopStatsWithoutText.
  ///
  /// In en, this message translates to:
  /// **'Without a transcript'**
  String get desktopStatsWithoutText;

  /// No description provided for @desktopStatsWorthALook.
  ///
  /// In en, this message translates to:
  /// **'Worth a look'**
  String get desktopStatsWorthALook;

  /// No description provided for @desktopSubtitleOptions.
  ///
  /// In en, this message translates to:
  /// **'Subtitle options'**
  String get desktopSubtitleOptions;

  /// No description provided for @desktopSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get desktopSync;

  /// No description provided for @desktopSyncCameBack.
  ///
  /// In en, this message translates to:
  /// **'This computer was away for more than 90 days, so your other devices\' data was taken first.'**
  String get desktopSyncCameBack;

  /// No description provided for @desktopSyncChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get desktopSyncChoose;

  /// No description provided for @desktopSyncComputer.
  ///
  /// In en, this message translates to:
  /// **'Computer {name}'**
  String desktopSyncComputer(String name);

  /// No description provided for @desktopSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'The sync folder could not be read. Check that its drive is there.'**
  String get desktopSyncFailed;

  /// No description provided for @desktopSyncFolder.
  ///
  /// In en, this message translates to:
  /// **'Sync folder'**
  String get desktopSyncFolder;

  /// No description provided for @desktopSyncForget.
  ///
  /// In en, this message translates to:
  /// **'Forget this device'**
  String get desktopSyncForget;

  /// No description provided for @desktopSyncForgetBody.
  ///
  /// In en, this message translates to:
  /// **'{device} will no longer be read. Its transcripts move to this computer\'s folder first, so none is lost. Use this for a device that was lost or sold.'**
  String desktopSyncForgetBody(String device);

  /// No description provided for @desktopSyncFrom.
  ///
  /// In en, this message translates to:
  /// **'Last from {device}: {ago}'**
  String desktopSyncFrom(String device, String ago);

  /// No description provided for @desktopSyncGuide.
  ///
  /// In en, this message translates to:
  /// **'At home: Syncthing on this computer and Syncthing‑Fork (from F-Droid) on the phone, sharing one folder; set Syncthing‑Fork to Wi‑Fi only to spare the phone\'s battery. Through a cloud: the cloud app\'s folder on this computer (OneDrive, Google Drive, Dropbox), and FolderSync on the phone with the same folder.'**
  String get desktopSyncGuide;

  /// No description provided for @desktopSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Mirrors tags, favorites, lists, positions, saved searches and transcripts with your phone and other computers, through a folder a sync app keeps in step (Syncthing at home, or a cloud folder). Nothing goes to any service from here.'**
  String get desktopSyncHint;

  /// No description provided for @desktopSyncLast.
  ///
  /// In en, this message translates to:
  /// **'Last synced {ago}'**
  String desktopSyncLast(String ago);

  /// No description provided for @desktopSyncNoOthers.
  ///
  /// In en, this message translates to:
  /// **'No other device in this folder yet. Turn sync on in MeTube Super with the same folder.'**
  String get desktopSyncNoOthers;

  /// No description provided for @desktopSyncNotBackup.
  ///
  /// In en, this message translates to:
  /// **'Sync is not a backup: it mirrors a mistake as faithfully as anything else. Your dated backups stay apart from it.'**
  String get desktopSyncNotBackup;

  /// No description provided for @desktopSyncOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Nothing leaves this computer.'**
  String get desktopSyncOff;

  /// No description provided for @desktopSyncPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone {name}'**
  String desktopSyncPhone(String name);

  /// No description provided for @desktopSyncThisComputer.
  ///
  /// In en, this message translates to:
  /// **'This computer: {name}'**
  String desktopSyncThisComputer(String name);

  /// No description provided for @desktopSyncTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get desktopSyncTurnOff;

  /// No description provided for @desktopTheater.
  ///
  /// In en, this message translates to:
  /// **'Theater'**
  String get desktopTheater;

  /// No description provided for @desktopToThisComputer.
  ///
  /// In en, this message translates to:
  /// **'To this computer'**
  String get desktopToThisComputer;

  /// No description provided for @desktopTranscriptFirst.
  ///
  /// In en, this message translates to:
  /// **'Fetch its transcript first'**
  String get desktopTranscriptFirst;

  /// No description provided for @desktopTranscriptHint.
  ///
  /// In en, this message translates to:
  /// **'Follows playback · click a line to jump'**
  String get desktopTranscriptHint;

  /// No description provided for @desktopTranscriptsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'They are removed from this computer. Only a file you exported, or another device through sync, can bring them back.'**
  String get desktopTranscriptsDeleteBody;

  /// No description provided for @desktopTranscriptsExportHint.
  ///
  /// In en, this message translates to:
  /// **'All of them in one file a phone can import.'**
  String get desktopTranscriptsExportHint;

  /// No description provided for @desktopTranscriptsHelp.
  ///
  /// In en, this message translates to:
  /// **'Ember keeps the words said in each YouTube clip you add, so a search (Ctrl+K) also finds what was said inside your clips, not only their titles. They stay on this computer.'**
  String get desktopTranscriptsHelp;

  /// No description provided for @desktopTranscriptsImportHint.
  ///
  /// In en, this message translates to:
  /// **'A transcripts file from a phone. It adds what is missing here and deletes nothing.'**
  String get desktopTranscriptsImportHint;

  /// No description provided for @desktopTrayOnClose.
  ///
  /// In en, this message translates to:
  /// **'Keep playing in the tray when the window closes'**
  String get desktopTrayOnClose;

  /// No description provided for @desktopTrayOnCloseHint.
  ///
  /// In en, this message translates to:
  /// **'Closing the window keeps the sound playing; quit from the icon by the clock.'**
  String get desktopTrayOnCloseHint;

  /// No description provided for @desktopTrayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open MeTube Ember'**
  String get desktopTrayOpen;

  /// No description provided for @desktopTrayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get desktopTrayQuit;

  /// No description provided for @desktopUiSize.
  ///
  /// In en, this message translates to:
  /// **'Interface size'**
  String get desktopUiSize;

  /// No description provided for @desktopUiSizeHint.
  ///
  /// In en, this message translates to:
  /// **'{bigger} and {smaller} change it from anywhere, and {reset} returns to 100%.'**
  String desktopUiSizeHint(String bigger, String smaller, String reset);

  /// No description provided for @desktopUiSizeTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too large for this screen'**
  String get desktopUiSizeTooLarge;

  /// No description provided for @desktopUpdateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install and restart'**
  String get desktopUpdateInstall;

  /// No description provided for @desktopUpdateRestartHint.
  ///
  /// In en, this message translates to:
  /// **'Ember closes, installs the update and opens again. Your settings and library stay as they are.'**
  String get desktopUpdateRestartHint;

  /// No description provided for @desktopViewCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get desktopViewCompact;

  /// No description provided for @desktopViewTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get desktopViewTable;

  /// No description provided for @desktopVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get desktopVolume;

  /// No description provided for @desktopVolumeLevel.
  ///
  /// In en, this message translates to:
  /// **'Volume {percent}%'**
  String desktopVolumeLevel(int percent);

  /// No description provided for @desktopWhatsNewAllFeatures.
  ///
  /// In en, this message translates to:
  /// **'Everything Ember can do'**
  String get desktopWhatsNewAllFeatures;

  /// No description provided for @desktopWidenSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get desktopWidenSidebar;

  /// No description provided for @desktopWindowClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get desktopWindowClose;

  /// No description provided for @desktopWindowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get desktopWindowMaximize;

  /// No description provided for @desktopWindowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get desktopWindowMinimize;

  /// No description provided for @desktopWindowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore down'**
  String get desktopWindowRestore;

  /// No description provided for @desktopZoomChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get desktopZoomChange;

  /// No description provided for @desktopZoomLowered.
  ///
  /// In en, this message translates to:
  /// **'The interface is now {percent} so it fits this screen.'**
  String desktopZoomLowered(String percent);

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
  /// **'Diagnostic logs'**
  String get diagnosticLogs;

  /// No description provided for @diagnosticLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View, search, and share app logs (redacted)'**
  String get diagnosticLogsSubtitle;

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

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get downloadComplete;

  /// No description provided for @downloadCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get downloadCompleteTitle;

  /// No description provided for @downloadDate.
  ///
  /// In en, this message translates to:
  /// **'Download date'**
  String get downloadDate;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @downloadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailedTitle;

  /// No description provided for @downloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadNow;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started…'**
  String get downloadStarted;

  /// No description provided for @downloadStartedQuality.
  ///
  /// In en, this message translates to:
  /// **'Download started · {quality}'**
  String downloadStartedQuality(Object quality);

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloading;

  /// No description provided for @downloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadingTitle;

  /// No description provided for @editSubscription.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editSubscription;

  /// No description provided for @emptyFilteredMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear a filter above to see your whole library.'**
  String get emptyFilteredMessage;

  /// No description provided for @emptyFilteredTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters'**
  String get emptyFilteredTitle;

  /// No description provided for @emptyLibraryMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a video link, or pull to refresh.'**
  String get emptyLibraryMessage;

  /// No description provided for @emptyOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose “Make available offline” on a clip, and it plays here without the server.'**
  String get emptyOfflineMessage;

  /// No description provided for @emptyOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved on this phone yet'**
  String get emptyOfflineTitle;

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

  /// No description provided for @errAccessRejected.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare refused the Client ID or the Client Secret'**
  String get errAccessRejected;

  /// No description provided for @errAuth.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password'**
  String get errAuth;

  /// No description provided for @errFileGone.
  ///
  /// In en, this message translates to:
  /// **'The file is no longer on the server. Try again to download it anew.'**
  String get errFileGone;

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
  /// **'The platform requires login. The server admin should refresh the cookies'**
  String get errPlatformBlocked;

  /// No description provided for @errPlatformBlockedCookies.
  ///
  /// In en, this message translates to:
  /// **'The platform requires login. Send it a cookies file from Settings → Cookies'**
  String get errPlatformBlockedCookies;

  /// No description provided for @errPollTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long. Try again.'**
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

  /// No description provided for @every30Minutes.
  ///
  /// In en, this message translates to:
  /// **'Every 30 minutes'**
  String get every30Minutes;

  /// No description provided for @everyHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every hour} other{Every {count} hours}}'**
  String everyHours(int count);

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get exitFullscreen;

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

  /// No description provided for @externalPlayerShort.
  ///
  /// In en, this message translates to:
  /// **'Another player'**
  String get externalPlayerShort;

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

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get fileSize;

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

  /// No description provided for @filtersOn.
  ///
  /// In en, this message translates to:
  /// **'Filters on'**
  String get filtersOn;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @foldersDisabled.
  ///
  /// In en, this message translates to:
  /// **'This server does not allow folders: CUSTOM_DIRS is off in its settings.'**
  String get foldersDisabled;

  /// No description provided for @foldersHelp.
  ///
  /// In en, this message translates to:
  /// **'A folder is made on the server, inside its downloads, and the clip is saved straight into it, where the network share and any other app see it. Leave it at \"No folder\" and nothing changes. For folders to work the server needs two things: CUSTOM_DIRS on, which is MeTube\'s default, and no outtmpl in YTDL_OPTIONS, which would save every file at the top whatever folder is chosen. To name files your way, use OUTPUT_TEMPLATE instead. The setup guide shows the lines.'**
  String get foldersHelp;

  /// No description provided for @foldersIgnored.
  ///
  /// In en, this message translates to:
  /// **'This server saves every file at the top of the downloads, whatever folder is chosen: its YTDL_OPTIONS has an outtmpl. The setup guide says how to move it to OUTPUT_TEMPLATE.'**
  String get foldersIgnored;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @followChannel.
  ///
  /// In en, this message translates to:
  /// **'Follow a channel'**
  String get followChannel;

  /// No description provided for @followingChannel.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingChannel;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @framesPerSecond.
  ///
  /// In en, this message translates to:
  /// **'{count} fps'**
  String framesPerSecond(int count);

  /// No description provided for @helpAboutField.
  ///
  /// In en, this message translates to:
  /// **'About this field'**
  String get helpAboutField;

  /// No description provided for @inPlaylists.
  ///
  /// In en, this message translates to:
  /// **'In playlists'**
  String get inPlaylists;

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

  /// No description provided for @jumpToNewest.
  ///
  /// In en, this message translates to:
  /// **'Go to the newest'**
  String get jumpToNewest;

  /// No description provided for @knownVideos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing known yet} =1{1 video known} other{{count} videos known}}'**
  String knownVideos(int count);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

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

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup {when}'**
  String lastBackup(String when);

  /// No description provided for @lastCheckedAt.
  ///
  /// In en, this message translates to:
  /// **'Last checked {when}'**
  String lastCheckedAt(String when);

  /// No description provided for @latestAdditions.
  ///
  /// In en, this message translates to:
  /// **'Latest additions'**
  String get latestAdditions;

  /// No description provided for @licensedUnder.
  ///
  /// In en, this message translates to:
  /// **'Licensed under GPL-3.0'**
  String get licensedUnder;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @listenInBackground.
  ///
  /// In en, this message translates to:
  /// **'Listen in the background'**
  String get listenInBackground;

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

  /// No description provided for @localUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Local server URL'**
  String get localUrlLabel;

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

  /// No description provided for @madeOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved for offline'**
  String get madeOffline;

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

  /// No description provided for @mediaAccessBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Android will not ask again. Turn on photos and videos for this app in the system settings, then come back.'**
  String get mediaAccessBlockedMessage;

  /// No description provided for @mediaAccessGrant.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get mediaAccessGrant;

  /// No description provided for @mediaAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your downloads are kept in the phone\'s Download folder, and Android needs your permission before the app can list them.'**
  String get mediaAccessMessage;

  /// No description provided for @mediaAccessOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get mediaAccessOpenSettings;

  /// No description provided for @mediaAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your media'**
  String get mediaAccessTitle;

  /// No description provided for @metubeCredit.
  ///
  /// In en, this message translates to:
  /// **'The self-hosted server this app is a client for'**
  String get metubeCredit;

  /// No description provided for @modeAutoNext.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modeAutoNext;

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

  /// No description provided for @moreChips.
  ///
  /// In en, this message translates to:
  /// **'More · {count}'**
  String moreChips(int count);

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

  /// No description provided for @neverChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get neverChecked;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder…'**
  String get newFolder;

  /// No description provided for @newFolderHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ai/Lessons'**
  String get newFolderHint;

  /// No description provided for @newFromSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new from a channel you follow} other{{count} new from the channels you follow}}'**
  String newFromSubscriptions(int count);

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

  /// No description provided for @noBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get noBackupsYet;

  /// No description provided for @noDownloads.
  ///
  /// In en, this message translates to:
  /// **'No downloads'**
  String get noDownloads;

  /// No description provided for @noDownloadsMessage.
  ///
  /// In en, this message translates to:
  /// **'Downloaded videos will appear here.\nShare a video link or use the Add URL button.'**
  String get noDownloadsMessage;

  /// No description provided for @noExternalPlayer.
  ///
  /// In en, this message translates to:
  /// **'No external player on this device'**
  String get noExternalPlayer;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get noFolder;

  /// No description provided for @noFolderHint.
  ///
  /// In en, this message translates to:
  /// **'At the top of the downloads'**
  String get noFolderHint;

  /// No description provided for @noLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No logs found'**
  String get noLogsFound;

  /// No description provided for @noPlayableSource.
  ///
  /// In en, this message translates to:
  /// **'This item has no playable source'**
  String get noPlayableSource;

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

  /// No description provided for @noVideosFound.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get noVideosFound;

  /// No description provided for @noWarranty.
  ///
  /// In en, this message translates to:
  /// **'Provided as is, without any warranty.'**
  String get noWarranty;

  /// No description provided for @notAffiliated.
  ///
  /// In en, this message translates to:
  /// **'Unofficial client, not affiliated with the MeTube project or yt-dlp, and not endorsed by them.'**
  String get notAffiliated;

  /// No description provided for @notEnoughSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough room on the phone: needs {needed}, {free} free'**
  String notEnoughSpace(String needed, String free);

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @notifyArrivals.
  ///
  /// In en, this message translates to:
  /// **'Tell me what arrives by itself'**
  String get notifyArrivals;

  /// No description provided for @notifyArrivalsDesc.
  ///
  /// In en, this message translates to:
  /// **'One notice when a followed channel\'s new videos land on the server. It appears when you open the app, return to it, or refresh the library, not while the app is in the background.'**
  String get notifyArrivalsDesc;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @nowPlayingCollapse.
  ///
  /// In en, this message translates to:
  /// **'Fold the player panel'**
  String get nowPlayingCollapse;

  /// No description provided for @nowPlayingExpand.
  ///
  /// In en, this message translates to:
  /// **'Show the player panel'**
  String get nowPlayingExpand;

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

  /// No description provided for @onlyNewVideos.
  ///
  /// In en, this message translates to:
  /// **'Only what appears from now on is downloaded. The videos already on the channel are left where they are.'**
  String get onlyNewVideos;

  /// No description provided for @openChannel.
  ///
  /// In en, this message translates to:
  /// **'Open channel'**
  String get openChannel;

  /// No description provided for @openInExternalPlayer.
  ///
  /// In en, this message translates to:
  /// **'Open in another player'**
  String get openInExternalPlayer;

  /// No description provided for @openOriginalLink.
  ///
  /// In en, this message translates to:
  /// **'Open original link'**
  String get openOriginalLink;

  /// No description provided for @ownFolder.
  ///
  /// In en, this message translates to:
  /// **'Save in its own folder'**
  String get ownFolder;

  /// No description provided for @ownFolderNote.
  ///
  /// In en, this message translates to:
  /// **'A folder in the server\'s downloads, which the network share and other apps see too. Only what arrives from now on goes there; what is already downloaded stays where it is.'**
  String get ownFolderNote;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

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

  /// No description provided for @pauseSubscription.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseSubscription;

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String percentValue(Object percent);

  /// No description provided for @phoneCopiesSection.
  ///
  /// In en, this message translates to:
  /// **'To this phone'**
  String get phoneCopiesSection;

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

  /// No description provided for @pictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture in picture'**
  String get pictureInPicture;

  /// No description provided for @pictureInPictureHelp.
  ///
  /// In en, this message translates to:
  /// **'When you leave the app while a video plays, it stays in a corner of the screen'**
  String get pictureInPictureHelp;

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

  /// No description provided for @platformOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get platformOther;

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

  /// No description provided for @playModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get playModeLabel;

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
  /// **'Playlist details'**
  String get playlistDetails;

  /// No description provided for @playlistEditHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a clip to move it. Swipe it aside to remove it.'**
  String get playlistEditHint;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'My playlist'**
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

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

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
  /// **'Up to 1080p'**
  String get quality1080;

  /// No description provided for @quality360.
  ///
  /// In en, this message translates to:
  /// **'Up to 360p'**
  String get quality360;

  /// No description provided for @quality480.
  ///
  /// In en, this message translates to:
  /// **'Up to 480p'**
  String get quality480;

  /// No description provided for @quality720.
  ///
  /// In en, this message translates to:
  /// **'Up to 720p'**
  String get quality720;

  /// No description provided for @qualityAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get qualityAudio;

  /// No description provided for @qualityBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get qualityBest;

  /// No description provided for @qualityHelper.
  ///
  /// In en, this message translates to:
  /// **'Used by quick download, by whole-playlist downloads, and by \"Download now\" in the clipboard bar, and it is the preselected option in the add-link sheet. So it matters whether or not quick download is on.'**
  String get qualityHelper;

  /// No description provided for @qualityReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the file…'**
  String get qualityReading;

  /// No description provided for @qualityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get qualityUnavailable;

  /// No description provided for @qualityVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get qualityVideo;

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
  /// **'Number {position} in line'**
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
  /// **'A shared or pasted link starts downloading immediately at the default quality, with no sheet. Numeric qualities are YouTube-only: anything else downloads at best quality, and an \"audio only\" default applies everywhere.'**
  String get quickDownloadHelp;

  /// No description provided for @quoteExtendHint.
  ///
  /// In en, this message translates to:
  /// **'Touch another line to take it in'**
  String get quoteExtendHint;

  /// No description provided for @quoteMomentLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link to this moment'**
  String get quoteMomentLink;

  /// No description provided for @quotePlayFrom.
  ///
  /// In en, this message translates to:
  /// **'Play from here'**
  String get quotePlayFrom;

  /// No description provided for @quoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quoteTitle;

  /// No description provided for @readingAsMarkdownHint.
  ///
  /// In en, this message translates to:
  /// **'Each paragraph with its time, linked to its moment'**
  String get readingAsMarkdownHint;

  /// No description provided for @readingAsPdfHint.
  ///
  /// In en, this message translates to:
  /// **'To print or keep'**
  String get readingAsPdfHint;

  /// No description provided for @readingAsSrtHint.
  ///
  /// In en, this message translates to:
  /// **'Line by line with its times, for any player'**
  String get readingAsSrtHint;

  /// No description provided for @readingAsText.
  ///
  /// In en, this message translates to:
  /// **'Text to read'**
  String get readingAsText;

  /// No description provided for @readingAsTextHint.
  ///
  /// In en, this message translates to:
  /// **'Paragraphs without times, to paste anywhere'**
  String get readingAsTextHint;

  /// No description provided for @readingHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a sentence to hear it from there'**
  String get readingHint;

  /// No description provided for @readingMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{About a minute to read} other{About {count} minutes to read}}'**
  String readingMinutes(int count);

  /// No description provided for @readingRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readingRead;

  /// No description provided for @readingShare.
  ///
  /// In en, this message translates to:
  /// **'Share the text'**
  String get readingShare;

  /// No description provided for @readingTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get readingTextSize;

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

  /// No description provided for @removedFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to remove: they are no longer failed} =1{Removed 1 failed download} other{Removed {count} failed downloads}}'**
  String removedFailed(int count);

  /// No description provided for @removeFailed.
  ///
  /// In en, this message translates to:
  /// **'Remove the failed'**
  String get removeFailed;

  /// No description provided for @removeFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Only downloads that failed leave the server\'s list. Everything that finished, which is what your library shows, stays exactly as it is.'**
  String get removeFailedBody;

  /// No description provided for @removeFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Remove 1 failed download?} other{Remove {count} failed downloads?}}'**
  String removeFailedTitle(int count);

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @removeLocalCopy.
  ///
  /// In en, this message translates to:
  /// **'Remove local copy'**
  String get removeLocalCopy;

  /// No description provided for @removeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Remove {count} unavailable'**
  String removeUnavailable(int count);

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

  /// No description provided for @reportBug.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get reportBug;

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
  /// **'Restore failed: the backup file is not valid'**
  String get restoreFailed;

  /// No description provided for @restorePickBody.
  ///
  /// In en, this message translates to:
  /// **'This phone has MeTube Lite downloads but no settings, as after a reinstall. If you kept a backup, choose it: the app writes them to Download/MeTube_Lite/backups.'**
  String get restorePickBody;

  /// No description provided for @restorePickChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup'**
  String get restorePickChoose;

  /// No description provided for @restorePickTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring back your settings?'**
  String get restorePickTitle;

  /// No description provided for @restoreServerLine.
  ///
  /// In en, this message translates to:
  /// **'Server in this backup: {server}'**
  String restoreServerLine(String server);

  /// No description provided for @restoreSettings.
  ///
  /// In en, this message translates to:
  /// **'Restore all data'**
  String get restoreSettings;

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

  /// No description provided for @resumeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeSubscription;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @retryAll.
  ///
  /// In en, this message translates to:
  /// **'Retry all'**
  String get retryAll;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
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

  /// No description provided for @searchLogs.
  ///
  /// In en, this message translates to:
  /// **'Search logs…'**
  String get searchLogs;

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
  /// **'Select all'**
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
  /// **'Server configuration'**
  String get serverConfiguration;

  /// No description provided for @serverFailuresLine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 download didn\'t finish on the server} other{{count} downloads didn\'t finish on the server}}'**
  String serverFailuresLine(int count);

  /// No description provided for @serverFailuresNote.
  ///
  /// In en, this message translates to:
  /// **'Stopped by the server with an error, whether added from this phone, a subscription or MeTube\'s own page.'**
  String get serverFailuresNote;

  /// No description provided for @serverFailuresTitle.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t finish on the server'**
  String get serverFailuresTitle;

  /// No description provided for @serverFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No files on the server} =1{1 file on the server} other{{count} files on the server}}'**
  String serverFilesCount(int count);

  /// No description provided for @serverHttpWarning.
  ///
  /// In en, this message translates to:
  /// **'An http:// address outside your home network sends the password unencrypted. From outside, use an https:// address.'**
  String get serverHttpWarning;

  /// No description provided for @serverKeepsFilesBody.
  ///
  /// In en, this message translates to:
  /// **'The history entry is removed but the file stays on disk, so the server fills up. Set DELETE_FILE_ON_TRASHCAN=true on the MeTube container.'**
  String get serverKeepsFilesBody;

  /// No description provided for @serverKeepsFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your server is not deleting the files'**
  String get serverKeepsFilesTitle;

  /// No description provided for @serverQueueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} =1{1 in the queue} other{{count} in the queue}}'**
  String serverQueueCount(int count);

  /// No description provided for @serverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Looks for MeTube on the Wi-Fi this phone is on, only when you tap.'**
  String get serverSearchHint;

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

  /// No description provided for @serverUnreachableLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Videos saved on this phone still play.'**
  String get serverUnreachableLocalHint;

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
  /// **'About the server URL'**
  String get serverUrlHelpTitle;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'http://192.168.1.5:8086 or https://domain.com'**
  String get serverUrlHint;

  /// No description provided for @serverUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Server URL is required'**
  String get serverUrlRequired;

  /// No description provided for @serverVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'MeTube {version}'**
  String serverVersionLabel(String version);

  /// No description provided for @serverVersionOutdated.
  ///
  /// In en, this message translates to:
  /// **'Update available: {latest}'**
  String serverVersionOutdated(String latest);

  /// No description provided for @serverVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Version unknown'**
  String get serverVersionUnknown;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// No description provided for @settingsDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsDownloads;

  /// No description provided for @settingsGroupApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsGroupApp;

  /// No description provided for @settingsGroupData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsGroupData;

  /// No description provided for @settingsGroupServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsGroupServer;

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settingsSaved;

  /// No description provided for @settingsTranscripts.
  ///
  /// In en, this message translates to:
  /// **'Transcripts & subtitles'**
  String get settingsTranscripts;

  /// No description provided for @settingsValueArrivals.
  ///
  /// In en, this message translates to:
  /// **'tells you what arrives'**
  String get settingsValueArrivals;

  /// No description provided for @settingsValueAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get settingsValueAuto;

  /// No description provided for @settingsValueChannels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No channels yet} =1{1 channel} other{{count} channels}}'**
  String settingsValueChannels(int count);

  /// No description provided for @settingsValueCloudflare.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare Access'**
  String get settingsValueCloudflare;

  /// No description provided for @settingsValueCompatOff.
  ///
  /// In en, this message translates to:
  /// **'Best compatibility: off'**
  String get settingsValueCompatOff;

  /// No description provided for @settingsValueCompatOn.
  ///
  /// In en, this message translates to:
  /// **'Best compatibility: on'**
  String get settingsValueCompatOn;

  /// No description provided for @settingsValueExternalNow.
  ///
  /// In en, this message translates to:
  /// **'external now'**
  String get settingsValueExternalNow;

  /// No description provided for @settingsValueLocalNow.
  ///
  /// In en, this message translates to:
  /// **'local now'**
  String get settingsValueLocalNow;

  /// No description provided for @settingsValueManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get settingsValueManual;

  /// No description provided for @settingsValueNoPassword.
  ///
  /// In en, this message translates to:
  /// **'no password'**
  String get settingsValueNoPassword;

  /// No description provided for @settingsValueNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet'**
  String get settingsValueNotSet;

  /// No description provided for @settingsValueOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsValueOff;

  /// No description provided for @settingsValueOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsValueOn;

  /// No description provided for @settingsValueQuick.
  ///
  /// In en, this message translates to:
  /// **'quick'**
  String get settingsValueQuick;

  /// No description provided for @settingsValueSubtitlesShown.
  ///
  /// In en, this message translates to:
  /// **'subtitles shown'**
  String get settingsValueSubtitlesShown;

  /// No description provided for @settingsValueWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi only'**
  String get settingsValueWifiOnly;

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

  /// No description provided for @shareGoesOn.
  ///
  /// In en, this message translates to:
  /// **'Still preparing in the background. The share menu opens when it is ready; its progress is in Downloads.'**
  String get shareGoesOn;

  /// No description provided for @shareLargeBody.
  ///
  /// In en, this message translates to:
  /// **'It downloads to this phone first, then the share menu opens.'**
  String get shareLargeBody;

  /// No description provided for @shareLargeTitle.
  ///
  /// In en, this message translates to:
  /// **'Download {size} to share?'**
  String shareLargeTitle(String size);

  /// No description provided for @shareLogs.
  ///
  /// In en, this message translates to:
  /// **'Share logs'**
  String get shareLogs;

  /// No description provided for @shareMessagingLimit.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp and Telegram take up to 2 GB; for larger files use Drive or Quick Share.'**
  String get shareMessagingLimit;

  /// No description provided for @shareOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening the share menu…'**
  String get shareOpening;

  /// No description provided for @shareOpeningHint.
  ///
  /// In en, this message translates to:
  /// **'A large file takes a few seconds to hand over.'**
  String get shareOpeningHint;

  /// No description provided for @sharePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing to share'**
  String get sharePreparing;

  /// No description provided for @shareProgressOf.
  ///
  /// In en, this message translates to:
  /// **'{received} of {total}'**
  String shareProgressOf(String received, String total);

  /// No description provided for @shareReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to share'**
  String get shareReady;

  /// No description provided for @shareSelected.
  ///
  /// In en, this message translates to:
  /// **'Share selected'**
  String get shareSelected;

  /// No description provided for @sharedLinksAdd.
  ///
  /// In en, this message translates to:
  /// **'Add them'**
  String get sharedLinksAdd;

  /// No description provided for @sharedLinksBody.
  ///
  /// In en, this message translates to:
  /// **'Each one goes to your server to download.'**
  String get sharedLinksBody;

  /// No description provided for @sharedLinksCapped.
  ///
  /// In en, this message translates to:
  /// **'Only the first {max} links were added.'**
  String sharedLinksCapped(int max);

  /// No description provided for @sharedLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 link?} other{Add {count} links?}}'**
  String sharedLinksTitle(int count);

  /// No description provided for @shortsFilter.
  ///
  /// In en, this message translates to:
  /// **'Shorts'**
  String get shortsFilter;

  /// No description provided for @showChannel.
  ///
  /// In en, this message translates to:
  /// **'Everything from {channel}'**
  String showChannel(String channel);

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

  /// No description provided for @sortAndFilter.
  ///
  /// In en, this message translates to:
  /// **'Sort and filter'**
  String get sortAndFilter;

  /// No description provided for @sortAndPlatform.
  ///
  /// In en, this message translates to:
  /// **'Sort and platform'**
  String get sortAndPlatform;

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

  /// No description provided for @startDownload.
  ///
  /// In en, this message translates to:
  /// **'Start download'**
  String get startDownload;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @streamingFromServer.
  ///
  /// In en, this message translates to:
  /// **'Streaming from the server'**
  String get streamingFromServer;

  /// No description provided for @subscriptionAdded.
  ///
  /// In en, this message translates to:
  /// **'Now following {name}'**
  String subscriptionAdded(String name);

  /// No description provided for @subscriptionName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get subscriptionName;

  /// No description provided for @subscriptionPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get subscriptionPaused;

  /// No description provided for @subscriptionQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality for this channel'**
  String get subscriptionQuality;

  /// No description provided for @subscriptionQualityHelp.
  ///
  /// In en, this message translates to:
  /// **'The server keeps the quality chosen when you follow, and does not let it be changed. To change it: Check now, then unfollow and follow again.\n\n\"Best\" can mean 4K in the AV1 format. Recent phones play it smoothly; if you see stuttering, your phone does not decode AV1 in hardware: choose 1080p, or turn on \"Best playback compatibility\" before following.'**
  String get subscriptionQualityHelp;

  /// No description provided for @subscriptionQualityNote.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be changed after following.'**
  String get subscriptionQualityNote;

  /// No description provided for @subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

  /// No description provided for @subscriptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No channels followed yet'**
  String get subscriptionsEmpty;

  /// No description provided for @subscriptionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Follow a channel and the server downloads each new video by itself, straight into your library. What is already on the channel stays where it is.'**
  String get subscriptionsEmptyBody;

  /// No description provided for @subscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Channels the server follows for you'**
  String get subscriptionsSubtitle;

  /// No description provided for @subscriptionsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This MeTube is older than subscriptions'**
  String get subscriptionsUnsupported;

  /// No description provided for @subscriptionsUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'Update the MeTube container to a release that has channel subscriptions, then come back here. Nothing else in the app is affected.'**
  String get subscriptionsUnsupportedBody;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @subtitlesBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get subtitlesBackground;

  /// No description provided for @subtitlesBackgroundFaint.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get subtitlesBackgroundFaint;

  /// No description provided for @subtitlesBackgroundHelp.
  ///
  /// In en, this message translates to:
  /// **'What sits behind the words. With none, each letter keeps a dark edge so it still reads over a bright picture.'**
  String get subtitlesBackgroundHelp;

  /// No description provided for @subtitlesBackgroundNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get subtitlesBackgroundNone;

  /// No description provided for @subtitlesBackgroundSolid.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get subtitlesBackgroundSolid;

  /// No description provided for @subtitlesHide.
  ///
  /// In en, this message translates to:
  /// **'Hide subtitles'**
  String get subtitlesHide;

  /// No description provided for @subtitlesInShorts.
  ///
  /// In en, this message translates to:
  /// **'Subtitles in shorts'**
  String get subtitlesInShorts;

  /// No description provided for @subtitlesInShortsHelp.
  ///
  /// In en, this message translates to:
  /// **'Off unless you turn it on: many shorts already carry their words in the picture.'**
  String get subtitlesInShortsHelp;

  /// No description provided for @subtitlesLanguage.
  ///
  /// In en, this message translates to:
  /// **'Subtitle language'**
  String get subtitlesLanguage;

  /// No description provided for @subtitlesShow.
  ///
  /// In en, this message translates to:
  /// **'Show subtitles'**
  String get subtitlesShow;

  /// No description provided for @subtitlesShowHelp.
  ///
  /// In en, this message translates to:
  /// **'Over the video, for clips that have a transcript. The CC button in the player does the same.'**
  String get subtitlesShowHelp;

  /// No description provided for @subtitlesSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get subtitlesSize;

  /// No description provided for @subtitlesSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get subtitlesSizeLarge;

  /// No description provided for @subtitlesSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get subtitlesSizeMedium;

  /// No description provided for @subtitlesSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get subtitlesSizeSmall;

  /// No description provided for @subtitlesStyleTip.
  ///
  /// In en, this message translates to:
  /// **'To change the size and background while you watch, long-press CC in the player.'**
  String get subtitlesStyleTip;

  /// No description provided for @syncDeviceQuiet.
  ///
  /// In en, this message translates to:
  /// **'Nothing has come from it for over two days. If it was in use, a sync app is probably paused or asleep, there or here: phones put apps they think unused to sleep.'**
  String get syncDeviceQuiet;

  /// No description provided for @syncPhoneCameBack.
  ///
  /// In en, this message translates to:
  /// **'This phone was away for more than 90 days, so your other devices\' data was taken first.'**
  String get syncPhoneCameBack;

  /// No description provided for @syncPhoneFailed.
  ///
  /// In en, this message translates to:
  /// **'The sync folder could not be read. Choose it again if it moved or its permission was taken back.'**
  String get syncPhoneFailed;

  /// No description provided for @syncPhoneForgetBody.
  ///
  /// In en, this message translates to:
  /// **'{device} will no longer be read. Its transcripts move to this phone\'s folder first, so none is lost. Use this for a device that was lost or sold.'**
  String syncPhoneForgetBody(String device);

  /// No description provided for @syncPhoneGuide.
  ///
  /// In en, this message translates to:
  /// **'At home: Syncthing-Fork (from F-Droid) on this phone and Syncthing on the computer, sharing one folder; set it to Wi‑Fi only to spare the battery. Through a cloud: FolderSync with the cloud folder the computer uses.'**
  String get syncPhoneGuide;

  /// No description provided for @syncPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Mirrors tags, favorites, lists, resume positions and transcripts with MeTube Ember on your computer, through a folder a sync app keeps in step. Nothing goes to any service from here.'**
  String get syncPhoneHint;

  /// No description provided for @syncPhoneNoOthers.
  ///
  /// In en, this message translates to:
  /// **'No other device in this folder yet. Turn sync on in MeTube Ember with the same folder.'**
  String get syncPhoneNoOthers;

  /// No description provided for @syncPhoneOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Nothing leaves this phone.'**
  String get syncPhoneOff;

  /// No description provided for @syncPhoneThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This phone: {name}'**
  String syncPhoneThisDevice(String name);

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync with the computer'**
  String get syncTitle;

  /// No description provided for @tagActionsHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a tag to rename or delete it.'**
  String get tagActionsHint;

  /// No description provided for @tagFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a tag to show its clips, again to hide them, and once more to let it go.'**
  String get tagFilterHint;

  /// No description provided for @tagLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can have up to {max} tags. Remove one in Manage tags to add another.'**
  String tagLimitReached(int max);

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

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @titleFilter.
  ///
  /// In en, this message translates to:
  /// **'Only download titles containing'**
  String get titleFilter;

  /// No description provided for @titleFilterHelp.
  ///
  /// In en, this message translates to:
  /// **'The server downloads a new video from this channel only if its title contains what you write here.\n\n• A plain word is enough: Episode\n• Any of several words: Episode|Part (the | means \"or\")\n• English is case-sensitive: episode does not match Episode. Write [Ee]pisode, or both words.\n\nA video the filter skips counts as seen for good: removing the filter later downloads what comes after, not what was skipped.'**
  String get titleFilterHelp;

  /// No description provided for @titleFilterHelper.
  ///
  /// In en, this message translates to:
  /// **'Several words: separate them with | . Leave empty for everything.'**
  String get titleFilterHelper;

  /// No description provided for @titleFilterHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Episode'**
  String get titleFilterHint;

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

  /// No description provided for @transcript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcript;

  /// No description provided for @transcriptFind.
  ///
  /// In en, this message translates to:
  /// **'Search the transcript'**
  String get transcriptFind;

  /// No description provided for @transcriptFull.
  ///
  /// In en, this message translates to:
  /// **'Full transcript'**
  String get transcriptFull;

  /// No description provided for @transcriptMatches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} =1{1 match} other{{count} matches}}'**
  String transcriptMatches(int count);

  /// No description provided for @transcriptNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get transcriptNextMatch;

  /// No description provided for @transcriptPeekHint.
  ///
  /// In en, this message translates to:
  /// **'Tap for the whole text'**
  String get transcriptPeekHint;

  /// No description provided for @transcriptPreviousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get transcriptPreviousMatch;

  /// No description provided for @transcriptSaidMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Said once more} other{Said {count} more times}}'**
  String transcriptSaidMore(int count);

  /// No description provided for @transcriptSwitchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch the transcript language'**
  String get transcriptSwitchLanguage;

  /// No description provided for @transcriptsClips.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No clips yet} =1{1 clip} other{{count} clips}}'**
  String transcriptsClips(int count);

  /// No description provided for @transcriptsDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get transcriptsDeleteAll;

  /// No description provided for @transcriptsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'They are removed from this phone. Only a file you exported can bring them back.'**
  String get transcriptsDeleteBody;

  /// No description provided for @transcriptsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete every transcript?'**
  String get transcriptsDeleteTitle;

  /// No description provided for @transcriptsDisableBody.
  ///
  /// In en, this message translates to:
  /// **'The saved transcripts ({size}) stay on this phone unless you delete them.'**
  String transcriptsDisableBody(String size);

  /// No description provided for @transcriptsDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop searching inside clips?'**
  String get transcriptsDisableTitle;

  /// No description provided for @transcriptsEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get transcriptsEnable;

  /// No description provided for @transcriptsEnableBody.
  ///
  /// In en, this message translates to:
  /// **'Before each YouTube clip you add is downloaded, the app fetches its words from your server, in the app\'s language and in English (up to 40 seconds), and keeps them on this phone only. Clips already in your library are included only if your server saved their subtitles beside them (the setup guide shows how). You can turn this off at any time.'**
  String get transcriptsEnableBody;

  /// No description provided for @transcriptsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get transcriptsExport;

  /// No description provided for @transcriptsExported.
  ///
  /// In en, this message translates to:
  /// **'Transcripts saved to: {path}'**
  String transcriptsExported(Object path);

  /// No description provided for @transcriptsHelp.
  ///
  /// In en, this message translates to:
  /// **'The app keeps the words said in each YouTube clip you add, so a library search also finds what was said inside your clips, not only their titles.\n\nThe words are fetched from your server just before the download and kept on this phone; the full backup does not include them. To move them to another phone, use Export here and Import there. An import adds to what is already here and deletes nothing.\n\nA server set to write subtitles beside each clip (one line in its configuration; the setup guide shows it) covers everything it downloads from then on, subscriptions and other sites included: the app reads those files on its own, in the app\'s language and in English.'**
  String get transcriptsHelp;

  /// No description provided for @transcriptsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get transcriptsImport;

  /// No description provided for @transcriptsImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file holds no transcripts.'**
  String get transcriptsImportInvalid;

  /// No description provided for @transcriptsImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 transcript} other{Imported {count} transcripts}}'**
  String transcriptsImported(int count);

  /// No description provided for @transcriptsKeep.
  ///
  /// In en, this message translates to:
  /// **'Stop and keep'**
  String get transcriptsKeep;

  /// No description provided for @transcriptsSaidInside.
  ///
  /// In en, this message translates to:
  /// **'Said inside clips'**
  String get transcriptsSaidInside;

  /// No description provided for @transcriptsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search inside clips'**
  String get transcriptsSearch;

  /// No description provided for @transcriptsSearchHelp.
  ///
  /// In en, this message translates to:
  /// **'Keeps the words of every YouTube clip you add, so you can search what was said.'**
  String get transcriptsSearchHelp;

  /// No description provided for @transcriptsStopAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Stop and delete'**
  String get transcriptsStopAndDelete;

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

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollow;

  /// No description provided for @unfollowConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unfollow {name}?'**
  String unfollowConfirm(String name);

  /// No description provided for @unfollowConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The server forgets which videos it has already seen. If you follow this channel again later, everything on it by then counts as seen, and what you missed is not filled in. Pausing keeps that memory.'**
  String get unfollowConfirmBody;

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

  /// No description provided for @updateAllowInstallBody.
  ///
  /// In en, this message translates to:
  /// **'Android needs your permission before the app can install its own updates. Grant it once in system settings, then tap Install again.'**
  String get updateAllowInstallBody;

  /// No description provided for @updateAllowInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow installing updates'**
  String get updateAllowInstallTitle;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates'**
  String get updateCheckFailed;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get updateChecking;

  /// No description provided for @updateCredentials.
  ///
  /// In en, this message translates to:
  /// **'Update credentials'**
  String get updateCredentials;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the update'**
  String get updateDownloadFailed;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get updateDownloading;

  /// No description provided for @updateFailedToStart.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the installer'**
  String get updateFailedToStart;

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get updateInstall;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNever.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get updateNever;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get updateNow;

  /// No description provided for @updateOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get updateOpenSystemSettings;

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to install'**
  String get updateReady;

  /// No description provided for @updateSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String updateSizeMb(String size);

  /// No description provided for @updateSkipVersion.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkipVersion;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version'**
  String get updateUpToDate;

  /// No description provided for @updateVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateVersionAvailable(String version);

  /// No description provided for @updateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateWhatsNew;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

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

  /// No description provided for @videoPlayer.
  ///
  /// In en, this message translates to:
  /// **'Video player'**
  String get videoPlayer;

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

  /// No description provided for @viewCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get viewCards;

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

  /// No description provided for @waitingForWifi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi'**
  String get waitingForWifi;

  /// No description provided for @whatsNewGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get whatsNewGotIt;

  /// No description provided for @whatsNewReleasePage.
  ///
  /// In en, this message translates to:
  /// **'Release page'**
  String get whatsNewReleasePage;

  /// No description provided for @whatsNewThisVersion.
  ///
  /// In en, this message translates to:
  /// **'What\'s new in this version'**
  String get whatsNewThisVersion;

  /// No description provided for @whatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new in {version}'**
  String whatsNewTitle(String version);

  /// No description provided for @whatsNewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'What changed in this version is on the release page.'**
  String get whatsNewUnavailable;

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

  /// No description provided for @yourChannels.
  ///
  /// In en, this message translates to:
  /// **'Your channels'**
  String get yourChannels;

  /// No description provided for @yourChannelsHint.
  ///
  /// In en, this message translates to:
  /// **'Followed in Settings or the player'**
  String get yourChannelsHint;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your library'**
  String get yourLibrary;

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

  /// No description provided for @ytdlpCredit.
  ///
  /// In en, this message translates to:
  /// **'The downloader MeTube runs'**
  String get ytdlpCredit;
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
