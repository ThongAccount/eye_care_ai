# Security notes — EyeCare AI (mobile release)

Status as of 2026-10-24. Everything below was verified against the live repo
(`ThongAccount/eye_care_ai`, **public**) and the live GitHub Releases API.

## 1. NVIDIA NIM key is shipped inside every release APK — OPEN, needs rotation

`build-apk.yml` builds the release APK with
`--dart-define=NIM_API_KEY=${{ secrets.NIM_API_KEY }}`. A `--dart-define` value
is compiled into the app, so the key ends up as a plain string inside
`lib/arm64-v8a/libapp.so` and `lib/armeabi-v7a/libapp.so` of the published
APK. The repo and its Releases are public → **anyone can download an APK and
extract a working key**.

Verified: the key in the build-92 APK authenticates against
`https://integrate.api.nvidia.com/v1/models` (HTTP 200, 85 models).

A second, older key (`nvapi-lV_LIdtyP…`) is still reachable in the git history
— `lib/config/local_env.dart` at commit `036505d` — and it also authenticates
(HTTP 200, 85 models). Redaction in `ba4f4de` did not purge the history.

**What must happen (owner action, not a code change):**

1. Revoke/rotate the NVIDIA NIM key currently shipped in the APK.
2. Revoke/rotate the older key exposed in the git history.
3. Stop putting the key in the client. A `--dart-define` can never be secret:
   the only correct place for an account key is a backend that holds it and
   proxies the NIM calls. Until that proxy exists, either accept the exposure
   knowingly or build release APKs without `--dart-define=NIM_API_KEY` (AI chat
   then only works for people running a debug build with their own key).

Guard added meanwhile: `build-apk.yml` now scans the whole source tree for
secret patterns before it builds (`Scan source tree for secrets`). The local
`scripts/githooks/pre-push` guard only covers lines a developer just added and
only on machines where it is installed; CI covers the whole tree.

## 2. Release signing material was committed publicly — mostly stale

| Artifact | Where | State |
|---|---|---|
| `release-keystore-base64.txt` | commit `e28710e`, still downloadable | base64 of a 2,712-byte PKCS#12 keystore; its password is unknown to us and it is **not** the key that signs today's builds |
| `upload-keystore.jks` + `android/key.properties` | commit `6a41e0b` | upload key with its password in the same history — must be rotated before any Play upload |
| `android/app/ci-fallback-keystore.jks` | tracked on `main` | fallback signing key with the password hardcoded in `android/app/build.gradle.kts` |
| live release keystore | GitHub Actions secrets (`KEYSTORE_BASE64`, …) | cert sha256 `bcc23b01…` (CN=EyeCare AI, O=ThongAccount) — matches none of the artifacts above |

Consequences and the safe order of operations:

- The **fallback** key does not sign the published APK, so a fake APK signed
  with it cannot silently replace the real app (signature mismatch), but it
  does let anyone claim our application id `com.eyecare.eye_care_ai`.
- **Do not rotate the live release signing key** while the app is distributed
  as a direct APK: Android refuses updates signed with a different key. Enrol
  in **Play App Signing** with a fresh upload key first, then rotate the
  upload key.
- `backup-keystore.yml` exists but has **0 runs** — the documented keystore
  backup has never actually been produced. Run it (it needs
  `RECOVERY_PASSPHRASE`).
- The keystore password must never live in a notes vault or a repo. The
  memory vault currently still stores it in plain text
  (`journal/2026-08-08-eye-care-ai.md`) — that entry has to be replaced by a
  pointer to the secret store, and the vault owner (VaultBot) owns that fix.

## 3. Other release-pipeline rules

- The `release/` folder is ignored by `.gitignore` but two APKs (build-57 and
  build-58) had been committed, which made the `release/*.apk` glob attach
  those stale binaries to every new release. The updater then downloaded the
  wrong APK. Fixed in `aad5e2c` (asset is picked by build number, workflow
  cleans `release/` and attaches the exact file, stale APKs untracked).
- Version/build numbers are monotonic and come from `github.run_number`
  (`build-<run_number>`), which is also the APK `versionCode`. Never reuse or
  hand-edit them.
- `flutter analyze --no-fatal-warnings --no-fatal-infos` and `flutter test`
  run before every release build, so a red test must not ship.
