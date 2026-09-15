# xFastSignal — нотатки з обговорення (початок проєкту)

Дата: 2026-09-05
Сесія-джерело: обговорення велось у теці xSilent, перед перемиканням на xFastSignal.

## Ідея

Android-застосунок для швидкої (в ідеалі — автоматичної) відправки повідомлень у Signal,
без ручного відкриття Signal і вибору контакту щоразу.

## Розглянуті варіанти автоматизації

1. **Android share intent / Direct Share шорткати** — застосунок одразу відкриває
   потрібний контакт у Signal з готовим текстом (`ACTION_SEND`), але фінальне
   натискання "надіслати" лишається за користувачем у самому Signal.
   Офіційно підтримується, не потребує серверної частини, але це не справжня
   автовідправка.
2. **Автовідправка через `signal-cli`** (обраний напрямок) — окремий backend з
   лінкованим/зареєстрованим номером Signal, який реально надсилає повідомлення без
   участі людини.
3. **`signal-cli` на самому пристрої** (Termux/вбудований JVM) — офлайн, приватний
   ключ не залишає телефон, але signal-cli офіційно не збирається під Android;
   визнано дослідницьким і надто крихким варіантом, відкинуто як перший крок.

## Рішення: reuse напрацювань з xBot

У проєкті `xBot` (`c:\src\xBot`) вже є робочий Signal-бот на ASP.NET Core (net10.0)
з `signal-cli` у контейнері:

- **Важливий нюанс**: xBot **мігрував з `signal-cli-rest-api` (REST) на власний
  легкий образ `signal-cli`, що говорить лише JSON-RPC**
  (`Services/Signal/SignalJsonRpcClient.cs`, `Services/Signal/SignalEventListenerService.cs`
  для SSE-потоку вхідних). Тобто "звертання через REST API", як спочатку
  формулювалось — вже застаріла версія архітектури xBot.

### Обрана архітектура (варіант 1 з трьох запропонованих)

- xBot лишається "тримачем" зареєстрованого/лінкованого номера Signal і
  `SignalJsonRpcClient`.
- У xBot додається невеликий **авторизований HTTP-endpoint** (API key/JWT), який
  під капотом викликає вже готовий JSON-RPC клієнт — щось на кшталт
  `POST /send {template, target}`.
- **xFastSignal — тонкий Android-клієнт**, який просто б'є в цей endpoint
  (кнопки/App Shortcuts), не дублюючи інтеграцію з signal-cli.

Альтернативи, які розглядались і відкинуті на користь цього варіанту:
- xFastSignal ходить напряму по JSON-RPC до signal-cli-контейнера, минаючи xBot —
  менше компонентів, але тоді автентифікацію/безпеку мережевого доступу до daemon
  довелось би вирішувати в самому Flutter-додатку, а не перевикористовувати те, що
  xBot вже вирішив.

### Безпека (озвучено, ще не спроєктовано)

Ендпоінт у xBot фактично надсилає повідомлення від імені прив'язаного номера —
тому пропозиція звужувати можливості не до "довільний текст на будь-який номер",
а до:
- фіксованих шаблонів повідомлень,
- allowlist одержувачів (контактів/груп).

## Стан проєкту xFastSignal

- Створено заготовку: `flutter create --org ua.vn.log --project-name xfastsignal
  --platforms android -a kotlin`.
- **Org/домен**: `ua.vn.log` (зворотнє від домену користувача `log.vn.ua`) —
  свідомо відмінний від `ua.org.sovic`, який використовується в xSilent.
- `applicationId = ua.vn.log.xfastsignal`.
- Лише Android-платформа (iOS/desktop не генерувались).
- Залежності (riverpod, http/dio-клієнт) — **ще не додані**, як і структура папок.
- Git-репозиторій у xFastSignal **ще не ініціалізовано**.

## Відкриті питання / наступні кроки

1. Контракт API у xBot: форма запиту/відповіді, коди помилок, спосіб автентифікації
   (API key в заголовку? JWT?).
2. Модель шаблонів повідомлень і allowlist одержувачів — де зберігається
   (конфіг xBot? БД? редагується з xFastSignal чи лише на бекенді?).
3. Чи endpoint — це новий контролер у xBot, чи виокремлений мікросервіс.
4. Базові залежності й структура xFastSignal (riverpod + http/dio, за зразком
   xSilent: drift + Riverpod + flutter_local_notifications — але тут можливо не
   всі ці шари потрібні).
5. UI xFastSignal: екран швидких кнопок / App Shortcuts / Direct Share для
   миттєвого виклику потрібного шаблону.

## Перенесення розробки на Mac (2026-09-15)

Дата: 2026-09-15. Налаштовували середовище на першому Mac (Apple Silicon, macOS 27).
Планується продовжити на іншому Mac-пристрої — нижче стан і що лишилось.

### Зроблено на першому Mac

- **Homebrew casks:** `flutter`, `temurin@21`, `android-commandlinetools`,
  `dotnet-sdk`, `docker-desktop` (усе через `brew install --cask`; пакети з
  sudo-інсталятором — `temurin@21`, `dotnet-sdk`, `docker-desktop` — вимагають
  інтерактивного пароля, з-під автоматизації не йдуть).
- **`~/.zshrc`** доповнено (блок `# xFastSignal dev env`):
  `JAVA_HOME` → `temurin-21` (системна Java 26 навмисно не використовується —
  несумісна з Gradle/AGP у поточному Flutter), `ANDROID_HOME`/`ANDROID_SDK_ROOT`
  → `/opt/homebrew/share/android-commandlinetools`, PATH доповнено
  cmdline-tools/platform-tools.
- **Android SDK:** ліцензії прийнято (`sdkmanager --licenses`), встановлено
  `platform-tools`, `platforms;android-37.2`, `build-tools;37.0.0`.
  `flutter doctor` — Android toolchain повністю зелений.
- **VS Code:** CLI `code` присимлінкований у `/opt/homebrew/bin/code` (App
  Store/дефолтний інсталятор не додає його в PATH сам). Розширення:
  `Dart-Code.flutter` (+ dart-code), `ms-dotnettools.csdevkit`,
  `ms-azuretools.vscode-docker`.
- **.NET:** `dotnet build` бекенду xSignalRelay проходить чисто, HTTPS
  dev-сертифікат довірено (`dotnet dev-certs https --trust`).
- **Docker Desktop:** встановлено й запущено (перший запуск вимагав ручного
  прийняття ліцензії + пароля в GUI — з автоматизації не спрацювало).
- **SSH до GitHub:** ключ `~/.local/ssh/home.lan/keys/github.com.sovicUA`
  (host-alias `github.com`/`github.sovicua` у
  `~/.local/ssh/home.lan/config.d/github.com.conf`) спершу не працював —
  публічний ключ довелось додати на GitHub-акаунт вручну через
  Settings → SSH keys, після чого запрацював.
- **Репозиторій `xBot`** склоновано в `/Users/viktor/src/xBot` (по SSH) —
  потрібен був лише заради `signal-cli/Dockerfile` (образ
  `ghcr.io/sovicua/xbot-signal-cli` не мав arm64-збірки, качався через
  emulated amd64). Зібрали нативний arm64-образ локально:
  `docker build --platform linux/arm64 -t xbot-signal-cli:arm64 -f signal-cli/Dockerfile signal-cli`
  (з кореня xBot). Працює, перевірено `--version` → `signal-cli 0.14.7`.
- **xSignalRelay:** docker-compose.yml і README оновлено — signal-cli тепер
  завжди на вилученому сервері, залежність від мережі `xbot-network` (спільної
  з compose xBot) прибрано; relay звертається до нього через обов'язковий
  env var `SIGNAL_BASE_URL` (коміт `602e7de`).
- **`origin` remote** xFastSignal переключено з HTTPS на SSH
  (`git@github.com:sovicUA/xFastSignal.git`) — HTTPS на цьому Mac не мав
  налаштованих credentials.

### Не зроблено / відкрито

- **Фізичний Android-пристрій** ще не підключали й не тестували
  (`adb devices` не перевірявся).
- **signal-cli daemon** реально не піднімали й не лінкували на цьому Mac —
  лише зібрали образ. Реальний(і) номер(и) уже працює(ють) на вилученому
  сервері (див. `Signal:BaseUrl`/`SIGNAL_BASE_URL` в xSignalRelay); якщо
  колись знадобиться піднімати ще один daemon локально — команда й нюанси
  (лінкування пристрою) в `xBot/README.md`, розділ «Signal», і
  `xBot/docker-compose.signal.yml`.
- **Образ `ghcr.io/sovicua/xbot-signal-cli:latest`** (amd64, тягнутий через
  emulation) лишився в локальному Docker — можна прибрати
  (`docker rmi ghcr.io/sovicua/xbot-signal-cli:latest`), бо є нативний
  `xbot-signal-cli:arm64`.
- **GHCR PAT**, яким логінились (`docker login ghcr.io`), діставали вручну з
  `~/.docker/config.json` на окремій Linux-машині (base64, не шифрування) —
  варто ротувати/відкликати на GitHub, якщо більше не плануєте користуватись
  ним з цього Mac.

### Для продовження на іншому Mac

Повторити той самий сетап (Homebrew casks вище + VS Code CLI/розширення +
Android SDK-компоненти + `JAVA_HOME`/`ANDROID_HOME` в shell rc + SSH-ключ
GitHub, якщо ще не синхронізований). `xBot` не обов'язково клонувати знову,
якщо arm64-образ `xbot-signal-cli` переносити вручну (`docker save`/`load`)
або просто перезібрати на місці тим самим способом.
