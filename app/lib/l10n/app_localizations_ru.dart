// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class SRu extends S {
  SRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'SolaHelm';

  @override
  String get navHome => 'Главная';

  @override
  String get navNodes => 'Узлы';

  @override
  String get navSubscriptions => 'Подписки';

  @override
  String get navConnections => 'Соединения';

  @override
  String get navLogs => 'Журнал';

  @override
  String get navSettings => 'Настройки';

  @override
  String get statusDisconnected => 'Отключено';

  @override
  String get statusConnected => 'Подключено';

  @override
  String get statusConnecting => 'Подключение…';

  @override
  String get tapToConnect => 'Нажмите, чтобы подключиться';

  @override
  String get connect => 'Подключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String connectedFor(String time, String core) {
    return '$time · ядро $core';
  }

  @override
  String coreAutoChip(String core) {
    return '$core · авто';
  }

  @override
  String coreChosenAuto(String core) {
    return 'ядро $core выбрано автоматически';
  }

  @override
  String coreChosenManual(String core) {
    return 'ядро $core закреплено в настройках';
  }

  @override
  String get modeLabel => 'Режим';

  @override
  String get modeTun => 'TUN';

  @override
  String get modeSystemProxy => 'Системный прокси';

  @override
  String modePortOnly(int port) {
    return 'Только порт $port';
  }

  @override
  String get metricNode => 'Узел';

  @override
  String get metricLatency => 'Задержка';

  @override
  String get metricSpeed => 'Скорость';

  @override
  String get metricTraffic => 'Трафик';

  @override
  String kbps(int value) {
    return '$value КБ/с';
  }

  @override
  String gb(String value) {
    return '$value ГБ';
  }

  @override
  String trafficOf(String used, String total) {
    return '$used из $total';
  }

  @override
  String groupLabel(String name) {
    return 'Группа: $name';
  }

  @override
  String get groupAuto => 'Авто (быстрейший)';

  @override
  String get ping => 'Пинг';

  @override
  String pingMs(int ms) {
    return '$ms мс';
  }

  @override
  String get pingTimeout => 'нет ответа';

  @override
  String get pingUnknown => '—';

  @override
  String get recentConnections => 'Последние соединения';

  @override
  String get routeDirect => 'напрямую';

  @override
  String routeVia(String node) {
    return 'VPN · $node';
  }

  @override
  String get addSubscription => 'Добавить подписку';

  @override
  String get subscriptionUrl => 'Ссылка на подписку';

  @override
  String get subscriptionUrlHint => 'https://panel.example.org/…/sub/…';

  @override
  String get add => 'Добавить';

  @override
  String get cancel => 'Отмена';

  @override
  String get errorUrlEmpty => 'Введите ссылку';

  @override
  String get errorUrlInvalid =>
      'Ссылка должна начинаться с http:// или https://';

  @override
  String get scanQr => 'QR-код';

  @override
  String get pasteClipboard => 'Вставить';

  @override
  String get clipboardEmpty => 'В буфере обмена нет ссылки';

  @override
  String get subPending => 'Загрузится, когда подключим ядро';

  @override
  String expiresOn(String date) {
    return 'до $date';
  }

  @override
  String get noExpiry => 'бессрочно';

  @override
  String get unlimited => 'без лимита';

  @override
  String get formatSingBox => 'sing-box JSON';

  @override
  String get formatClash => 'Clash YAML';

  @override
  String formatLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ссылки',
      many: '$count ссылок',
      few: '$count ссылки',
      one: '$count ссылка',
    );
    return '$_temp0';
  }

  @override
  String reasonOnlyIn(String protocol, String core) {
    return '$protocol есть только в $core';
  }

  @override
  String get reasonByFormat => 'ядро выбрано по формату';

  @override
  String rulesTemplate(String name) {
    return 'правила «$name»';
  }

  @override
  String get settingsTheme => 'Тема';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get settingsCore => 'Ядро';

  @override
  String get coreAuto => 'Авто';

  @override
  String get coreHint =>
      'В режиме «Авто» ядро выбирается по формату подписки и протоколам. Если протокол есть только в одном ядре, будет выбрано оно.';

  @override
  String get settingsAbout => 'О программе';

  @override
  String coreVersions(String sb, String mh) {
    return 'sing-box $sb · mihomo $mh';
  }

  @override
  String get demoBanner => 'Демо-данные: интерфейс ещё не подключён к ядру';

  @override
  String get comingSoon => 'Раздел появится, когда интерфейс подключим к ядру.';

  @override
  String get nodesNotConnected => 'Подключитесь, чтобы увидеть узлы подписки.';

  @override
  String get groupAutoHint => 'Эта группа выбирает узел сама по задержке.';

  @override
  String get noSubscriptions =>
      'Добавьте подписку — ссылку из кабинета вашей панели.';

  @override
  String get noSubscriptionsTitle => 'Пока нет подписок';

  @override
  String get needSubscription => 'Сначала добавьте подписку';

  @override
  String get refresh => 'Обновить';

  @override
  String get delete => 'Удалить';

  @override
  String get subscriptionAdded => 'Подписка добавлена';

  @override
  String updatedAt(String time) {
    return 'обновлено $time';
  }

  @override
  String localPort(int port) {
    return 'Порт 127.0.0.1:$port';
  }

  @override
  String get adminBadge => 'администратор';

  @override
  String get coreMissing =>
      'Не найден solahelm-core рядом с приложением — показаны демо-данные';

  @override
  String errorPrefix(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get noConnections => 'Соединений пока нет.';

  @override
  String get connectionsHint =>
      'Активные соединения через ядро: куда и через какой узел.';

  @override
  String trafficUnlimited(String used) {
    return '$used · без лимита';
  }

  @override
  String get groupSelector => 'ручной выбор';

  @override
  String get groupUrlTest => 'автовыбор по задержке';

  @override
  String get groupFallback => 'резерв: первый рабочий';

  @override
  String get groupLoadBalance => 'балансировка';

  @override
  String get logsEmpty =>
      'Журнал пуст. Строки ядра появятся после подключения.';

  @override
  String get search => 'Поиск';

  @override
  String get pause => 'Пауза';

  @override
  String get resume => 'Продолжить';

  @override
  String get clear => 'Очистить';

  @override
  String get copy => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get levelAll => 'Все';

  @override
  String get connActive => 'Активные';

  @override
  String get connClosed => 'Закрытые';

  @override
  String processesCount(int n) {
    return 'Процессов: $n';
  }

  @override
  String get filter => 'Фильтр';

  @override
  String get sortDownload => 'Скачано';

  @override
  String get sortUpload => 'Отдано';

  @override
  String get sortTime => 'Время';

  @override
  String get sortHost => 'Хост';

  @override
  String get sortCount => 'Соединений';

  @override
  String get byProcess => 'По процессам';

  @override
  String get flatList => 'Списком';

  @override
  String get closeAll => 'Закрыть все';

  @override
  String get closeConnection => 'Закрыть соединение';

  @override
  String get back => 'Назад';

  @override
  String secondsAgo(int n) {
    return '$n с назад';
  }

  @override
  String minutesAgo(int n) {
    return '$n мин назад';
  }

  @override
  String hoursAgo(int n) {
    return '$n ч назад';
  }

  @override
  String get secTraffic => 'Трафик';

  @override
  String get upSpeed => 'Скорость отдачи';

  @override
  String get downSpeed => 'Скорость скачивания';

  @override
  String get uploaded => 'Отдано';

  @override
  String get downloaded => 'Скачано';

  @override
  String get secRouting => 'Маршрутизация';

  @override
  String get rule => 'Правило';

  @override
  String get chain => 'Цепочка прокси';

  @override
  String get connType => 'Тип подключения';

  @override
  String get secNetwork => 'Сеть';

  @override
  String get host => 'Хост';

  @override
  String get destIp => 'IP назначения';

  @override
  String get srcIp => 'IP источника';

  @override
  String get srcPort => 'Порт источника';

  @override
  String get destPort => 'Порт назначения';

  @override
  String get remote => 'Удалённое назначение';

  @override
  String get secProcess => 'Процесс';

  @override
  String get processName => 'Имя';

  @override
  String get processPath => 'Путь';

  @override
  String get started => 'Начало';

  @override
  String get close => 'Закрыть';

  @override
  String get statusActive => 'Активно';

  @override
  String get statusClosed => 'Закрыто';

  @override
  String get clearClosed => 'Очистить закрытые';

  @override
  String get settingsBehavior => 'Поведение';

  @override
  String get closeToTray => 'Сворачивать в трей при закрытии окна';

  @override
  String get launchAtStartup => 'Запускать вместе с Windows';

  @override
  String get startMinimized => 'Запускать свёрнутым в трей';

  @override
  String get autoConnect => 'Подключаться при запуске';

  @override
  String get autoConnectTunNote =>
      'В режиме TUN при автоподключении Windows спросит права администратора.';

  @override
  String get trayShow => 'Открыть SolaHelm';

  @override
  String get trayExit => 'Выход';

  @override
  String trayModeMenu(String mode) {
    return 'Режим подключения ($mode)';
  }

  @override
  String routingMenu(String mode) {
    return 'Маршрутизация ($mode)';
  }

  @override
  String get routingRule => 'Правила';

  @override
  String get routingGlobal => 'Глобально';

  @override
  String get routingDirect => 'Напрямую';

  @override
  String get routingLabel => 'Маршрутизация';

  @override
  String get notElevated =>
      'Недостаточно прав для TUN: Windows не разрешил запустить ядро от имени администратора. Подтвердите запрос или выберите «Системный прокси».';
}
