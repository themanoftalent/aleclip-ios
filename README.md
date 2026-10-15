# AleClip for iOS (iPhone & iPad)

<p align="center">
  <img src="AleClip/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="128" height="128" style="border-radius: 28px;" alt="AleClip App Icon" />
</p>

<p align="center">
  <b>The modern, colorful, and privacy-first clipboard companion for iPhone and iPad.</b><br>
  Built with Swift 6 & SwiftUI. 100% On-Device, Zero Telemetry.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0%2B-blue.svg?style=flat-square" alt="iOS 17.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square" alt="Swift 6" />
  <img src="https://img.shields.io/badge/Version-2.0.1%20(2026)-success.svg?style=flat-square" alt="Version 2.0.1" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square" alt="MIT License" />
  <img src="https://img.shields.io/badge/Privacy-100%25%20On--Device-brightgreen.svg?style=flat-square" alt="Privacy" />
</p>

---

## Highlights

- **Instant & Privacy-First Clipboard Monitoring**: Captures copied text, links, color codes, and images seamlessly when the app is active.
- **Accidental Deletion Protection & Trash Recovery**: Never lose an important memo or link! Features instant 5-second Undo banners (⌘Z / floating toast) and a dedicated Trash folder with one-tap restoration.
- **Native iOS Share Sheet Extension**: Share text, links, and photos directly into AleClip from Safari, Notes, Twitter, Photos, and any other iOS app.
- **Vibrant Spectrum Aesthetic (Zero Pink)**: Crafted using a radiant, custom palette across Electric Cyan, Cobalt Azure, Neon Mint, Emerald Green, Electric Lime, and Sunburst Gold.
- **Smart Filter Categories**: Filter instantaneously across *All*, *Pinned*, *Text*, *Links*, *Images*, *Files*, *Colors*, and *Trash*.
- **Interactive Inspector & Editor**: Tap any clip to view full details, edit text notes, zoom images, open URLs directly in Safari, or inspect color swatches.
- **Bi-Directional Backup & JSON Export**: Export your complete clip archive to JSON to migrate seamlessly between iPhone, iPad, and Mac.
- **Full Bilingual Localization**: English and Turkish (Türkçe) with dynamic in-app switching.
- **100% Privacy & Zero Telemetry**: Zero analytics, zero ad SDKs, zero cloud tracking. Complies with Apple's `PrivacyInfo.xcprivacy` specification.

---

## Project Structure

```text
aleclip-ios/
├── AleClip/
│   ├── App/
│   │   └── AleClipApp.swift               # SwiftUI App lifecycle & deep links
│   ├── Models/
│   │   └── ClipItem.swift                 # ClipItem model & ClipType enum
│   ├── Services/
│   │   ├── StorageService.swift           # App Group / sandbox persistence & Trash
│   │   ├── ClipboardService.swift         # iOS pasteboard ingest & toast detection
│   │   ├── LocalizationService.swift      # Dynamic English/Turkish translations
│   │   └── HapticService.swift            # iOS tactile haptic feedback
│   ├── Views/
│   │   ├── MainView.swift                 # Main screen, search, category pills & list
│   │   ├── ClipRowView.swift              # Card row, badges, swipe actions, context menu
│   │   ├── ClipDetailView.swift           # Full editor, image zoom & URL opener
│   │   ├── NewClipSheet.swift             # Manual note & clip creation sheet
│   │   ├── SettingsView.swift             # Preferences, storage management & backup
│   │   ├── WatermarkLogoView.swift        # Spectrum "ALE" logo lockup (zero pink)
│   │   └── ToastBannerView.swift          # Spring-animated floating toast & Undo pill
│   ├── Resources/
│   │   ├── Assets.xcassets/               # AppIcon (1024x1024) & AccentColor
│   │   ├── PrivacyInfo.xcprivacy          # Apple Privacy Manifest (0 tracking)
│   │   ├── en.lproj/Localizable.strings   # English translations
│   │   └── tr.lproj/Localizable.strings   # Turkish translations
│   └── Info.plist                         # Version 2.0.1 (2026), URL schemes
├── AleClipShareExtension/
│   ├── ShareViewController.swift          # Native iOS Share Sheet integration
│   └── Info.plist                         # Activation rules (text, links, images)
├── AleClip.xcodeproj/                     # Xcode Project (PBX 56, iOS 17.0+ deployment)
├── AppStore/
│   ├── METADATA.md                        # App Store descriptions, keywords & metadata
│   ├── PRIVACY_POLICY.md                  # Zero-telemetry Privacy Policy
│   └── APP_STORE_SUBMISSION_GUIDE.md      # Detailed App Store submission guide
└── .github/workflows/
    └── ios-build.yml                      # CI/CD workflow for automated builds & archiving
```

---

## App Store Submission

All App Store Connect metadata, descriptions, keywords, privacy declarations, and step-by-step instructions are ready:

- 📋 [**App Store Metadata & Keywords**](AppStore/METADATA.md)
- 🔒 [**Zero-Telemetry Privacy Policy**](AppStore/PRIVACY_POLICY.md)
- 🚀 [**Step-by-Step App Store Submission Guide**](AppStore/APP_STORE_SUBMISSION_GUIDE.md)

---

## Building Locally in Xcode

1. Open `AleClip.xcodeproj` in Xcode 15 or 16:
   ```bash
   open AleClip.xcodeproj
   ```
2. Select your development team under **Signing & Capabilities**.
3. Choose an iPhone simulator or connected physical iOS device.
4. Press `Cmd + R` to build and run!

---

---

## ☕ Sponsor or Buy Me a Coffee

If you find this project helpful, consider supporting it or reaching out for collaboration:

[![Buy Me A Coffee](https://img.shields.io/badge/BUY%20ME%20A%20COFFEE-SUPPORT%20PROJECT-green?style=for-the-badge&logo=buymeacoffee)](https://buymeacoffee.com/themanoftalent) [![GitHub Sponsors](https://img.shields.io/badge/SPONSOR-GITHUB%20SPONSORS-ea4aaa?style=for-the-badge&logo=githubsponsors)](https://github.com/sponsors/themanoftalent) [![Let's Connect](https://img.shields.io/badge/LET%27S%20CONNECT-EMAIL-blue?style=for-the-badge&logo=gmail)](mailto:cs.akifcifci@gmail.com)

---

## License

MIT License. Copyright © 2026 AleClip. Developed with passion by **themanoftalent**.
