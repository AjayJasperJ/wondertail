# Wondertail repository rules

- Read the current README, CHANGELOG, and relevant game rules before editing.
- Keep CHANGELOG.md updated for every version update. Add changes to the current
  unreleased entry while developing; record the exact version and release date
  when bumping pubspec.yaml. Never claim planned work is implemented.
- Keep README.md short and current: setup, supported features, downloads, and
  documentation links. Put version history in CHANGELOG.md and detailed game
  behavior in docs/. Remove stale or conflicting feature statements.
- When changing the version, update the README and changelog together. Keep the
  APK packaging version derived from pubspec.yaml rather than hard-coding it.
- Preserve older saves. Test reward idempotence, failed writes, and profile/normal
  world isolation whenever changing progression or challenge modes.
- Keep the normal game offline and untimed. Challenge timers must be optional,
  pause during menus/backgrounding, and never erase normal progress.
- Run formatting, dart tool/check_release.dart, flutter analyze, meaningful
  tests, and the affected release builds. Report device-testing limits honestly.
- Never commit credentials, signing keys, personal saves, or unlicensed assets.
