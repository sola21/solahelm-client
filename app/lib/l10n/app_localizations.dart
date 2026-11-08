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

  /// No description provided for @reasonOnlyIn.
  ///
  /// In ru, this message translates to:
  /// **'{protocol} есть только в {core}'**
  String reasonOnlyIn(String protocol, String core);

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
