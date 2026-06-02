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

## 5. Cut a release

```sh
git tag v0.1.0
git push origin v0.1.0
```

Watch **Actions → Release**. On success a GitHub Release is created with
`84Key-v0.1.0.dmg` attached. The tag version (minus the `v`) is baked into the app's
`MARKETING_VERSION`.

Dry run: push a pre-release tag like `v0.0.1-rc1` first, then delete it and the draft
Release once verified (`git push --delete origin v0.0.1-rc1`).

## 6. Verify the DMG

On another Mac, downloading the DMG and running:

```sh
xcrun stapler validate 84Key-v0.1.0.dmg
spctl -a -t open --context context:primary-signature 84Key-v0.1.0.dmg
```

Both should pass, and the app should open without a Gatekeeper warning.

## How secrets stay safe

- Stored as **GitHub encrypted secrets** in the `release` environment; GitHub
  auto-masks them in logs.
- The workflow only triggers on **tag pushes**, so pull requests from forks can never
  run it or read the secrets.
- The job imports the certificate into a **temporary keychain** with a random password
  and **deletes the keychain and key files** on completion (even on failure).
- The workflow requests only `contents: write` (enough to publish a Release).
- Build artifacts (`build/`, `*.dmg`, `*.app`) are git-ignored — never committed.
