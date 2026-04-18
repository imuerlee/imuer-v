import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NebulaVPN'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @servers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get servers;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting...'**
  String get disconnecting;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @noServerSelected.
  ///
  /// In en, this message translates to:
  /// **'No Server Selected'**
  String get noServerSelected;

  /// No description provided for @tapToSelectServer.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a server'**
  String get tapToSelectServer;

  /// No description provided for @uploadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadSpeed;

  /// No description provided for @downloadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadSpeed;

  /// No description provided for @totalUpload.
  ///
  /// In en, this message translates to:
  /// **'Total Upload'**
  String get totalUpload;

  /// No description provided for @totalDownload.
  ///
  /// In en, this message translates to:
  /// **'Total Download'**
  String get totalDownload;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @serverList.
  ///
  /// In en, this message translates to:
  /// **'Server List'**
  String get serverList;

  /// No description provided for @serversCount.
  ///
  /// In en, this message translates to:
  /// **'{count} servers'**
  String serversCount(int count);

  /// No description provided for @testAll.
  ///
  /// In en, this message translates to:
  /// **'Test All'**
  String get testAll;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @clipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get clipboard;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServer;

  /// No description provided for @noServers.
  ///
  /// In en, this message translates to:
  /// **'No Servers'**
  String get noServers;

  /// No description provided for @addServerToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Add a server to get started'**
  String get addServerToGetStarted;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @serverName.
  ///
  /// In en, this message translates to:
  /// **'Server Name'**
  String get serverName;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @uuid.
  ///
  /// In en, this message translates to:
  /// **'UUID'**
  String get uuid;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @tcp.
  ///
  /// In en, this message translates to:
  /// **'TCP'**
  String get tcp;

  /// No description provided for @udp.
  ///
  /// In en, this message translates to:
  /// **'UDP'**
  String get udp;

  /// No description provided for @ws.
  ///
  /// In en, this message translates to:
  /// **'WebSocket'**
  String get ws;

  /// No description provided for @grpc.
  ///
  /// In en, this message translates to:
  /// **'gRPC'**
  String get grpc;

  /// No description provided for @tls.
  ///
  /// In en, this message translates to:
  /// **'TLS'**
  String get tls;

  /// No description provided for @reality.
  ///
  /// In en, this message translates to:
  /// **'Reality'**
  String get reality;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @sni.
  ///
  /// In en, this message translates to:
  /// **'SNI'**
  String get sni;

  /// No description provided for @alpn.
  ///
  /// In en, this message translates to:
  /// **'ALPN'**
  String get alpn;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprint;

  /// No description provided for @allowInsecure.
  ///
  /// In en, this message translates to:
  /// **'Allow Insecure'**
  String get allowInsecure;

  /// No description provided for @flow.
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get flow;

  /// No description provided for @publicKey.
  ///
  /// In en, this message translates to:
  /// **'Public Key'**
  String get publicKey;

  /// No description provided for @shortId.
  ///
  /// In en, this message translates to:
  /// **'Short ID'**
  String get shortId;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @method.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get method;

  /// No description provided for @plugin.
  ///
  /// In en, this message translates to:
  /// **'Plugin'**
  String get plugin;

  /// No description provided for @pluginOptions.
  ///
  /// In en, this message translates to:
  /// **'Plugin Options'**
  String get pluginOptions;

  /// No description provided for @obfs.
  ///
  /// In en, this message translates to:
  /// **'OBFS'**
  String get obfs;

  /// No description provided for @obfsPassword.
  ///
  /// In en, this message translates to:
  /// **'OBFS Password'**
  String get obfsPassword;

  /// No description provided for @mtu.
  ///
  /// In en, this message translates to:
  /// **'MTU'**
  String get mtu;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get privateKey;

  /// No description provided for @peerPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Peer Public Key'**
  String get peerPublicKey;

  /// No description provided for @presharedKey.
  ///
  /// In en, this message translates to:
  /// **'Preshared Key'**
  String get presharedKey;

  /// No description provided for @reserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get reserved;

  /// No description provided for @speedLimitUp.
  ///
  /// In en, this message translates to:
  /// **'Upload Speed Limit'**
  String get speedLimitUp;

  /// No description provided for @speedLimitDown.
  ///
  /// In en, this message translates to:
  /// **'Download Speed Limit'**
  String get speedLimitDown;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @authentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get authentication;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @subscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get subscriptionUrl;

  /// No description provided for @enterSubscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter subscription URL'**
  String get enterSubscriptionUrl;

  /// No description provided for @fetchSubscription.
  ///
  /// In en, this message translates to:
  /// **'Fetch Subscription'**
  String get fetchSubscription;

  /// No description provided for @noSubscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'No subscription URL'**
  String get noSubscriptionUrl;

  /// No description provided for @subscriptionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} servers'**
  String subscriptionSuccess(int count);

  /// No description provided for @noValidServersFound.
  ///
  /// In en, this message translates to:
  /// **'No valid servers found'**
  String get noValidServersFound;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrCode;

  /// No description provided for @pointCameraAtQrCode.
  ///
  /// In en, this message translates to:
  /// **'Point camera at QR code'**
  String get pointCameraAtQrCode;

  /// No description provided for @importFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Import from Clipboard'**
  String get importFromClipboard;

  /// No description provided for @importFromFile.
  ///
  /// In en, this message translates to:
  /// **'Import from File'**
  String get importFromFile;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} server(s)'**
  String importSuccess(int count);

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @autoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto Connect'**
  String get autoConnect;

  /// No description provided for @autoConnectDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically connect on app launch'**
  String get autoConnectDesc;

  /// No description provided for @autoStart.
  ///
  /// In en, this message translates to:
  /// **'Auto Start'**
  String get autoStart;

  /// No description provided for @autoStartDesc.
  ///
  /// In en, this message translates to:
  /// **'Start VPN when device boots'**
  String get autoStartDesc;

  /// No description provided for @killSwitch.
  ///
  /// In en, this message translates to:
  /// **'Kill Switch'**
  String get killSwitch;

  /// No description provided for @killSwitchDesc.
  ///
  /// In en, this message translates to:
  /// **'Block internet if VPN disconnects'**
  String get killSwitchDesc;

  /// No description provided for @customDns.
  ///
  /// In en, this message translates to:
  /// **'Custom DNS'**
  String get customDns;

  /// No description provided for @dnsFallback.
  ///
  /// In en, this message translates to:
  /// **'DNS Fallback'**
  String get dnsFallback;

  /// No description provided for @routing.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get routing;

  /// No description provided for @routingMode.
  ///
  /// In en, this message translates to:
  /// **'Routing Mode'**
  String get routingMode;

  /// No description provided for @geographicRouting.
  ///
  /// In en, this message translates to:
  /// **'Geographic Routing'**
  String get geographicRouting;

  /// No description provided for @bypassLan.
  ///
  /// In en, this message translates to:
  /// **'Bypass LAN'**
  String get bypassLan;

  /// No description provided for @bypassLanDesc.
  ///
  /// In en, this message translates to:
  /// **'Don\'t proxy local network'**
  String get bypassLanDesc;

  /// No description provided for @trafficStatistics.
  ///
  /// In en, this message translates to:
  /// **'Traffic Statistics'**
  String get trafficStatistics;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @dailyAverage.
  ///
  /// In en, this message translates to:
  /// **'Daily Average'**
  String get dailyAverage;

  /// No description provided for @sessionStatistics.
  ///
  /// In en, this message translates to:
  /// **'Session Statistics'**
  String get sessionStatistics;

  /// No description provided for @connectionDuration.
  ///
  /// In en, this message translates to:
  /// **'Connection Duration'**
  String get connectionDuration;

  /// No description provided for @speedHistory.
  ///
  /// In en, this message translates to:
  /// **'Speed History'**
  String get speedHistory;

  /// No description provided for @trafficOverview.
  ///
  /// In en, this message translates to:
  /// **'Traffic Overview'**
  String get trafficOverview;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogs;

  /// No description provided for @debugMode.
  ///
  /// In en, this message translates to:
  /// **'Debug Mode'**
  String get debugMode;

  /// No description provided for @debugModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable debug logging'**
  String get debugModeDesc;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get darkTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get lightTheme;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @connectionNotification.
  ///
  /// In en, this message translates to:
  /// **'Connection Notification'**
  String get connectionNotification;

  /// No description provided for @connectionNotificationDesc.
  ///
  /// In en, this message translates to:
  /// **'Show notification when connected'**
  String get connectionNotificationDesc;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @mux.
  ///
  /// In en, this message translates to:
  /// **'Multiplexing'**
  String get mux;

  /// No description provided for @muxCount.
  ///
  /// In en, this message translates to:
  /// **'Mux Count'**
  String get muxCount;

  /// No description provided for @xHttp.
  ///
  /// In en, this message translates to:
  /// **'XHTTP'**
  String get xHttp;

  /// No description provided for @localDns.
  ///
  /// In en, this message translates to:
  /// **'Local DNS'**
  String get localDns;

  /// No description provided for @proxyPort.
  ///
  /// In en, this message translates to:
  /// **'Proxy Port'**
  String get proxyPort;

  /// No description provided for @tunImplementation.
  ///
  /// In en, this message translates to:
  /// **'TUN Implementation'**
  String get tunImplementation;

  /// No description provided for @mixedPort.
  ///
  /// In en, this message translates to:
  /// **'Mixed Port'**
  String get mixedPort;

  /// No description provided for @enableDns.
  ///
  /// In en, this message translates to:
  /// **'Enable DNS'**
  String get enableDns;

  /// No description provided for @enableDnsDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable custom DNS configuration'**
  String get enableDnsDesc;

  /// No description provided for @ipv6Support.
  ///
  /// In en, this message translates to:
  /// **'IPv6 Support'**
  String get ipv6Support;

  /// No description provided for @ipv6SupportDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable IPv6 routing'**
  String get ipv6SupportDesc;

  /// No description provided for @routingGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global Proxy'**
  String get routingGlobal;

  /// No description provided for @primaryDns.
  ///
  /// In en, this message translates to:
  /// **'Primary DNS'**
  String get primaryDns;

  /// No description provided for @secondaryDns.
  ///
  /// In en, this message translates to:
  /// **'Secondary DNS'**
  String get secondaryDns;

  /// No description provided for @subscriptionName.
  ///
  /// In en, this message translates to:
  /// **'Subscription Name'**
  String get subscriptionName;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @confirmImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get confirmImport;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
