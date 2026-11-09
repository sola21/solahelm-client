import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
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
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

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
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'SolaHelm'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get navHome;

  /// No description provided for @navNodes.
  ///
  /// In ru, this message translates to:
  /// **'Узлы'**
  String get navNodes;

  /// No description provided for @navSubscriptions.
  ///
  /// In ru, this message translates to:
  /// **'Подписки'**
  String get navSubscriptions;

  /// No description provided for @navConnections.
  ///
  /// In ru, this message translates to:
  /// **'Соединения'**
  String get navConnections;

  /// No description provided for @navLogs.
  ///
  /// In ru, this message translates to:
  /// **'Журнал'**
  String get navLogs;

  /// No description provided for @navSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// No description provided for @statusDisconnected.
  ///
  /// In ru, this message translates to:
  /// **'Отключено'**
  String get statusDisconnected;

  /// No description provided for @statusConnected.
  ///
  /// In ru, this message translates to:
  /// **'Подключено'**
  String get statusConnected;

  /// No description provided for @statusConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Подключение…'**
  String get statusConnecting;

  /// No description provided for @tapToConnect.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы подключиться'**
  String get tapToConnect;

  /// No description provided for @connect.
  ///
  /// In ru, this message translates to:
  /// **'Подключить'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In ru, this message translates to:
  /// **'Отключить'**
  String get disconnect;

  /// No description provided for @connectedFor.
  ///
  /// In ru, this message translates to:
  /// **'{time} · ядро {core}'**
  String connectedFor(String time, String core);

  /// No description provided for @coreAutoChip.
  ///
  /// In ru, this message translates to:
  /// **'{core} · авто'**
  String coreAutoChip(String core);

  /// No description provided for @coreChosenAuto.
  ///
  /// In ru, this message translates to:
  /// **'ядро {core} выбрано автоматически'**
  String coreChosenAuto(String core);

  /// No description provided for @coreChosenManual.
  ///
  /// In ru, this message translates to:
  /// **'ядро {core} закреплено в настройках'**
  String coreChosenManual(String core);

  /// No description provided for @modeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Режим'**
  String get modeLabel;

  /// No description provided for @modeTun.
  ///
  /// In ru, this message translates to:
  /// **'TUN'**
  String get modeTun;

  /// No description provided for @modeSystemProxy.
  ///
  /// In ru, this message translates to:
  /// **'Системный прокси'**
  String get modeSystemProxy;

  /// No description provided for @modePortOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только порт {port}'**
  String modePortOnly(int port);

  /// No description provided for @metricNode.
  ///
  /// In ru, this message translates to:
  /// **'Узел'**
  String get metricNode;

  /// No description provided for @metricLatency.
  ///
  /// In ru, this message translates to:
  /// **'Задержка'**
  String get metricLatency;

  /// No description provided for @metricSpeed.
  ///
  /// In ru, this message translates to:
  /// **'Скорость'**
  String get metricSpeed;

  /// No description provided for @metricTraffic.
  ///
  /// In ru, this message translates to:
  /// **'Трафик'**
  String get metricTraffic;

  /// No description provided for @kbps.
  ///
  /// In ru, this message translates to:
  /// **'{value} КБ/с'**
  String kbps(int value);

  /// No description provided for @gb.
  ///
  /// In ru, this message translates to:
  /// **'{value} ГБ'**
  String gb(String value);

  /// No description provided for @trafficOf.
  ///
  /// In ru, this message translates to:
  /// **'{used} из {total}'**
  String trafficOf(String used, String total);

  /// No description provided for @groupLabel.
  ///
  /// In ru, this message translates to:
  /// **'Группа: {name}'**
  String groupLabel(String name);

  /// No description provided for @groupAuto.
  ///
  /// In ru, this message translates to:
  /// **'Авто (быстрейший)'**
  String get groupAuto;

  /// No description provided for @ping.
  ///
  /// In ru, this message translates to:
  /// **'Пинг'**
  String get ping;

  /// No description provided for @pingMs.
  ///
  /// In ru, this message translates to:
  /// **'{ms} мс'**
  String pingMs(int ms);

  /// No description provided for @pingTimeout.
  ///
  /// In ru, this message translates to:
  /// **'нет ответа'**
  String get pingTimeout;

  /// No description provided for @pingUnknown.
  ///
  /// In ru, this message translates to:
  /// **'—'**
  String get pingUnknown;

  /// No description provided for @recentConnections.
  ///
  /// In ru, this message translates to:
  /// **'Последние соединения'**
  String get recentConnections;

  /// No description provided for @routeDirect.
  ///
  /// In ru, this message translates to:
  /// **'напрямую'**
  String get routeDirect;

  /// No description provided for @routeVia.
  ///
  /// In ru, this message translates to:
  /// **'VPN · {node}'**
  String routeVia(String node);

  /// No description provided for @addSubscription.
  ///
  /// In ru, this message translates to:
  /// **'Добавить подписку'**
  String get addSubscription;

  /// No description provided for @subscriptionUrl.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на подписку'**
  String get subscriptionUrl;

  /// No description provided for @subscriptionUrlHint.
  ///
  /// In ru, this message translates to:
  /// **'https://panel.example.org/…/sub/…'**
  String get subscriptionUrlHint;

  /// No description provided for @add.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @errorUrlEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите ссылку'**
  String get errorUrlEmpty;

  /// No description provided for @errorUrlInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка должна начинаться с http:// или https://'**
  String get errorUrlInvalid;

  /// No description provided for @scanQr.
  ///
  /// In ru, this message translates to:
  /// **'QR-код'**
  String get scanQr;

  /// No description provided for @pasteClipboard.
  ///
  /// In ru, this message translates to:
  /// **'Вставить'**
  String get pasteClipboard;

  /// No description provided for @clipboardEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В буфере обмена нет ссылки'**
  String get clipboardEmpty;

  /// No description provided for @subPending.
  ///
  /// In ru, this message translates to:
  /// **'Загрузится, когда подключим ядро'**
  String get subPending;

  /// No description provided for @expiresOn.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String expiresOn(String date);

  /// No description provided for @noExpiry.
  ///
  /// In ru, this message translates to:
  /// **'бессрочно'**
  String get noExpiry;

  /// No description provided for @unlimited.
  ///
  /// In ru, this message translates to:
  /// **'без лимита'**
  String get unlimited;

  /// No description provided for @formatSingBox.
  ///
  /// In ru, this message translates to:
  /// **'sing-box JSON'**
  String get formatSingBox;

  /// No description provided for @formatClash.
  ///
  /// In ru, this message translates to:
  /// **'Clash YAML'**
  String get formatClash;

  /// No description provided for @formatLinks.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} ссылка} few{{count} ссылки} many{{count} ссылок} other{{count} ссылки}}'**
  String formatLinks(int count);

  /// No description provided for @linksSkipped.
  ///
  /// In ru, this message translates to:
  /// **'пропущены: {protocols}'**
  String linksSkipped(String protocols);

  /// No description provided for @reasonByFormat.
  ///
  /// In ru, this message translates to:
  /// **'ядро выбрано по формату'**
  String get reasonByFormat;

  /// No description provided for @rulesTemplate.
  ///
  /// In ru, this message translates to:
  /// **'правила «{name}»'**
  String rulesTemplate(String name);

  /// No description provided for @settingsTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get languageSystem;

  /// No description provided for @settingsCore.
  ///
  /// In ru, this message translates to:
  /// **'Ядро'**
  String get settingsCore;

  /// No description provided for @coreAuto.
  ///
  /// In ru, this message translates to:
  /// **'Авто'**
  String get coreAuto;

  /// No description provided for @coreHint.
  ///
  /// In ru, this message translates to:
  /// **'В режиме «Авто» ядро выбирается по формату подписки и протоколам. Если протокол есть только в одном ядре, будет выбрано оно.'**
  String get coreHint;

  /// No description provided for @settingsAbout.
  ///
  /// In ru, this message translates to:
  /// **'О программе'**
  String get settingsAbout;

  /// No description provided for @coreVersions.
  ///
  /// In ru, this message translates to:
  /// **'sing-box {sb} · mihomo {mh}'**
  String coreVersions(String sb, String mh);

  /// No description provided for @demoBanner.
  ///
  /// In ru, this message translates to:
  /// **'Демо-данные: интерфейс ещё не подключён к ядру'**
  String get demoBanner;

  /// No description provided for @comingSoon.
  ///
  /// In ru, this message translates to:
  /// **'Раздел появится, когда интерфейс подключим к ядру.'**
  String get comingSoon;

  /// No description provided for @nodesNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Подключитесь, чтобы увидеть узлы подписки.'**
  String get nodesNotConnected;

  /// No description provided for @groupAutoHint.
  ///
  /// In ru, this message translates to:
  /// **'Эта группа выбирает узел сама по задержке.'**
  String get groupAutoHint;

  /// No description provided for @noSubscriptions.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте подписку — ссылку из кабинета вашей панели.'**
  String get noSubscriptions;

  /// No description provided for @noSubscriptionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет подписок'**
  String get noSubscriptionsTitle;

  /// No description provided for @needSubscription.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте подписку'**
  String get needSubscription;

  /// No description provided for @refresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get refresh;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @subscriptionAdded.
  ///
  /// In ru, this message translates to:
  /// **'Подписка добавлена'**
  String get subscriptionAdded;

  /// No description provided for @updatedAt.
  ///
  /// In ru, this message translates to:
  /// **'обновлено {time}'**
  String updatedAt(String time);

  /// No description provided for @localPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт 127.0.0.1:{port}'**
  String localPort(int port);

  /// No description provided for @adminBadge.
  ///
  /// In ru, this message translates to:
  /// **'администратор'**
  String get adminBadge;

  /// No description provided for @coreMissing.
  ///
  /// In ru, this message translates to:
  /// **'Не найден solahelm-core рядом с приложением — показаны демо-данные'**
  String get coreMissing;

  /// No description provided for @errorPrefix.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {message}'**
  String errorPrefix(String message);

  /// No description provided for @noConnections.
  ///
  /// In ru, this message translates to:
  /// **'Соединений пока нет.'**
  String get noConnections;

  /// No description provided for @connectionsHint.
  ///
  /// In ru, this message translates to:
  /// **'Активные соединения через ядро: куда и через какой узел.'**
  String get connectionsHint;

  /// No description provided for @trafficUnlimited.
  ///
  /// In ru, this message translates to:
  /// **'{used} · без лимита'**
  String trafficUnlimited(String used);

  /// No description provided for @groupSelector.
  ///
  /// In ru, this message translates to:
  /// **'ручной выбор'**
  String get groupSelector;

  /// No description provided for @groupUrlTest.
  ///
  /// In ru, this message translates to:
  /// **'автовыбор по задержке'**
  String get groupUrlTest;

  /// No description provided for @groupFallback.
  ///
  /// In ru, this message translates to:
  /// **'резерв: первый рабочий'**
  String get groupFallback;

  /// No description provided for @groupLoadBalance.
  ///
  /// In ru, this message translates to:
  /// **'балансировка'**
  String get groupLoadBalance;

  /// No description provided for @logsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Журнал пуст. Строки ядра появятся после подключения.'**
  String get logsEmpty;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// No description provided for @pause.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get resume;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// No description provided for @copy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get copied;

  /// No description provided for @levelAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get levelAll;

  /// No description provided for @connActive.
  ///
  /// In ru, this message translates to:
  /// **'Активные'**
  String get connActive;

  /// No description provided for @connClosed.
  ///
  /// In ru, this message translates to:
  /// **'Закрытые'**
  String get connClosed;

  /// No description provided for @processesCount.
  ///
  /// In ru, this message translates to:
  /// **'Процессов: {n}'**
  String processesCount(int n);

  /// No description provided for @filter.
  ///
  /// In ru, this message translates to:
  /// **'Фильтр'**
  String get filter;

  /// No description provided for @sortDownload.
  ///
  /// In ru, this message translates to:
  /// **'Скачано'**
  String get sortDownload;

  /// No description provided for @sortUpload.
  ///
  /// In ru, this message translates to:
  /// **'Отдано'**
  String get sortUpload;

  /// No description provided for @sortTime.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get sortTime;

  /// No description provided for @sortHost.
  ///
  /// In ru, this message translates to:
  /// **'Хост'**
  String get sortHost;

  /// No description provided for @sortCount.
  ///
  /// In ru, this message translates to:
  /// **'Соединений'**
  String get sortCount;

  /// No description provided for @byProcess.
  ///
  /// In ru, this message translates to:
  /// **'По процессам'**
  String get byProcess;

  /// No description provided for @flatList.
  ///
  /// In ru, this message translates to:
  /// **'Списком'**
  String get flatList;

  /// No description provided for @closeAll.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть все'**
  String get closeAll;

  /// No description provided for @closeConnection.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть соединение'**
  String get closeConnection;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @secondsAgo.
  ///
  /// In ru, this message translates to:
  /// **'{n} с назад'**
  String secondsAgo(int n);

  /// No description provided for @minutesAgo.
  ///
  /// In ru, this message translates to:
  /// **'{n} мин назад'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In ru, this message translates to:
  /// **'{n} ч назад'**
  String hoursAgo(int n);

  /// No description provided for @secTraffic.
  ///
  /// In ru, this message translates to:
  /// **'Трафик'**
  String get secTraffic;

  /// No description provided for @upSpeed.
  ///
  /// In ru, this message translates to:
  /// **'Скорость отдачи'**
  String get upSpeed;

  /// No description provided for @downSpeed.
  ///
  /// In ru, this message translates to:
  /// **'Скорость скачивания'**
  String get downSpeed;

  /// No description provided for @uploaded.
  ///
  /// In ru, this message translates to:
  /// **'Отдано'**
  String get uploaded;

  /// No description provided for @downloaded.
  ///
  /// In ru, this message translates to:
  /// **'Скачано'**
  String get downloaded;

  /// No description provided for @secRouting.
  ///
  /// In ru, this message translates to:
  /// **'Маршрутизация'**
  String get secRouting;

  /// No description provided for @rule.
  ///
  /// In ru, this message translates to:
  /// **'Правило'**
  String get rule;

  /// No description provided for @chain.
  ///
  /// In ru, this message translates to:
  /// **'Цепочка прокси'**
  String get chain;

  /// No description provided for @connType.
  ///
  /// In ru, this message translates to:
  /// **'Тип подключения'**
  String get connType;

  /// No description provided for @secNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Сеть'**
  String get secNetwork;

  /// No description provided for @host.
  ///
  /// In ru, this message translates to:
  /// **'Хост'**
  String get host;

  /// No description provided for @destIp.
  ///
  /// In ru, this message translates to:
  /// **'IP назначения'**
  String get destIp;

  /// No description provided for @srcIp.
  ///
  /// In ru, this message translates to:
  /// **'IP источника'**
  String get srcIp;

  /// No description provided for @srcPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт источника'**
  String get srcPort;

  /// No description provided for @destPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт назначения'**
  String get destPort;

  /// No description provided for @remote.
  ///
  /// In ru, this message translates to:
  /// **'Удалённое назначение'**
  String get remote;

  /// No description provided for @secProcess.
  ///
  /// In ru, this message translates to:
  /// **'Процесс'**
  String get secProcess;

  /// No description provided for @processName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get processName;

  /// No description provided for @processPath.
  ///
  /// In ru, this message translates to:
  /// **'Путь'**
  String get processPath;

  /// No description provided for @started.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get started;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @statusActive.
  ///
  /// In ru, this message translates to:
  /// **'Активно'**
  String get statusActive;

  /// No description provided for @statusClosed.
  ///
  /// In ru, this message translates to:
  /// **'Закрыто'**
  String get statusClosed;

  /// No description provided for @clearClosed.
  ///
  /// In ru, this message translates to:
  /// **'Очистить закрытые'**
  String get clearClosed;

  /// No description provided for @settingsBehavior.
  ///
  /// In ru, this message translates to:
  /// **'Поведение'**
  String get settingsBehavior;

  /// No description provided for @closeToTray.
  ///
  /// In ru, this message translates to:
  /// **'Сворачивать в трей при закрытии окна'**
  String get closeToTray;

  /// No description provided for @launchAtStartup.
  ///
  /// In ru, this message translates to:
  /// **'Запускать вместе с Windows'**
  String get launchAtStartup;

  /// No description provided for @startMinimized.
  ///
  /// In ru, this message translates to:
  /// **'Запускать свёрнутым в трей'**
  String get startMinimized;

  /// No description provided for @autoConnect.
  ///
  /// In ru, this message translates to:
  /// **'Подключаться при запуске'**
  String get autoConnect;

  /// No description provided for @autoConnectTunNote.
  ///
  /// In ru, this message translates to:
  /// **'В режиме TUN при автоподключении Windows спросит права администратора.'**
  String get autoConnectTunNote;

  /// No description provided for @trayShow.
  ///
  /// In ru, this message translates to:
  /// **'Открыть SolaHelm'**
  String get trayShow;

  /// No description provided for @trayExit.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get trayExit;

  /// No description provided for @trayModeMenu.
  ///
  /// In ru, this message translates to:
  /// **'Режим подключения ({mode})'**
  String trayModeMenu(String mode);

  /// No description provided for @routingMenu.
  ///
  /// In ru, this message translates to:
  /// **'Маршрутизация ({mode})'**
  String routingMenu(String mode);

  /// No description provided for @routingRule.
  ///
  /// In ru, this message translates to:
  /// **'Правила'**
  String get routingRule;

  /// No description provided for @routingGlobal.
  ///
  /// In ru, this message translates to:
  /// **'Глобально'**
  String get routingGlobal;

  /// No description provided for @routingDirect.
  ///
  /// In ru, this message translates to:
  /// **'Напрямую'**
  String get routingDirect;

  /// No description provided for @routingLabel.
  ///
  /// In ru, this message translates to:
  /// **'Маршрутизация'**
  String get routingLabel;

  /// No description provided for @notElevated.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для TUN: Windows не разрешил запустить ядро от имени администратора. Подтвердите запрос или выберите «Системный прокси».'**
  String get notElevated;

  /// No description provided for @navRules.
  ///
  /// In ru, this message translates to:
  /// **'Правила'**
  String get navRules;

  /// No description provided for @importFile.
  ///
  /// In ru, this message translates to:
  /// **'Файл'**
  String get importFile;

  /// No description provided for @pastedName.
  ///
  /// In ru, this message translates to:
  /// **'Из буфера {date}'**
  String pastedName(String date);

  /// No description provided for @profileAdded.
  ///
  /// In ru, this message translates to:
  /// **'Профиль добавлен'**
  String get profileAdded;

  /// No description provided for @menuOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть и редактировать'**
  String get menuOpen;

  /// No description provided for @menuRules.
  ///
  /// In ru, this message translates to:
  /// **'Правила'**
  String get menuRules;

  /// No description provided for @rename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get rename;

  /// No description provided for @nameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get nameLabel;

  /// No description provided for @sourceFile.
  ///
  /// In ru, this message translates to:
  /// **'файл'**
  String get sourceFile;

  /// No description provided for @sourcePasted.
  ///
  /// In ru, this message translates to:
  /// **'вставлен'**
  String get sourcePasted;

  /// No description provided for @editedBadge.
  ///
  /// In ru, this message translates to:
  /// **'изменён вручную'**
  String get editedBadge;

  /// No description provided for @rulesBadge.
  ///
  /// In ru, this message translates to:
  /// **'свои правила'**
  String get rulesBadge;

  /// No description provided for @check.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get check;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get saved;

  /// No description provided for @checkOk.
  ///
  /// In ru, this message translates to:
  /// **'Конфиг в порядке: {format}, ядро {core}'**
  String checkOk(String format, String core);

  /// No description provided for @checkOkLinks.
  ///
  /// In ru, this message translates to:
  /// **'Ссылки в порядке: {n} прокси, ядро mihomo'**
  String checkOkLinks(int n);

  /// No description provided for @editedWarning.
  ///
  /// In ru, this message translates to:
  /// **'Профиль по ссылке: при обновлении подписки правки в тексте будут заменены. Свои правила задавайте в «Правилах», они сохраняются отдельно.'**
  String get editedWarning;

  /// No description provided for @unsavedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменения не сохранены'**
  String get unsavedTitle;

  /// No description provided for @discard.
  ///
  /// In ru, this message translates to:
  /// **'Не сохранять'**
  String get discard;

  /// No description provided for @rulesEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get rulesEdit;

  /// No description provided for @rulesActive.
  ///
  /// In ru, this message translates to:
  /// **'Действующие правила'**
  String get rulesActive;

  /// No description provided for @rulesOfProfile.
  ///
  /// In ru, this message translates to:
  /// **'Правила профиля'**
  String get rulesOfProfile;

  /// No description provided for @rulesNone.
  ///
  /// In ru, this message translates to:
  /// **'Правил нет'**
  String get rulesNone;

  /// No description provided for @rulesCount.
  ///
  /// In ru, this message translates to:
  /// **'Правил: {n}'**
  String rulesCount(int n);

  /// No description provided for @ruleType.
  ///
  /// In ru, this message translates to:
  /// **'Тип правила'**
  String get ruleType;

  /// No description provided for @rulePayload.
  ///
  /// In ru, this message translates to:
  /// **'Параметр'**
  String get rulePayload;

  /// No description provided for @ruleTarget.
  ///
  /// In ru, this message translates to:
  /// **'Прокси'**
  String get ruleTarget;

  /// No description provided for @addTop.
  ///
  /// In ru, this message translates to:
  /// **'В начало'**
  String get addTop;

  /// No description provided for @addBottom.
  ///
  /// In ru, this message translates to:
  /// **'В конец'**
  String get addBottom;

  /// No description provided for @asText.
  ///
  /// In ru, this message translates to:
  /// **'Текстом'**
  String get asText;

  /// No description provided for @asList.
  ///
  /// In ru, this message translates to:
  /// **'Списком'**
  String get asList;

  /// No description provided for @rulesHintReplace.
  ///
  /// In ru, this message translates to:
  /// **'Список целиком заменяет правила профиля и хранится отдельно от подписки: обновление его не сбросит.'**
  String get rulesHintReplace;

  /// No description provided for @rulesHintPrepend.
  ///
  /// In ru, this message translates to:
  /// **'Профиль sing-box: ваши правила встают перед правилами профиля. Правила самого профиля ниже, они только для чтения.'**
  String get rulesHintPrepend;

  /// No description provided for @resetRules.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть правила профиля'**
  String get resetRules;

  /// No description provided for @profileRulesReadonly.
  ///
  /// In ru, this message translates to:
  /// **'Правила профиля (только чтение)'**
  String get profileRulesReadonly;

  /// No description provided for @searchRules.
  ///
  /// In ru, this message translates to:
  /// **'Поиск правил'**
  String get searchRules;

  /// No description provided for @ruleInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Неверное правило в строке {n}: {line}'**
  String ruleInvalid(int n, String line);

  /// No description provided for @rulesSaved.
  ///
  /// In ru, this message translates to:
  /// **'Правила сохранены'**
  String get rulesSaved;

  /// No description provided for @payloadEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите параметр'**
  String get payloadEmpty;

  /// No description provided for @addRuleFor.
  ///
  /// In ru, this message translates to:
  /// **'Правило'**
  String get addRuleFor;

  /// No description provided for @ruleDirect.
  ///
  /// In ru, this message translates to:
  /// **'Напрямую'**
  String get ruleDirect;

  /// No description provided for @ruleProxy.
  ///
  /// In ru, this message translates to:
  /// **'Через VPN'**
  String get ruleProxy;

  /// No description provided for @ruleReject.
  ///
  /// In ru, this message translates to:
  /// **'Блокировать'**
  String get ruleReject;

  /// No description provided for @ruleAddedFor.
  ///
  /// In ru, this message translates to:
  /// **'Правило для {what} добавлено'**
  String ruleAddedFor(String what);

  /// No description provided for @rulesEditorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Правила: {name}'**
  String rulesEditorTitle(String name);

  /// No description provided for @rulesNotConnectedHint.
  ///
  /// In ru, this message translates to:
  /// **'Показаны правила профиля. Подключитесь, чтобы видеть правила, которые применило ядро.'**
  String get rulesNotConnectedHint;

  /// No description provided for @formatLinksShort.
  ///
  /// In ru, this message translates to:
  /// **'Ссылки'**
  String get formatLinksShort;

  /// No description provided for @statusDisconnecting.
  ///
  /// In ru, this message translates to:
  /// **'Отключение…'**
  String get statusDisconnecting;

  /// No description provided for @trayRestart.
  ///
  /// In ru, this message translates to:
  /// **'Перезапустить'**
  String get trayRestart;

  /// No description provided for @settingsConnection.
  ///
  /// In ru, this message translates to:
  /// **'Подключение и TUN'**
  String get settingsConnection;

  /// No description provided for @settingsConnectionHint.
  ///
  /// In ru, this message translates to:
  /// **'Стек и маршруты TUN, исключения системного прокси, порты, доступ из локальной сети'**
  String get settingsConnectionHint;

  /// No description provided for @settingsCoreAdv.
  ///
  /// In ru, this message translates to:
  /// **'Ядро'**
  String get settingsCoreAdv;

  /// No description provided for @settingsCoreAdvHint.
  ///
  /// In ru, this message translates to:
  /// **'IPv6, уровень логов, определение процессов, версии ядер'**
  String get settingsCoreAdvHint;

  /// No description provided for @reapplyHint.
  ///
  /// In ru, this message translates to:
  /// **'Изменения применятся после переподключения.'**
  String get reapplyHint;

  /// No description provided for @reapply.
  ///
  /// In ru, this message translates to:
  /// **'Переподключить'**
  String get reapply;

  /// No description provided for @secTun.
  ///
  /// In ru, this message translates to:
  /// **'TUN'**
  String get secTun;

  /// No description provided for @manageTun.
  ///
  /// In ru, this message translates to:
  /// **'Управлять настройками TUN'**
  String get manageTun;

  /// No description provided for @manageTunOff.
  ///
  /// In ru, this message translates to:
  /// **'Используются настройки профиля (стек gVisor, без запросов брандмауэра).'**
  String get manageTunOff;

  /// No description provided for @tunStack.
  ///
  /// In ru, this message translates to:
  /// **'Стек'**
  String get tunStack;

  /// No description provided for @tunStackHint.
  ///
  /// In ru, this message translates to:
  /// **'gVisor не открывает портов и не вызывает запрос брандмауэра. Mixed и System быстрее, но Windows может спросить разрешение.'**
  String get tunStackHint;

  /// No description provided for @strictRoute.
  ///
  /// In ru, this message translates to:
  /// **'Строгая маршрутизация'**
  String get strictRoute;

  /// No description provided for @strictRouteHint.
  ///
  /// In ru, this message translates to:
  /// **'Не даёт DNS-запросам уходить мимо туннеля.'**
  String get strictRouteHint;

  /// No description provided for @mtu.
  ///
  /// In ru, this message translates to:
  /// **'MTU'**
  String get mtu;

  /// No description provided for @routeExclude.
  ///
  /// In ru, this message translates to:
  /// **'Исключить сети из TUN'**
  String get routeExclude;

  /// No description provided for @routeExcludeHint.
  ///
  /// In ru, this message translates to:
  /// **'Эти сети идут напрямую, мимо туннеля: локальная сеть, RDP, принтеры.'**
  String get routeExcludeHint;

  /// No description provided for @addNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Добавить сеть'**
  String get addNetwork;

  /// No description provided for @networkHint.
  ///
  /// In ru, this message translates to:
  /// **'192.168.1.0/24'**
  String get networkHint;

  /// No description provided for @secSysProxy.
  ///
  /// In ru, this message translates to:
  /// **'Системный прокси'**
  String get secSysProxy;

  /// No description provided for @proxyBypass.
  ///
  /// In ru, this message translates to:
  /// **'Исключения системного прокси'**
  String get proxyBypass;

  /// No description provided for @proxyBypassHint.
  ///
  /// In ru, this message translates to:
  /// **'Адреса, к которым программы обращаются напрямую. Можно маски: 192.168.*, *.local, <local>.'**
  String get proxyBypassHint;

  /// No description provided for @addException.
  ///
  /// In ru, this message translates to:
  /// **'Добавить исключение'**
  String get addException;

  /// No description provided for @restoreDefaults.
  ///
  /// In ru, this message translates to:
  /// **'Стандартный список'**
  String get restoreDefaults;

  /// No description provided for @secPorts.
  ///
  /// In ru, this message translates to:
  /// **'Порты'**
  String get secPorts;

  /// No description provided for @mixedPort.
  ///
  /// In ru, this message translates to:
  /// **'Смешанный порт (HTTP + SOCKS)'**
  String get mixedPort;

  /// No description provided for @mixedPortHint.
  ///
  /// In ru, this message translates to:
  /// **'Если порт занят, будет взят следующий свободный.'**
  String get mixedPortHint;

  /// No description provided for @allowLan.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить подключения из локальной сети'**
  String get allowLan;

  /// No description provided for @allowLanHint.
  ///
  /// In ru, this message translates to:
  /// **'Другие устройства смогут использовать прокси этого компьютера. Windows может спросить разрешение брандмауэра.'**
  String get allowLanHint;

  /// No description provided for @lanAddresses.
  ///
  /// In ru, this message translates to:
  /// **'Адреса для других устройств: {list}'**
  String lanAddresses(String list);

  /// No description provided for @ipv6.
  ///
  /// In ru, this message translates to:
  /// **'IPv6'**
  String get ipv6;

  /// No description provided for @ipv6Profile.
  ///
  /// In ru, this message translates to:
  /// **'Из профиля'**
  String get ipv6Profile;

  /// No description provided for @ipv6On.
  ///
  /// In ru, this message translates to:
  /// **'Вкл'**
  String get ipv6On;

  /// No description provided for @ipv6Off.
  ///
  /// In ru, this message translates to:
  /// **'Выкл'**
  String get ipv6Off;

  /// No description provided for @logLevel.
  ///
  /// In ru, this message translates to:
  /// **'Уровень логов'**
  String get logLevel;

  /// No description provided for @logLevelProfile.
  ///
  /// In ru, this message translates to:
  /// **'Из профиля'**
  String get logLevelProfile;

  /// No description provided for @findProcess.
  ///
  /// In ru, this message translates to:
  /// **'Определять процессы'**
  String get findProcess;

  /// No description provided for @findProcessHint.
  ///
  /// In ru, this message translates to:
  /// **'Нужно для группировки соединений и правил PROCESS-NAME. Отключите, если важна каждая доля процессора.'**
  String get findProcessHint;

  /// No description provided for @coresBuiltIn.
  ///
  /// In ru, this message translates to:
  /// **'Ядра встроены в клиент и обновляются вместе с ним.'**
  String get coresBuiltIn;

  /// No description provided for @invalidCidr.
  ///
  /// In ru, this message translates to:
  /// **'Нужна сеть вида 192.168.1.0/24'**
  String get invalidCidr;

  /// No description provided for @invalidPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт от 1 до 65535'**
  String get invalidPort;

  /// No description provided for @invalidMtu.
  ///
  /// In ru, this message translates to:
  /// **'MTU от 576 до 65535'**
  String get invalidMtu;

  /// No description provided for @secDns.
  ///
  /// In ru, this message translates to:
  /// **'DNS'**
  String get secDns;

  /// No description provided for @dnsOverride.
  ///
  /// In ru, this message translates to:
  /// **'Свои DNS-серверы (профили mihomo)'**
  String get dnsOverride;

  /// No description provided for @dnsOverrideHint.
  ///
  /// In ru, this message translates to:
  /// **'Заменяет DNS профиля: запросы идут через VPN по правилам, провайдер их не видит. Первое разрешение имени чуть медленнее. Включайте, если DNS профиля сбоит. Профили sing-box не затрагиваются.'**
  String get dnsOverrideHint;

  /// No description provided for @dnsRemote.
  ///
  /// In ru, this message translates to:
  /// **'Через VPN'**
  String get dnsRemote;

  /// No description provided for @dnsRemoteHint.
  ///
  /// In ru, this message translates to:
  /// **'Для всех имён. Шифрованный DNS: https://…, tls://…'**
  String get dnsRemoteHint;

  /// No description provided for @dnsDirect.
  ///
  /// In ru, this message translates to:
  /// **'Напрямую'**
  String get dnsDirect;

  /// No description provided for @dnsDirectHint.
  ///
  /// In ru, this message translates to:
  /// **'Только чтобы найти сами VPN-серверы и для прямого трафика. Обычные IP-адреса.'**
  String get dnsDirectHint;

  /// No description provided for @invalidResolver.
  ///
  /// In ru, this message translates to:
  /// **'Нужен IP или адрес вида https://…/dns-query'**
  String get invalidResolver;

  /// No description provided for @trayExitKeepCore.
  ///
  /// In ru, this message translates to:
  /// **'Выйти, оставив VPN включённым'**
  String get trayExitKeepCore;

  /// No description provided for @toggleHotkey.
  ///
  /// In ru, this message translates to:
  /// **'Горячая клавиша вкл./выкл. VPN'**
  String get toggleHotkey;

  /// No description provided for @hotkeyNone.
  ///
  /// In ru, this message translates to:
  /// **'Не задана'**
  String get hotkeyNone;

  /// No description provided for @hotkeySet.
  ///
  /// In ru, this message translates to:
  /// **'Задать'**
  String get hotkeySet;

  /// No description provided for @hotkeyPress.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите сочетание клавиш, например Ctrl + Alt + V. Оно работает, даже когда окно скрыто.'**
  String get hotkeyPress;

  /// No description provided for @updates.
  ///
  /// In ru, this message translates to:
  /// **'Обновления'**
  String get updates;

  /// No description provided for @checkUpdates.
  ///
  /// In ru, this message translates to:
  /// **'Проверять обновления при запуске'**
  String get checkUpdates;

  /// No description provided for @checkNow.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get checkNow;

  /// No description provided for @updateLatest.
  ///
  /// In ru, this message translates to:
  /// **'У вас последняя версия'**
  String get updateLatest;

  /// No description provided for @updateNoReleases.
  ///
  /// In ru, this message translates to:
  /// **'Релизов пока нет'**
  String get updateNoReleases;

  /// No description provided for @updateAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступна версия {v}'**
  String updateAvailable(String v);

  /// No description provided for @updateTo.
  ///
  /// In ru, this message translates to:
  /// **'Обновить до {v}'**
  String updateTo(String v);

  /// No description provided for @updateDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка обновления… {p}%'**
  String updateDownloading(int p);

  /// No description provided for @updateHint.
  ///
  /// In ru, this message translates to:
  /// **'Клиент скачает архив (через VPN, если он включён), закроется, обновится и запустится снова. Настройки и подписки сохранятся.'**
  String get updateHint;

  /// No description provided for @settingsAndroid.
  ///
  /// In ru, this message translates to:
  /// **'Android'**
  String get settingsAndroid;

  /// No description provided for @vpnNotification.
  ///
  /// In ru, this message translates to:
  /// **'Уведомление «VPN работает»'**
  String get vpnNotification;

  /// No description provided for @vpnNotificationHint.
  ///
  /// In ru, this message translates to:
  /// **'Без уведомления Android не даёт VPN работать в фоне. Если выключить, оно сворачивается: без значка в строке состояния, в самом низу шторки.'**
  String get vpnNotificationHint;

  /// No description provided for @vpnNotificationHide.
  ///
  /// In ru, this message translates to:
  /// **'Убрать совсем'**
  String get vpnNotificationHide;

  /// No description provided for @vpnNotificationHideHint.
  ///
  /// In ru, this message translates to:
  /// **'Откроются настройки Android: выключите там «VPN работает (свёрнуто)». VPN продолжит работать, значок ключа останется — его показывает система.'**
  String get vpnNotificationHideHint;

  /// No description provided for @quickTile.
  ///
  /// In ru, this message translates to:
  /// **'Кнопка в шторке'**
  String get quickTile;

  /// No description provided for @quickTileHint.
  ///
  /// In ru, this message translates to:
  /// **'Откройте шторку, нажмите карандаш и перетащите плитку SolaHelm. Она включает последнее подключение и выключает VPN, не открывая приложение.'**
  String get quickTileHint;

  /// No description provided for @settingsUiMode.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс'**
  String get settingsUiMode;

  /// No description provided for @uiSimple.
  ///
  /// In ru, this message translates to:
  /// **'Простой'**
  String get uiSimple;

  /// No description provided for @uiSimpleHint.
  ///
  /// In ru, this message translates to:
  /// **'Одна большая кнопка: добавили подписку, нажали — работает. Видно страну, через которую идёт трафик, и можно выбрать сервер. Ничего лишнего.'**
  String get uiSimpleHint;

  /// No description provided for @uiAdvanced.
  ///
  /// In ru, this message translates to:
  /// **'Расширенный'**
  String get uiAdvanced;

  /// No description provided for @uiAdvancedHint.
  ///
  /// In ru, this message translates to:
  /// **'Всё сразу: режимы TUN и прокси, выбор ядра, правила, соединения, журнал, тонкие настройки подключения и ядра.'**
  String get uiAdvancedHint;

  /// No description provided for @welcomeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать в SolaHelm'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Как вам удобнее?'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeLater.
  ///
  /// In ru, this message translates to:
  /// **'Это можно поменять в любой момент: Настройки → Интерфейс.'**
  String get welcomeLater;

  /// No description provided for @settingsExit.
  ///
  /// In ru, this message translates to:
  /// **'Страна и IP'**
  String get settingsExit;

  /// No description provided for @showExitInfo.
  ///
  /// In ru, this message translates to:
  /// **'Показывать страну и IP'**
  String get showExitInfo;

  /// No description provided for @showExitInfoHint.
  ///
  /// In ru, this message translates to:
  /// **'После подключения клиент спрашивает у ipwho.is (через VPN), с каким IP и из какой страны вы теперь выходите в интернет.'**
  String get showExitInfoHint;

  /// No description provided for @exitLocating.
  ///
  /// In ru, this message translates to:
  /// **'Определяем страну…'**
  String get exitLocating;

  /// No description provided for @exitUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить IP'**
  String get exitUnknown;

  /// No description provided for @exitUnknownPlace.
  ///
  /// In ru, this message translates to:
  /// **'Страна неизвестна'**
  String get exitUnknownPlace;

  /// No description provided for @showIp.
  ///
  /// In ru, this message translates to:
  /// **'Показать IP целиком'**
  String get showIp;

  /// No description provided for @hideIp.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть IP'**
  String get hideIp;

  /// No description provided for @settingsRouting.
  ///
  /// In ru, this message translates to:
  /// **'Маршрутизация'**
  String get settingsRouting;

  /// No description provided for @routingRuDirect.
  ///
  /// In ru, this message translates to:
  /// **'Россия напрямую'**
  String get routingRuDirect;

  /// No description provided for @routingAll.
  ///
  /// In ru, this message translates to:
  /// **'Всё через VPN'**
  String get routingAll;

  /// No description provided for @routingHint.
  ///
  /// In ru, this message translates to:
  /// **'Для подписок-ссылок (универсальных): в них нет своих правил. «Россия напрямую» — российские сайты и приложения, торренты и локальная сеть идут мимо VPN, заблокированное и остальное — через VPN (наборы правил legiz-ru и MetaCubeX, как в шаблоне панели). Профили Clash и sing-box используют свои правила.'**
  String get routingHint;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'ru':
      return SRu();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
