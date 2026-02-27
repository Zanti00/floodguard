# AI Readme — FloodGuard 🤖📘

> Purpose: This file is an AI-oriented guide that explains the repository, important files, runtime requirements, SMS alert system behavior, coding conventions, testing expectations, and step-by-step instructions for how an AI assistant should handle tasks and feature requests.

---

## Quick project overview ✅

- Name: FloodGuard
- Tech: Flutter (Dart) mobile app (Android / iOS / web / desktop targets present)
- Main features:
  - Display data pulled from external APIs (weather/flood feeds, hotline info, etc.)
  - SMS alerting system to send notifications to subscribed users
  - On-device UI: pages in `lib/pages/` and widgets in `lib/widgets/`

## Where to look 🔎

- Entry point: `lib/main.dart`
- Services: `lib/services/` (look for SMS/OTP, API clients, etc.) — e.g., `lib/services/otp_service.dart`
- Controllers: `lib/Controller/` (Bluetooth controllers exist here)
- Pages: `lib/pages/` (UI screens like `dashboard_page.dart`, `chat_page.dart`)
- Assets: `assets/`, `data/hotline.json`
- Pubspec: `pubspec.yaml` (packages and assets)
- Tests: `test/`

> Tip: When handling SMS, search the repo for keywords: `sms`, `otp`, `twilio`, `sendSms`, `subscribe`, `hotline`.

## Environment & run instructions ▶️

Prerequisites: Flutter SDK installed, platform toolchains (Android SDK, Xcode for macOS/iOS), set up devices/emulators.

Common commands:

- Install deps: `flutter pub get`
- Run app: `flutter run -d <device>`
- Analyze: `dart analyze` or `flutter analyze`
- Format: `dart format .`
- Tests: `flutter test`

Environment variables (expect these to be used or added):

- `API_BASE_URL` — base URL for data APIs
- `SMS_PROVIDER` — provider key (e.g., `twilio`, `nexmo`, `mock`)
- `SMS_API_KEY` — API key/secret for SMS provider
- `SMS_SENDER_NUMBER` — sending phone number or service ID

Never commit secrets into the repo. Use `.env`, secrets manager, or CI-protected variables.

## SMS Alert System — Design & expectations 🔔

- Users subscribe to receive alerts (UI + persisted subscription storage). Confirm where subscribers are stored (local DB, remote DB, or backend service).
- Sending flow:
  1. Build SMS message (include opt-out text if required by law/region).
  2. Use an SMS provider client (abstract via an interface so providers are swappable).
  3. Call provider API and record send status for retries and audit.
- Important constraints:
  - Always support opt-out/unsubscribe flows and track consent.
  - Avoid sending SMS in test or local environments (use mocks or a `mock` provider).
  - Respect rate limits and provider terms.

Implementation checklist for adding or modifying SMS providers:

- Add provider implementation behind an interface (e.g., `SmsProvider` or similar)
- Add configuration via env vars and `pubspec` dependencies
- Add unit tests for the provider and integration-style tests with mocked network
- Add logging and error handling with retries and exponential backoff
- Document the provider in this README under the providers section

## Testing & CI ✅

- Unit tests: `test/` for pure Dart logic
- Widget tests: test presentation and basic interaction
- Integration tests: optional for end-to-end
- When writing tests that may trigger SMS, always mock the SMS client and verify calls, not external sends
- CI: ensure `dart analyze`, `dart format --verify-no-changes`, and `flutter test` are required steps

## Security & Compliance ⚖️

- Do NOT store or print API secrets or user phone numbers in logs
- Implement opt-in/opt-out and record consent timestamp
- Sanitize and validate phone numbers (E.164 format preferred)
- Adhere to local SMS laws (e.g., opt-in requirement, opt-out keywords)

## Coding Conventions & PR rules 🧭

- Language: Dart with null safety
- Format via `dart format` and analyze via `dart analyze`
- Tests required for new behavior or bug fixes
- Commit message pattern: `<area>: <short summary>` (e.g., `sms: add twilio provider`) and include a short description in the PR
- Branch naming: `feature/<short-description>`, `fix/<short-description>`
- Small incremental PRs are preferred; each PR should include tests and docs if behavior changes
- Add `CHANGELOG.md` entry for user-facing changes

## How the AI assistant should operate — step-by-step workflow 🤖➡️👨‍💻

1. Read this file and archive it as the project policy document for task context.
2. When asked to implement a feature or fix a bug:
   - Summarize the requested change in one paragraph and list assumptions.
   - Search the repo for relevant files (e.g., search `otp`, `sms`, `hotline`) and list the files you will modify.
   - Propose a short plan: files changed, tests to add, and any required configuration.
   - Implement changes in small commits: code + tests + docs/README update.
   - Run `dart analyze`, `dart format`, and `flutter test` locally; fix failures until clean.
   - Create a concise PR description: what changed, why, test summary, and migration notes if any.
3. If the task may send SMS (production action), ask for explicit approval before running any live sends or deploying.

## Useful prompts / examples for you to use when asking the AI 📝

- "Add Twilio SMS provider with env-config, unit tests, and documentation." ✅
- "Implement opt-out keywords and store opt-out in subscriber records." ✅
- "Write unit tests for `otp_service.dart` and mock the SMS provider." ✅
- "Find all places SMS is sent and convert them to use a new provider interface." ✅

## Troubleshooting & hunting tips 🔧

- If SMS isn't sent: search for `sendSms`, `otp`, or calls to external endpoints in `lib/services/`.
- If tests fail on CI but pass locally: check environment variables and mocked network behavior.
- If phone formatting issues occur: ensure normalization to E.164 and add tests for edge cases.

## Documentation & change tracking 📚

- Keep `AI_README.md` updated when adding providers, important schema changes, or new runtime requirements
- Add short entries to `CHANGELOG.md` for user-facing changes

---

> If you want, I can also:
>
> - Create skeleton tests for `lib/services/otp_service.dart` (mocked SMS provider)
> - Add a Twilio provider skeleton behind an interface
> - Add a short checklist template and GitHub PR template to the repo

**Maintainer / contact:** (fill in your preferred contact info here)

---

_Last update: Jan 25, 2026_
