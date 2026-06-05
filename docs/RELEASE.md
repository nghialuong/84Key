# Releasing 84Key (macOS)

Pushing a version tag (e.g. `v0.1.0`) triggers
[`.github/workflows/release.yml`](../.github/workflows/release.yml), which builds,
signs, **notarizes**, and attaches a `.dmg` to a new GitHub Release.

The workflow needs an Apple Developer account. All credentials live in **GitHub
encrypted secrets** under the `release` environment — they are never committed and
GitHub masks them in CI logs. Set them up once with the steps below.

## 1. Prerequisites

- A paid **Apple Developer** account.
- A **Developer ID Application** certificate (Keychain Access → Certificate
  Assistant, or download from the Apple Developer portal) with its private key in
  your login keychain.
- The [`gh`](https://cli.github.com) CLI, authenticated (`gh auth login`).

## 2. Export the signing certificate

In **Keychain Access**, find *Developer ID Application: …*, expand it, select both
the certificate **and** its private key, right-click → **Export 2 items…**, save as
`devid.p12`, and set an export password (you'll store it as a secret too).

Base64-encode it (CI decodes it back):

```sh
base64 -i devid.p12 -o devid.p12.b64
```

## 3. Create an App Store Connect API key (for notarization)

In [App Store Connect](https://appstoreconnect.apple.com) → **Users and Access** →
**Integrations / Keys** → **App Store Connect API**: create a key with the
**Developer** role, download the `AuthKey_XXXXXX.p8` (one-time download), and note:

- **Key ID** (e.g. `ABCDE12345`)
- **Issuer ID** (a UUID at the top of the Keys page)

Base64-encode the key:

```sh
base64 -i AuthKey_XXXXXX.p8 -o asc.p8.b64
```

## 4. Load the secrets (nothing is printed or committed)

Create the `release` environment in **Settings → Environments** on GitHub (optionally
restrict it to tag refs), then set the secrets via `gh` — values are read from files
or typed at a prompt, never echoed:

```sh
gh secret set DEVELOPER_ID_CERT_P12      --env release < devid.p12.b64
gh secret set DEVELOPER_ID_CERT_PASSWORD --env release   # paste the .p12 export password
gh secret set ASC_API_KEY_P8             --env release < asc.p8.b64
gh secret set ASC_API_KEY_ID             --env release   # paste the Key ID
gh secret set ASC_API_ISSUER_ID          --env release   # paste the Issuer ID
```

Then delete the local sensitive files:

```sh
rm -f devid.p12 devid.p12.b64 AuthKey_XXXXXX.p8 asc.p8.b64
```

| Secret | What it is |
| --- | --- |
| `DEVELOPER_ID_CERT_P12` | base64 of the `.p12` (cert + private key) |
| `DEVELOPER_ID_CERT_PASSWORD` | the `.p12` export password |
| `ASC_API_KEY_P8` | base64 of the App Store Connect `.p8` key |
| `ASC_API_KEY_ID` | the API Key ID |
| `ASC_API_ISSUER_ID` | the API Issuer ID |
| `SPARKLE_PRIVATE_ED_KEY` | Sparkle EdDSA **private** key (see §7) |

## 5. Cut a release

```sh
git tag v0.1.0
git push origin v0.1.0
```

Watch **Actions → Release**. On success a GitHub Release is created with
`84Key-v0.1.0.dmg` attached. The tag version (minus the `v`) is baked into the app's
`MARKETING_VERSION`.

> **Bump the build number first.** Sparkle decides "is this newer?" by comparing
> `CFBundleVersion` (`CURRENT_PROJECT_VERSION` in `platform/macos/project.yml`), not
> the marketing version. Increment it for every release (1 → 2 → 3 …), otherwise the
> appcast advertises an update Sparkle won't treat as newer.

Dry run: push a pre-release tag like `v0.0.1-rc1` first, then delete it and the draft
Release once verified (`git push --delete origin v0.0.1-rc1`).

## 6. Verify the DMG

On another Mac, downloading the DMG and running:

```sh
xcrun stapler validate 84Key-v0.1.0.dmg
spctl -a -t open --context context:primary-signature 84Key-v0.1.0.dmg
```

Both should pass, and the app should open without a Gatekeeper warning.

## 7. Auto-update (Sparkle)

84Key updates itself with [Sparkle](https://github.com/sparkle-project/Sparkle). The
app checks an **appcast** feed daily (and on demand via the menu's *Kiểm tra cập
nhật…*), downloads the new DMG straight from GitHub Releases, and verifies it with an
**EdDSA signature** — a Sparkle-specific signature that is *separate* from Apple
code-signing/notarization.

The release workflow signs each DMG and writes a new `<item>` into `appcast.xml` on the
**`gh-pages`** branch. The app reads that file **raw over HTTPS** at
`https://raw.githubusercontent.com/nghialuong/84Key/gh-pages/appcast.xml` (the `SUFeedURL`
in `Info.plist`). The DMG keeps living on GitHub Releases; the appcast only points at its
per-tag download URL. **Pre-release tags (anything with a `-`, e.g. `v0.1.0-rc1`) still
publish a Release but are not added to the appcast**, so stable users are never offered a
pre-release.

> **Why `raw.githubusercontent.com` and not GitHub Pages?** This account serves its
> apex domain `nghialuong.com` from Vercel, and the `nghialuong.github.io` user site
> has that as a custom domain — so GitHub 301-redirects every Pages *project* URL
> (`nghialuong.github.io/84Key/…`) to `nghialuong.com/84Key/…`, which Vercel 404s.
> `raw.githubusercontent.com` sidesteps that entirely: it serves the file from the
> public repo over HTTPS with no redirect (`Content-Type: text/plain`, which Sparkle
> parses fine). Both the repo being **public** and the feed URL matter here — a private
> repo's raw files and release assets require auth and can't be fetched by the updater.

This is a **one-time setup**. Do it once, then releases are automatic. It assumes the
repo is **public** (required so end users can download release DMGs and read the feed).

### 7a. Generate the EdDSA key pair

After the project has fetched Sparkle once (any local build, or run
`xcodegen generate && xcodebuild -resolvePackageDependencies` in `platform/macos`), the
key tools live under DerivedData. From the repo root after a `bash tools/package.sh`:

```sh
BIN=build/dd/SourcePackages/artifacts/sparkle/Sparkle/bin
"$BIN/generate_keys"                 # stores the PRIVATE key in your login Keychain,
                                     # prints the PUBLIC key (base64) — copy it
"$BIN/generate_keys" -x sparkle_private_key.txt   # export the PRIVATE key for CI
```

- Paste the printed **public** key into `platform/macos/Resources/Info.plist`, replacing
  `REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY` in `SUPublicEDKey`. (It ships inside the app and
  is safe to commit.)
- Load the exported **private** key as a secret, then delete the file:

```sh
gh secret set SPARKLE_PRIVATE_ED_KEY --env release < sparkle_private_key.txt
rm -f sparkle_private_key.txt
```

> Keep the private key safe. If it's ever lost, existing installs can't verify future
> updates and users must re-download manually; if it leaks, rotate it (new key pair →
> new public key in `Info.plist` → ship that build before signing further updates).

### 7b. The `gh-pages` branch (appcast home)

The appcast lives on an orphan **`gh-pages`** branch (it holds only `appcast.xml` plus a
`.nojekyll`). It's already created and seeded with an empty feed; the release workflow
appends to it. No GitHub Pages site is needed — the feed is read raw. Confirm it's
reachable:

```sh
curl -fsSL https://raw.githubusercontent.com/nghialuong/84Key/gh-pages/appcast.xml | head
```

> `raw.githubusercontent.com` is CDN-cached for ~5 minutes, which is fine for an
> update feed. If you later want a branded/faster feed, point Sparkle at a real host
> (e.g. add an `appcast.xml` route to the `nghialuong.com` Vercel site, or a Pages
> site on a domain that isn't shadowed) and update `SUFeedURL`.

### 7c. How a release feeds the updater

Each stable release, the workflow (`Update Sparkle appcast` step) automatically:

1. Signs `84Key-vX.Y.Z.dmg` with the EdDSA private key (`sign_update`).
2. Runs [`tools/update_appcast.py`](../tools/update_appcast.py) to splice a new
   newest-first `<item>` into `appcast.xml` (preserving older items and their per-tag
   download URLs), then commits and pushes it to `gh-pages`.

No manual steps once 7a is done — just bump the build number and push a tag (§5).

## How secrets stay safe

- Stored as **GitHub encrypted secrets** in the `release` environment; GitHub
  auto-masks them in logs.
- The workflow only triggers on **tag pushes**, so pull requests from forks can never
  run it or read the secrets.
- The job imports the certificate into a **temporary keychain** with a random password
  and **deletes the keychain and key files** on completion (even on failure).
- The workflow requests only `contents: write` (enough to publish a Release).
- Build artifacts (`build/`, `*.dmg`, `*.app`) are git-ignored — never committed.
