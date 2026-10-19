# Contribution workflow

1. Select an unchecked roadmap task and define observable acceptance criteria.
2. Create a focused branch such as `feat/cloud-encounter` or `docs/event-rules`.
3. Keep changes small and update design documents when behavior changes.
   Maintain CHANGELOG.md for every version update; keep the README focused on
   current setup and shipped behavior. Update the version, changelog, and README
   together and run `dart tool/check_release.dart` before submitting.
4. Run applicable formatting, analysis and meaningful tests after the application exists.
5. Open a pull request describing the problem, behavior and validation.

Never commit credentials, signing keys, personal player data or unlicensed artwork. Keep the MVP offline. Do not mark planned features as implemented.
