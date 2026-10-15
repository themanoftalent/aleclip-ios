# Apple App Store Submission Guide — AleClip iOS

This guide provides step-by-step instructions for uploading **AleClip iOS (v2.0.1)** to TestFlight and the Apple App Store.

---

## 1. Prerequisites Checklist

Before you begin, ensure you have:
1. An active **Apple Developer Program** account ($99/yr) at [developer.apple.com](https://developer.apple.com).
2. Access to **App Store Connect** at [appstoreconnect.apple.com](https://appstoreconnect.apple.com).
3. A Mac with **Xcode 15 or 16** installed (or utilize the included GitHub Actions workflow).

---

## 2. Register Identifiers on developer.apple.com

1. Navigate to **Certificates, Identifiers & Profiles** > **Identifiers**.
2. Click the blue **`+`** icon to add a new **App IDs**:
   - **Type**: App
   - **Description**: AleClip iOS App
   - **Bundle ID**: Explicit -> `com.themanoftalent.aleclip`
   - **Capabilities**: Enable **App Groups**
3. Create the **App Group**:
   - Go to **Identifiers** > Select dropdown **App Groups** > Click **`+`**
   - **Description**: AleClip App Group
   - **Identifier**: `group.com.themanoftalent.aleclip`
   - Re-open `com.themanoftalent.aleclip` App ID and assign this group.
4. Create the **Share Extension App ID**:
   - **Description**: AleClip Share Extension
   - **Bundle ID**: Explicit -> `com.themanoftalent.aleclip.share`
   - **Capabilities**: Enable **App Groups** and assign `group.com.themanoftalent.aleclip`.

---

## 3. Create the App in App Store Connect

1. Go to [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps).
2. Click the **`+`** button > **New App**.
3. Fill in the required fields:
   - **Platforms**: iOS
   - **Name**: `AleClip - Clipboard Manager`
   - **Primary Language**: English (U.S.) or Turkish
   - **Bundle ID**: Select `com.themanoftalent.aleclip`
   - **SKU**: `aleclip-ios-001`
   - **User Access**: Full Access
4. Click **Create**.

---

## 4. Fill in App Store Information

Use the prepared content from [`AppStore/METADATA.md`](./METADATA.md):
1. **Subtitle**: `Fast, Colorful & Private`
2. **Category**:
   - Primary: `Utilities`
   - Secondary: `Productivity`
3. **App Privacy Questionnaire**:
   - Click **App Privacy** in the left sidebar.
   - Click **Get Started**.
   - Answer: **"No, we do not collect data from this app"**.
   - Save and Publish privacy details. (Matches `PrivacyInfo.xcprivacy`).
4. **Pricing and Availability**:
   - Price: **Free ($0.00)**.
   - Availability: All countries / regions.

---

## 5. Build, Archive & Upload to App Store Connect

### Method A: Using Xcode on a Mac (Recommended)
1. Clone the repository and open `AleClip.xcodeproj`:
   ```bash
   open AleClip.xcodeproj
   ```
2. Select the **AleClip** target in Xcode > **Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - Select your **Apple Developer Team**.
   - Ensure the Bundle Identifier is `com.themanoftalent.aleclip`.
3. Do the same for the **AleClipShareExtension** target:
   - Select your Team.
   - Bundle Identifier: `com.themanoftalent.aleclip.share`.
4. In the top toolbar, select destination: **Any iOS Device (arm64)**.
5. In the menu bar, select:
   ```text
   Product > Archive
   ```
6. When the Xcode Organizer window appears:
   - Click **Distribute App**.
   - Choose **App Store Connect**.
   - Choose **Upload**.
   - Keep default options (Upload app symbols, strip Swift symbols).
   - Click **Next** > **Upload**.

### Method B: Automated Upload via GitHub Actions
AleClip includes a production CI/CD workflow at [`.github/workflows/ios-build.yml`](../.github/workflows/ios-build.yml).
You can configure App Store Connect API keys in your repository secrets:
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY` (Content of your `.p8` key file)

---

## 6. TestFlight Internal & External Testing

1. Once uploaded, wait 5–10 minutes for Apple to process the binary.
2. Go to **App Store Connect** > **TestFlight**.
3. Under **Internal Testing**, add yourself and your team.
4. Open the **TestFlight** app on your iPhone and install AleClip v2.0.1.
5. Verify:
   - Clipboard capture & toast notifications.
   - Undo delete & trash recovery.
   - Spectrum UI color scheme (zero pink).
   - Share extension from Safari and Photos.

---

## 7. Prepare Screenshots & Submit for App Review

1. Required Screenshot sizes:
   - **6.7" Display** (iPhone 15 Pro Max / 16 Pro Max): 1290 x 2796 pixels.
   - **6.5" Display** (iPhone 11 Pro Max / XS Max): 1242 x 2688 pixels.
   - **iPad Pro 12.9"** (Optional if iPad is enabled): 2048 x 2732 pixels.
2. In App Store Connect > **1.0 Prepare for Submission**:
   - Drag and drop screenshots.
   - Paste Description, Keywords, and Promotional Text from `AppStore/METADATA.md`.
   - Set Support URL: `https://github.com/themanoftalent/aleclip-ios/issues`.
   - Set Marketing URL: `https://github.com/themanoftalent/aleclip-ios`.
   - Set Privacy Policy URL: `https://themanoftalent.github.io/aleclip-ios/`.
   - Select the processed Build (v2.0.1 Build 2026).
3. Click **Save** > **Add for Review** > **Submit to App Review**!

Apple typical review turnaround is **24 to 48 hours**. Once approved, AleClip will be live worldwide on the App Store!
