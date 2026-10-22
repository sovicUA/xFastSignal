# xFastSignal — нотатки та архітектурні рішення

Початок: 2026-09-05. Поточний стан і наступні кроки — розділи «Стан проєкту» і
«Наступні кроки» нижче; як підхопити роботу на іншій машині — «Продовження на
іншому ПК».
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

У проєкті `xBot` (сусідній репозиторій) вже є робочий Signal-бот на ASP.NET Core (net10.0)
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

> **Переглянуто (2026-09-05, та сама сесія):** ендпоінт **не** додається в xBot —
> замість цього окремий мікросервіс `backend/xSignalRelay`, який сам ходить до
> signal-cli по JSON-RPC (метод `send`, send-only). xBot не змінюється.
> **Переглянуто (2026-09-15):** signal-cli працює на окремому (вилученому) сервері;
> relay звертається до нього за `SIGNAL_BASE_URL`, без спільної docker-мережі з xBot.

### Безпека

Ендпоінт фактично надсилає повідомлення від імені прив'язаного номера — тому
можливості звужено не до "довільний текст на будь-який номер", а до:
- фіксованих шаблонів повідомлень (з плейсхолдерами),
- allowlist одержувачів (контактів/груп).

Реалізовано в xSignalRelay: шаблони й allowlist у SQLite, клієнт бачить одержувачів
лише за opaque `id` (сирі номери/groupId не залишають бекенд), авторизація —
заголовок `X-Api-Key`.

## Стан проєкту (оновлено 2026-10-21)

**Бекенд `xSignalRelay` — робочий:**
- `GET /templates`, `GET /recipients`, `POST /send` (коди `400/403/404/502`),
  авторизація `X-Api-Key`.
- SQLite (EF Core, міграція `Initial`), сид демо-даних з конфіга.
- Сторінка статусу `/` (health check signal-cli кожні 30 с, останні 5 відправок),
  Swagger `/swagger` (поза Development — за ключем).
- Docker: `docker compose up` з `RELAY_API_KEY` + `SIGNAL_BASE_URL`, порт 8082,
  том `relay-data`.

**Клієнт Flutter — каркас (2026-10-21):**
- `flutter create --org ua.vn.log --project-name xfastsignal --platforms android -a kotlin`.
- **Org/домен**: `ua.vn.log` (зворотнє від домену користувача `log.vn.ua`) —
  свідомо відмінний від `ua.org.sovic`, який використовується в xSilent.
- `applicationId = ua.vn.log.xfastsignal`, лише Android.
- Залежності: `flutter_riverpod` 2 (ручні `Notifier`, як у xSilent), `dio`,
  `flutter_secure_storage` (API-ключ), `shared_preferences` (URL, згодом — кнопки).
- `lib/`: `models/catalog.dart`, `services/relay_client.dart` (контракт relay +
  людські повідомлення помилок), `services/relay_settings.dart`, `providers.dart`,
  `screens/settings_screen.dart` (URL + ключ, «Перевірити з'єднання»),
  `screens/home_screen.dart` (поки що — список шаблонів/одержувачів з relay).
- Debug-збірка дозволяє cleartext HTTP до `10.0.2.2`/`localhost`
  (`android/app/src/debug/res/xml/network_security_config.xml`); release — лише HTTPS.
  Якщо relay буде за HTTPS із сертифікатом внутрішнього CA — release-збірці треба
  буде явно довірити цей CA (`network_security_config`).
- **Ще немає:** кнопок (шаблон → одержувач), відправки з UI, App Shortcuts.

**Репозиторій:** основний — на внутрішньому Git-сервері (з 2026-10-21);
[github.com/sovicUA/xFastSignal](https://github.com/sovicUA/xFastSignal) — **публічне**
дзеркало (лише читання, синхронізується автоматично). Тому внутрішні адреси, хости,
IP і шляхи до ключів у репо **не записуємо** — лише плейсхолдери.

## Вирішені питання

1. ~~Контракт API~~ → `POST /send { templateId, target, params? }` → `202`,
   `X-Api-Key` у заголовку. Деталі — `backend/xSignalRelay/README.md`.
2. ~~Де зберігаються шаблони/allowlist~~ → SQLite мікросервісу; поки що наповнюється
   сидом або правкою БД (admin-CRUD — у планах).
3. ~~Контролер у xBot чи мікросервіс~~ → окремий мікросервіс xSignalRelay.

## Бачення клієнта (узгоджено 2026-10-21)

Суть: один тап → повідомлення пішло, Signal не відкривається. Клієнт знає лише relay
(`POST /send`); номери й тексти шаблонів лишаються на сервері.

- **«Кнопка» = шаблон + одержувач (+ параметри).** Сервер віддає шаблони й одержувачів
  окремо, клієнт збирає з них готові дії («Виїхав → Дружина»). Кнопки зберігаються
  **локально на телефоні** — бекенд не змінюється, кожен пристрій має свій набір.
- **Параметри** (`{minutes}` тощо): у кнопці кожен параметр або **зафіксований**
  («Запізнююсь 15»), або позначений **«питати при тапі»** — тоді перед відправкою
  коротке поле вводу.
- **Без діалогу підтвердження:** тап → snackbar «Надсилаю… [Скасувати]» ~3 с →
  відправка → ✓/✗.
- **Екрани (MVP):** Налаштування (URL relay + API-ключ у secure storage, перевірка
  з'єднання) · Головний (сітка кнопок) · Редактор кнопки (шаблон, одержувач, параметри).
- **Рівні швидкості:** 1) кнопки в застосунку (MVP) → 2) App Shortcuts (довгий тап на
  іконці — відправка без відкриття UI) → 3) віджет / Quick Settings tile.

## Наступні кроки

1. **Клієнт:** ~~каркас + налаштування + каталог~~ ✅; модель і сховище кнопок,
   редактор кнопки, сітка кнопок на головному з відправкою й Undo.
2. **Клієнт:** App Shortcuts (відправка з іконки без відкриття застосунку),
   далі — Direct Share / віджет.
3. **Бекенд:** admin-CRUD шаблонів і allowlist, rate limiting на `/send`, кілька
   API-ключів, валідація `Recipient.Value` (E.164 / groupId).
4. **Деплой** relay на сервер xBot поруч із signal-cli (у docker-мережі xBot,
   `Signal__BaseUrl=http://signal-cli:8080`, за reverse proxy) — прибере потребу
   в SSH-тунелі; **ще не узгоджено**, на сервер без явної команди не
   розгортати. Далі — перевірка на фізичному пристрої.

## Продовження на іншому ПК (2026-10-22)

### Де зупинились

Сесія 2026-10-21/22 (Windows-ПК, `D:\src\xFastSignal`):
- Репо перенесено на внутрішній Git-сервер (`origin`); GitHub — публічне дзеркало.
- Бекенд перевірено наживо проти бойового signal-cli xBot: `/send` на контакт і
  на групу («xBot Test Group») — повідомлення доходять.
- Зроблено каркас Flutter-клієнта (див. «Стан проєкту»). Аналізатор чистий, 7 тестів
  зелені, debug APK збирається. **На пристрої/емуляторі ще не запускали.**
- **Наступна задача:** кнопки «шаблон → одержувач» (модель + збереження в
  SharedPreferences, редактор, сітка на головному, відправка з Undo ~3 с) — за
  «Баченням клієнта» вище.

### Сетап нового ПК

1. **Клон:** з основного (внутрішнього) сервера — адреса й SSH-доступ у документації
   інфраструктури, не тут; або лише для читання — з публічного дзеркала:
   ```sh
   git clone https://github.com/sovicUA/xFastSignal.git
   ```
2. **Інструменти** (версії, на яких усе працює): Flutter 3.47.2 / Dart 3.13.2,
   .NET SDK 10.0.3xx, Java 21 (не новіша — Gradle/AGP), Android SDK 36.
   ```sh
   flutter pub get
   flutter analyze && flutter test
   flutter build apk --debug   # перша збірка ~10 хв (Gradle тягне залежності)
   ```
   `android/gradle.properties` має `kotlin.incremental=false` — без цього на Windows,
   коли проєкт і pub-кеш на різних дисках, збірка падає з «Could not close incremental
   caches».
3. **Relay локально проти signal-cli xBot** — див. `backend/xSignalRelay/README.md`,
   «Розробка проти signal-cli xBot». Коротко (`<signal-host>` — SSH-хост сервера xBot,
   `<signal-cli-container>` — ім'я контейнера signal-cli з `docker ps` на ньому):
   ```sh
   IP=$(ssh <signal-host> 'docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" <signal-cli-container>')
   while true; do ssh -N -o ServerAliveInterval=30 -L 18080:$IP:8080 <signal-host>; sleep 5; done &
   cd backend/xSignalRelay
   Signal__BaseUrl=http://localhost:18080 ASPNETCORE_URLS=http://localhost:5180 dotnet run
   ```
   Тунель двічі рвався з `Connection reset by peer` (keepalive не допоміг) — звідси
   цикл. Статус relay: `http://localhost:5180/`.
4. **Локальна БД `relay.db` не в git.** На новому ПК сид створить демо-шаблони й
   фіктивного одержувача `self-note` (`+380000000000`). Реальних одержувачів додати
   вручну, напр. Python `sqlite3` (колонка `Enabled` обов'язкова):
   ```sql
   UPDATE Recipients SET Value = '+380…' WHERE Id = 'self-note';           -- свій номер
   INSERT INTO Recipients (Id, Kind, Value, DisplayName, Enabled)
     VALUES ('test-group', 'Group', '<groupId>', 'xBot Test Group', 1);
   ```
   `groupId` — з `listGroups` через тунель:
   `curl -X POST localhost:18080/api/v1/rpc -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"listGroups","id":1}'`.
   ⚠️ Номер xBot є і в **реальних** групах — для тестів брати лише «xBot Test Group».
5. **Клієнт на телефоні** (емулятора на Windows-ПК не було): USB-налагодження, потім
   ```sh
   adb reverse tcp:5180 tcp:5180
   flutter run
   ```
   У налаштуваннях застосунку: `http://localhost:5180`, ключ `dev-local-key`
   (debug-збірка дозволяє HTTP лише до `localhost` / `10.0.2.2`).

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
- **SSH до GitHub:** окремий ключ для GitHub спершу не працював — публічний ключ довелось додати на GitHub-акаунт вручну через
  Settings → SSH keys, після чого запрацював.
- **Репозиторій `xBot`** склоновано в `~/src/xBot` (по SSH) —
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
  налаштованих credentials. *(З 2026-10-21 основний — внутрішній Git-сервер, див.
  «Стан проєкту»; на Mac: `git remote set-url origin <адреса внутрішнього репо>`.)*

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
