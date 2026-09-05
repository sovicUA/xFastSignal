# xSignalRelay

Бекенд-мікросервіс для [xFastSignal](../../README.md). Приймає авторизований запит
«надішли шаблон X одержувачу Y» і виконує його через `signal-cli` daemon (той самий
контейнер, що використовує [xBot](../../../xBot)). xBot при цьому не змінюється.

- **Стек:** ASP.NET Core minimal API, net10.0.
- **Сховище:** SQLite (шаблони + allowlist одержувачів), редагується в рантаймі.
- **До signal-cli:** напряму, `POST {Signal:BaseUrl}/api/v1/rpc`, метод `send`. Send-only —
  вхідний потік (SSE) лишається за xBot.

## API

Усі ендпоінти (крім `/health`) вимагають заголовок `X-Api-Key: <ApiKey>`.

| Метод | Шлях          | Опис |
|-------|---------------|------|
| GET   | `/health`     | Ліваність (без авторизації). |
| GET   | `/templates`  | `[{ id, name, params: [...] }]` — доступні шаблони. |
| GET   | `/recipients` | `[{ id, kind, displayName }]` — allowlist (без сирих номерів). |
| POST  | `/send`       | `{ templateId, target, params? }` → `202 { sent: true }`. |

`target` — це `id` одержувача з `/recipients`, не номер телефону. Сирі значення
(`+380…`, base64 groupId) не залишають бекенд.

Коди помилок `/send`: `400` (немає полів / бракує значення плейсхолдера),
`404` (немає шаблону), `403` (одержувач не в allowlist), `502` (signal-cli не надіслав).

## Локальний запуск

```sh
# signal-cli daemon (з репо xBot):
cd ../../../xBot && SIGNAL_PHONE_NUMBER=+380XXXXXXXXX docker compose -f docker-compose.signal.yml up -d

cd -
dotnet run
# слухає http://localhost:5xxx; Signal:BaseUrl за замовч. http://localhost:8080
```

У `appsettings.Development.json` вже є `ApiKey=dev-local-key` і `Seed` з кількома
демо-шаблонами (щоб `/send` було на чому тестувати). Замініть номер у `Seed:Recipients`
на реальний або відредагуйте таблицю `Recipients` напряму.

```sh
curl -H "X-Api-Key: dev-local-key" http://localhost:5xxx/templates
curl -X POST http://localhost:5xxx/send \
  -H "X-Api-Key: dev-local-key" -H "Content-Type: application/json" \
  -d '{"templateId":"running-late","target":"self-note","params":{"minutes":"15"}}'
```

## Docker

```sh
# спершу signal-cli + xbot:
cd ../../../xBot && SIGNAL_PHONE_NUMBER=+380XXXXXXXXX docker compose up -d
cd -
RELAY_API_KEY=$(openssl rand -hex 24) docker compose up -d --build
# relay на порту 8082 хоста; всередині мережі — http://xsignalrelay:8080
```

## Конфігурація

| Ключ | Env | Замовч. | Опис |
|------|-----|---------|------|
| `Signal:BaseUrl` | `Signal__BaseUrl` | `http://localhost:8080` | Адреса signal-cli daemon. |
| `Db:Path` | `Db__Path` | `relay.db` | Файл SQLite. |
| `ApiKey` | `ApiKey` | — | Ключ, який очікується в `X-Api-Key`. Обовʼязковий. |
| `Seed:Enabled` | `Seed__Enabled` | `false` | Наповнити порожні таблиці з `Seed:Templates` / `Seed:Recipients`. |

## Стан / далі

- [ ] Admin-CRUD ендпоінти для шаблонів та allowlist (щоб редагувати з застосунку) —
      зараз лише сид з конфіга + правка БД напряму.
- [ ] Rate limiting на `/send`.
- [ ] Кілька API-ключів / per-key обмеження шаблонів.
- [ ] Валідація формату `Recipient.Value` (E.164 / groupId) при записі.
