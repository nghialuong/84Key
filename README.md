# 84Key

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)

A free, open-source Vietnamese input method (bộ gõ tiếng Việt) for macOS.

84Key takes its name from Vietnam's +84 international calling code. It reuses
the proven [OpenKey](https://github.com/tuyenvm/OpenKey) C++ typing engine and
wraps it in a modern SwiftUI menu-bar app, adding two flagship improvements:
automatic English-word detection and a Spotlight diacritic-placement fix.

> macOS only for now. Windows and Linux are planned for the future.

## Features

- **Accurate Vietnamese typing** with Telex, VNI, and Simple Telex input
  methods, backed by the battle-tested OpenKey engine.
- **Smart automatic English detection** — when you type an English word in
  Telex, 84Key recognizes it and skips diacritic transformation, so words like
  "feed" or "tools" come out correctly without fighting the IME.
- **Spotlight fix** — corrects diacritic placement inside Spotlight and other
  apps that mishandle composed input, using the macOS Accessibility API.
- **Menu-bar app** — a lightweight SwiftUI app that lives in your menu bar with
  settings and a guided Accessibility onboarding flow.
- **Multiple code tables** — Unicode (default), TCVN3, VNI-Windows, Unicode
  Compound, and CP1258.
- **No telemetry, ever** — 84Key does not phone home.

## Privacy

84Key is **100% local**. All keystroke processing happens on your Mac.

- **No telemetry.** 84Key collects no usage data or analytics.
- **No network calls for typing.** Nothing you type is ever sent anywhere.
- **No accounts, no tracking.**

84Key requires the macOS **Accessibility** permission to function, because it
uses a `CGEvent` tap to read and replace text as you type. This permission is
used solely on-device to deliver correct Vietnamese input and the Spotlight
fix. 84Key intentionally avoids acting in secure-input/password fields.

## Installation & setup

1. Build the app (see **Building** below) or download a release.
2. Launch 84Key. It appears in your menu bar.
3. Grant the **Accessibility** permission when prompted
   (System Settings → Privacy & Security → Accessibility). The onboarding flow
   guides you through this.
4. **Disable other Vietnamese IMEs** such as OpenKey or EVKey while using
   84Key. Running more than one Vietnamese input method at the same time causes
   conflicting keystrokes and garbled output.

> Bundle identifier: `com.nghialuong.key84`.

## Building

Requirements: **macOS** with **Xcode** installed, and **[XcodeGen](https://github.com/yonsm/XcodeGen)**
(`brew install xcodegen`) to generate the Xcode project.

- **C++ engine tests** (platform-independent, also run in CI):

  ```sh
  bash core/tests/run_tests.sh
  ```

- **macOS app:**

  ```sh
  cd platform/macos
  xcodegen generate            # regenerate 84Key.xcodeproj from project.yml
  xcodebuild -scheme 84Key -configuration Debug CODE_SIGNING_ALLOWED=NO build
  ```

- **Regenerate the dictionaries** (English from google-10000-english, Vietnamese
  from rules):

  ```sh
  python3 tools/gen_dict.py
  ```

See [`docs/BUILD.md`](docs/BUILD.md) for details and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
for how the engine and app fit together.

Notarized distribution requires an Apple Developer account (planned for a
future release); local development builds do not.

## Credits

- **[OpenKey](https://github.com/tuyenvm/OpenKey)** by Mai Vũ Tuyên — the
  Vietnamese typing engine that powers 84Key. Licensed under GPLv3.
- **[google-10000-english](https://github.com/first20hours/google-10000-english)**
  — the English word list used for automatic English detection (public domain /
  MIT).

## License

84Key is licensed under the **GNU General Public License v3.0 (GPLv3)**. See the
[LICENSE](LICENSE) file for the full text.

Because 84Key derives its typing engine from OpenKey, which is GPLv3, 84Key
must remain GPLv3. See [NOTICE](NOTICE) for attribution details.

---

# Tiếng Việt

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)

84Key là bộ gõ tiếng Việt miễn phí, mã nguồn mở dành cho macOS.

Tên gọi "84Key" lấy cảm hứng từ mã vùng điện thoại quốc tế +84 của Việt Nam.
84Key sử dụng lại engine gõ tiếng Việt viết bằng C++ của
[OpenKey](https://github.com/tuyenvm/OpenKey) và đóng gói trong một ứng dụng
SwiftUI hiện đại trên thanh menu, bổ sung hai cải tiến nổi bật: tự động nhận
diện từ tiếng Anh và sửa lỗi đặt dấu trong Spotlight.

> Hiện chỉ hỗ trợ macOS. Windows và Linux sẽ được hỗ trợ trong tương lai.

## Tính năng

- **Gõ tiếng Việt chính xác** với các kiểu gõ Telex, VNI và Simple Telex, dựa
  trên engine OpenKey đã được kiểm chứng.
- **Tự động nhận diện tiếng Anh** — khi bạn gõ một từ tiếng Anh trong kiểu
  Telex, 84Key nhận ra và bỏ qua việc bỏ dấu, nên những từ như "feed" hay
  "tools" hiển thị đúng mà không phải tắt bộ gõ.
- **Sửa lỗi Spotlight** — sửa vị trí dấu trong Spotlight và các ứng dụng xử lý
  sai chữ tổ hợp, nhờ Accessibility API của macOS.
- **Ứng dụng thanh menu** — ứng dụng SwiftUI gọn nhẹ nằm trên thanh menu, có
  phần cài đặt và hướng dẫn cấp quyền Trợ năng (Accessibility).
- **Nhiều bảng mã** — Unicode (mặc định), TCVN3, VNI-Windows, Unicode tổ hợp và
  CP1258.
- **Không thu thập dữ liệu.**

## Quyền riêng tư

84Key hoạt động **hoàn toàn cục bộ** trên máy của bạn.

- **Không gửi dữ liệu thống kê.** 84Key không thu thập dữ liệu sử dụng.
- **Không kết nối mạng khi gõ.** Những gì bạn gõ không bao giờ được gửi đi đâu.
- **Không tài khoản, không theo dõi.**

84Key cần quyền **Trợ năng (Accessibility)** của macOS để hoạt động, vì ứng
dụng dùng `CGEvent` tap để đọc và thay thế văn bản khi bạn gõ. Quyền này chỉ
được dùng ngay trên máy để gõ tiếng Việt chính xác và sửa lỗi Spotlight. 84Key
chủ động không can thiệp vào các ô nhập mật khẩu (secure input).

## Cài đặt & thiết lập

1. Tự build ứng dụng (xem mục **Building** ở trên) hoặc tải bản phát hành.
2. Mở 84Key. Ứng dụng xuất hiện trên thanh menu.
3. Cấp quyền **Trợ năng** khi được yêu cầu
   (System Settings → Privacy & Security → Accessibility). Phần hướng dẫn sẽ
   chỉ bạn từng bước.
4. **Tắt các bộ gõ tiếng Việt khác** như OpenKey hoặc EVKey khi dùng 84Key.
   Chạy nhiều bộ gõ cùng lúc sẽ gây xung đột phím và sai chữ.

> Mã định danh ứng dụng (bundle id): `com.nghialuong.key84`.

## Ghi công

- **[OpenKey](https://github.com/tuyenvm/OpenKey)** của Mai Vũ Tuyên — engine
  gõ tiếng Việt làm nền tảng cho 84Key (giấy phép GPLv3).
- **[google-10000-english](https://github.com/first20hours/google-10000-english)**
  — danh sách từ tiếng Anh dùng cho tính năng nhận diện tiếng Anh (public
  domain / MIT).

## Giấy phép

84Key được phát hành theo giấy phép **GNU General Public License v3.0 (GPLv3)**.
Xem tệp [LICENSE](LICENSE) để biết toàn văn.

Vì 84Key dùng lại engine từ OpenKey (vốn theo GPLv3), 84Key cũng phải giữ giấy
phép GPLv3.
