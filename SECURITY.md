# Security Policy

## Supported versions

84Key is in early development. Security fixes are provided for the latest
`0.1.x` release line.

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅        |
| < 0.1   | ❌        |

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue, as
that could expose users before a fix is available.

You can report a vulnerability through either of:

1. **GitHub Security Advisories** (preferred):
   <https://github.com/nghialuong/84Key/security/advisories/new>
2. **Email:** [INSERT SECURITY EMAIL]

Please include a description of the issue, steps to reproduce, the affected
version, and any relevant environment details. We aim to acknowledge reports
promptly and will keep you informed as we investigate and prepare a fix.
Coordinated disclosure is appreciated: please give us a reasonable window to
release a fix before any public discussion.

## Privacy & data handling

84Key is designed to be trustworthy and privacy-respecting:

- All input handling happens **locally on your device**. The keyboard-event
  processing pipeline that turns your typing into Vietnamese text runs entirely
  on-device.
- 84Key makes **no network requests** for its typing functionality, contains
  **no telemetry**, and **does not transmit, store, or share** what you type.
- The app requests macOS **Accessibility** permission because the input handling
  pipeline needs it to read and replace text in the focused field (for example,
  to place diacritics correctly). This permission is used solely for on-device
  text input and for nothing else.
- 84Key intentionally avoids acting in secure-input contexts (such as password
  fields), where the system restricts input handling.

Builds are reproducible from source so the behavior above can be independently
verified.
