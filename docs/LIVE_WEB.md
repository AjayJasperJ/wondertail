# Live browser testing

The 3D game can publish to **https://ajayjasperj.github.io/wondertail/**
after GitHub Pages is enabled and the deployment succeeds.

## One-time repository setting

1. Open [Settings → Pages](https://github.com/AjayJasperJ/wondertail/settings/pages).
2. Under **Build and deployment**, select **Source: GitHub Actions**.
3. Open [Wondertail 3D](https://github.com/AjayJasperJ/wondertail/actions/workflows/godot.yml)
   and run the workflow on `main`, or rerun all jobs in the latest run.

The connected repository tools cannot change Pages administration settings.
The default Actions token cannot enable Pages either, so this setting must be
made by the repository owner. Do not add a personal access token to the project.

This repository is private. GitHub Pages requires an eligible paid GitHub plan
to publish from private repositories. If GitHub shows an upgrade prompt, the
alternatives are a separate public repository containing only web build files,
or another static host. Keep the source repository private unless you decide
otherwise. The published game files are public even when source remains private.

## Daily testing

Push a game change to `main`. The existing Wondertail 3D workflow imports the
models, runs engine and rendering checks, and exports the builds. Only after
that build succeeds does **Publish live browser game** deploy the web artifact.
Pull requests build for checking but never deploy.

Open the same web link in a modern WebGL 2 browser, turn your phone landscape,
and tap the game to enable audio. Refresh after the deployment turns green to
load the latest build. There is no APK to download or install. First load still
downloads the game's assets, so use Wi-Fi for testing if needed.

Every build exports its JS, WASM and PCK using its full commit SHA in the file
names. This prevents mixed cached resources after an update. No service worker
is installed; this preview does not promise offline startup. The site's HTML
can briefly remain cached by GitHub's CDN; retry a refresh if an update has only
just published. The current deployed commit is available at `version.json`.

## Saves and performance

Browser progress is stored locally in this browser's storage, separate from
Android saves. Use the same browser and site address to retain it. Clearing
site data, private browsing or storage eviction can lose browser progress.
The game does not automatically migrate Android progress to the browser.

The web export uses Godot's Compatibility renderer and a single-threaded
template, so Pages does not need custom cross-origin isolation headers.
Performance can differ from the Android app; use Low graphics on slower phones.
Desktop keyboard controls and mobile touch controls remain available.

## Deployment troubleshooting

A failed **Configure GitHub Pages** step usually means Pages has not been enabled,
the account plan does not support private-repository Pages, or Pages permissions
are restricted. Check Settings → Pages and the failed step's message first.
A pending environment approval must be approved in the Actions deployment view.
A build failure leaves the previously deployed site in place.

The workflow publishes only `three_d/build/web/`, never the repository or APKs.
See the deployment job's summary and `github-pages` environment for its actual
published URL, especially if you later configure a custom domain.
