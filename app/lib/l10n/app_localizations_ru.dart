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
  String linksSkipped(String protocols) {
    return 'пропущены: $protocols';
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

  @override
  String get navRules => 'Правила';

  @override
  String get importFile => 'Файл';

  @override
  String pastedName(String date) {
    return 'Из буфера $date';
  }

  @override
  String get profileAdded => 'Профиль добавлен';

  @override
  String get menuOpen => 'Открыть и редактировать';

  @override
  String get menuRules => 'Правила';

  @override
  String get rename => 'Переименовать';

  @override
  String get nameLabel => 'Название';

  @override
  String get sourceFile => 'файл';

  @override
  String get sourcePasted => 'вставлен';

  @override
  String get editedBadge => 'изменён вручную';

  @override
  String get rulesBadge => 'свои правила';

  @override
  String get check => 'Проверить';

  @override
  String get save => 'Сохранить';

  @override
  String get saved => 'Сохранено';

  @override
  String checkOk(String format, String core) {
    return 'Конфиг в порядке: $format, ядро $core';
  }

  @override
  String checkOkLinks(int n) {
    return 'Ссылки в порядке: $n прокси, ядро mihomo';
  }

  @override
  String get editedWarning =>
      'Профиль по ссылке: при обновлении подписки правки в тексте будут заменены. Свои правила задавайте в «Правилах», они сохраняются отдельно.';

  @override
  String get unsavedTitle => 'Изменения не сохранены';

  @override
  String get discard => 'Не сохранять';

  @override
  String get rulesEdit => 'Редактировать';

  @override
  String get rulesActive => 'Действующие правила';

  @override
  String get rulesOfProfile => 'Правила профиля';

  @override
  String get rulesNone => 'Правил нет';

  @override
  String rulesCount(int n) {
    return 'Правил: $n';
  }

  @override
  String get ruleType => 'Тип правила';

  @override
  String get rulePayload => 'Параметр';

  @override
  String get ruleTarget => 'Прокси';

  @override
  String get addTop => 'В начало';

  @override
  String get addBottom => 'В конец';

  @override
  String get asText => 'Текстом';

  @override
  String get asList => 'Списком';

  @override
  String get rulesHintReplace =>
      'Список целиком заменяет правила профиля и хранится отдельно от подписки: обновление его не сбросит.';

  @override
  String get rulesHintPrepend =>
      'Профиль sing-box: ваши правила встают перед правилами профиля. Правила самого профиля ниже, они только для чтения.';

  @override
  String get resetRules => 'Вернуть правила профиля';

  @override
  String get profileRulesReadonly => 'Правила профиля (только чтение)';

  @override
  String get searchRules => 'Поиск правил';

  @override
  String ruleInvalid(int n, String line) {
    return 'Неверное правило в строке $n: $line';
  }

  @override
  String get rulesSaved => 'Правила сохранены';

  @override
  String get payloadEmpty => 'Введите параметр';

  @override
  String get addRuleFor => 'Правило';

  @override
  String get ruleDirect => 'Напрямую';

  @override
  String get ruleProxy => 'Через VPN';

  @override
  String get ruleReject => 'Блокировать';

  @override
  String ruleAddedFor(String what) {
    return 'Правило для $what добавлено';
  }

  @override
  String rulesEditorTitle(String name) {
    return 'Правила: $name';
  }

  @override
  String get rulesNotConnectedHint =>
      'Показаны правила профиля. Подключитесь, чтобы видеть правила, которые применило ядро.';

  @override
  String get formatLinksShort => 'Ссылки';

  @override
  String get statusDisconnecting => 'Отключение…';

  @override
  String get trayRestart => 'Перезапустить';

  @override
  String get settingsConnection => 'Подключение и TUN';

  @override
  String get settingsConnectionHint =>
      'Стек и маршруты TUN, исключения системного прокси, порты, доступ из локальной сети';

  @override
  String get settingsCoreAdv => 'Ядро';

  @override
  String get settingsCoreAdvHint =>
      'IPv6, уровень логов, определение процессов, версии ядер';

  @override
  String get reapplyHint => 'Изменения применятся после переподключения.';

  @override
  String get reapply => 'Переподключить';

  @override
  String get secTun => 'TUN';

  @override
  String get manageTun => 'Управлять настройками TUN';

  @override
  String get manageTunOff =>
      'Используются настройки профиля (стек gVisor, без запросов брандмауэра).';

  @override
  String get tunStack => 'Стек';

  @override
  String get tunStackHint =>
      'gVisor не открывает портов и не вызывает запрос брандмауэра. Mixed и System быстрее, но Windows может спросить разрешение.';

  @override
  String get strictRoute => 'Строгая маршрутизация';

  @override
  String get strictRouteHint => 'Не даёт DNS-запросам уходить мимо туннеля.';

  @override
  String get mtu => 'MTU';

  @override
  String get routeExclude => 'Исключить сети из TUN';

  @override
  String get routeExcludeHint =>
      'Эти сети идут напрямую, мимо туннеля: локальная сеть, RDP, принтеры.';

  @override
  String get addNetwork => 'Добавить сеть';

  @override
  String get networkHint => '192.168.1.0/24';

  @override
  String get secSysProxy => 'Системный прокси';

  @override
  String get proxyBypass => 'Исключения системного прокси';

  @override
  String get proxyBypassHint =>
      'Адреса, к которым программы обращаются напрямую. Можно маски: 192.168.*, *.local, <local>.';

  @override
  String get addException => 'Добавить исключение';

  @override
  String get restoreDefaults => 'Стандартный список';

  @override
  String get secPorts => 'Порты';

  @override
  String get mixedPort => 'Смешанный порт (HTTP + SOCKS)';

  @override
  String get mixedPortHint =>
      'Если порт занят, будет взят следующий свободный.';

  @override
  String get allowLan => 'Разрешить подключения из локальной сети';

  @override
  String get allowLanHint =>
      'Другие устройства смогут использовать прокси этого компьютера. Windows может спросить разрешение брандмауэра.';

  @override
  String lanAddresses(String list) {
    return 'Адреса для других устройств: $list';
  }

  @override
  String get ipv6 => 'IPv6';

  @override
  String get ipv6Profile => 'Из профиля';

  @override
  String get ipv6On => 'Вкл';

  @override
  String get ipv6Off => 'Выкл';

  @override
  String get logLevel => 'Уровень логов';

  @override
  String get logLevelProfile => 'Из профиля';

  @override
  String get findProcess => 'Определять процессы';

  @override
  String get findProcessHint =>
      'Нужно для группировки соединений и правил PROCESS-NAME. Отключите, если важна каждая доля процессора.';

  @override
  String get coresBuiltIn =>
      'Ядра встроены в клиент и обновляются вместе с ним.';

  @override
  String get invalidCidr => 'Нужна сеть вида 192.168.1.0/24';

  @override
  String get invalidPort => 'Порт от 1 до 65535';

  @override
  String get invalidMtu => 'MTU от 576 до 65535';

  @override
  String get secDns => 'DNS';

  @override
  String get dnsOverride => 'Свои DNS-серверы (профили mihomo)';

  @override
  String get dnsOverrideHint =>
      'Заменяет DNS профиля: запросы идут через VPN по правилам, провайдер их не видит. Первое разрешение имени чуть медленнее. Включайте, если DNS профиля сбоит. Профили sing-box не затрагиваются.';

  @override
  String get dnsRemote => 'Через VPN';

  @override
  String get dnsRemoteHint =>
      'Для всех имён. Шифрованный DNS: https://…, tls://…';

  @override
  String get dnsDirect => 'Напрямую';

  @override
  String get dnsDirectHint =>
      'Только чтобы найти сами VPN-серверы и для прямого трафика. Обычные IP-адреса.';

  @override
  String get invalidResolver => 'Нужен IP или адрес вида https://…/dns-query';

  @override
  String get trayExitKeepCore => 'Выйти, оставив VPN включённым';

  @override
  String get toggleHotkey => 'Горячая клавиша вкл./выкл. VPN';

  @override
  String get hotkeyNone => 'Не задана';

  @override
  String get hotkeySet => 'Задать';

  @override
  String get hotkeyPress =>
      'Нажмите сочетание клавиш, например Ctrl + Alt + V. Оно работает, даже когда окно скрыто.';

  @override
  String get updates => 'Обновления';

  @override
  String get checkUpdates => 'Проверять обновления при запуске';

  @override
  String get checkNow => 'Проверить';

  @override
  String get updateLatest => 'У вас последняя версия';

  @override
  String get updateNoReleases => 'Релизов пока нет';

  @override
  String updateAvailable(String v) {
    return 'Доступна версия $v';
  }

  @override
  String updateTo(String v) {
    return 'Обновить до $v';
  }

  @override
  String updateDownloading(int p) {
    return 'Загрузка обновления… $p%';
  }

  @override
  String get updateHint =>
      'Клиент скачает архив (через VPN, если он включён), закроется, обновится и запустится снова. Настройки и подписки сохранятся.';

  @override
  String get settingsAndroid => 'Android';

  @override
  String get vpnNotification => 'Уведомление «VPN работает»';

  @override
  String get vpnNotificationHint =>
      'Без уведомления Android не даёт VPN работать в фоне. Если выключить, оно сворачивается: без значка в строке состояния, в самом низу шторки.';

  @override
  String get vpnNotificationHide => 'Убрать совсем';

  @override
  String get vpnNotificationHideHint =>
      'Откроются настройки Android: выключите там «VPN работает (свёрнуто)». VPN продолжит работать, значок ключа останется — его показывает система.';

  @override
  String get quickTile => 'Кнопка в шторке';

  @override
  String get quickTileHint =>
      'Откройте шторку, нажмите карандаш и перетащите плитку SolaHelm. Она включает последнее подключение и выключает VPN, не открывая приложение.';

  @override
  String get settingsUiMode => 'Интерфейс';

  @override
  String get uiSimple => 'Простой';

  @override
  String get uiSimpleHint =>
      'Одна большая кнопка: добавили подписку, нажали — работает. Видно страну, через которую идёт трафик, и можно выбрать сервер. Ничего лишнего.';

  @override
  String get uiAdvanced => 'Расширенный';

  @override
  String get uiAdvancedHint =>
      'Всё сразу: режимы TUN и прокси, выбор ядра, правила, соединения, журнал, тонкие настройки подключения и ядра.';

  @override
  String get welcomeTitle => 'Добро пожаловать в SolaHelm';

  @override
  String get welcomeSubtitle => 'Как вам удобнее?';

  @override
  String get welcomeLater =>
      'Это можно поменять в любой момент: Настройки → Интерфейс.';

  @override
  String get settingsExit => 'Страна и IP';

  @override
  String get showExitInfo => 'Показывать страну и IP';

  @override
  String get showExitInfoHint =>
      'После подключения клиент спрашивает у ipwho.is (через VPN), с каким IP и из какой страны вы теперь выходите в интернет.';

  @override
  String get exitLocating => 'Определяем страну…';

  @override
  String get exitUnknown => 'Не удалось определить IP';

  @override
  String get exitUnknownPlace => 'Страна неизвестна';

  @override
  String get showIp => 'Показать IP целиком';

  @override
  String get hideIp => 'Скрыть IP';

  @override
  String get settingsRouting => 'Маршрутизация';

  @override
  String get routingRuDirect => 'Россия напрямую';

  @override
  String get routingAll => 'Всё через VPN';

  @override
  String get routingHint =>
      'Для подписок-ссылок (универсальных): в них нет своих правил. «Россия напрямую» — российские сайты и приложения, торренты и локальная сеть идут мимо VPN, заблокированное и остальное — через VPN (наборы правил legiz-ru и MetaCubeX, как в шаблоне панели). Профили Clash и sing-box используют свои правила.';

  @override
  String get qrCamera => 'Камерой';

  @override
  String get qrScreen => 'С экрана';

  @override
  String get qrGallery => 'Из галереи';

  @override
  String get qrImageFile => 'Из картинки';

  @override
  String get qrNotFound => 'QR-код не найден';

  @override
  String qrName(String date) {
    return 'QR $date';
  }

  @override
  String get qrCameraTitle => 'Наведите на QR-код';

  @override
  String get qrCameraHint => 'QR со ссылкой на подписку или на сервер';

  @override
  String get qrCameraDenied =>
      'Нет доступа к камере. Разрешите его в настройках Android.';

  @override
  String get qrCameraError => 'Камера недоступна';

  @override
  String get qrTorch => 'Фонарик';
}
