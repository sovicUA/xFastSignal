# xFastSignal

Android-застосунок для швидкої — в ідеалі автоматичної — відправки заздалегідь
визначених повідомлень у **Signal**, без ручного відкриття Signal і вибору контакту
щоразу (кнопки / App Shortcuts / Direct Share).

> Статус: рання розробка. Flutter-клієнт поки що заготовка; готовий бекенд-мікросервіс
> `xSignalRelay`. Історія рішень — у [NOTES.md](NOTES.md).

## Архітектура

Три рівні:

1. **signal-cli** (daemon у контейнері) — тримає зареєстрований/лінкований номер Signal,
   говорить JSON-RPC. Спільний із проєктом `xBot`.
2. **[`backend/xSignalRelay`](backend/xSignalRelay)** — тонкий ASP.NET Core (net10.0)
   мікросервіс: приймає авторизований запит «надішли шаблон X одержувачу Y» і виконує
   його через signal-cli. SQLite для шаблонів і allowlist одержувачів; клієнт бачить
   одержувачів лише за opaque `id` — сирі номери не залишають бекенд. Має сторінку
   статусу (`/`) і Swagger (`/swagger`).
3. **xFastSignal** (цей Flutter-застосунок, лише Android) — б'є в `POST /send` мікросервіса.

Клієнт свідомо не дублює інтеграцію з signal-cli. Деталі й відкинуті альтернативи —
у [NOTES.md](NOTES.md).

## Структура репозиторію

| Шлях | Що |
|------|-----|
| `lib/`, `android/` | Flutter-застосунок (org `ua.vn.log`, `applicationId ua.vn.log.xfastsignal`) |
| `backend/xSignalRelay/` | бекенд-мікросервіс — див. його [README](backend/xSignalRelay/README.md) |
| `NOTES.md` | архітектурні рішення та їх обґрунтування |

## Розробка

Клієнт:

```sh
flutter pub get
flutter run
```

Бекенд — див. [backend/xSignalRelay/README.md](backend/xSignalRelay/README.md).

## Безпека

Ендпоінт мікросервіса надсилає повідомлення від імені прив'язаного номера, тому
можливості навмисно звужені: **фіксовані шаблони** + **allowlist одержувачів**,
не «довільний текст на будь-який номер».
