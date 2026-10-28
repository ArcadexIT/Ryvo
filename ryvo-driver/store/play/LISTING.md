# Ryvo Driver — Google Play Listing Pack

## App identity

| Field | Value |
|-------|--------|
| Title | Ryvo Driver |
| Package name | `com.ryvo.driver` |
| Version | `1.0.0` (versionCode `1`) |
| Default language | English (en-GB / en-US) |
| Suggested category | Auto & Vehicles |
| Contact email | enquiries@ryvo.arcadexit.com |
| Privacy policy | https://ryvo.arcadexit.com/privacy-policy/ |
| Developer | Ryvo Ltd |

## Listing assets in this folder

| File | Spec | Status |
|------|------|--------|
| `short-description.txt` | ≤80 characters | Ready |
| `full-description.txt` | ≤4000 characters | Ready |
| `feature-graphic.png` | 1024 × 500 | Ready |
| `icon-512.png` | 512 × 512 | Ready |
| `app-release.aab` | Signed release bundle (~50MB) | Ready (also at `build/app/outputs/bundle/release/`) |
| `UPLOAD_CERT_SHA.txt` | SHA-1 / SHA-256 for Maps & Firebase | Ready |

## Screenshot checklist (capture from a real device)

Phone (required):
- At least 2 screenshots
- JPEG or 24-bit PNG (no alpha)
- Min dimension 320px, max 3840px
- Recommended: 1080 × 1920 (portrait)

Suggested screens to capture:
1. Home map (online) with job area
2. Incoming job / accept sheet
3. Active navigation / job in progress
4. Earnings / wallet
5. Profile or verification complete

7-inch / 10-inch tablets: optional unless you target large screens.

## Content rating notes

Expect questions about:
- Location sharing (precise location for jobs)
- User communication (in-app chat with customers)
- Account creation / identity verification
- Financial info (payouts / bank details)

App is for adults 18+ (provider workforce).

## Data safety (summary for Play Console form)

Collected / shared as needed to provide the service:

| Data type | Purpose | Notes |
|-----------|---------|--------|
| Location (precise) | App functionality | Job matching, map, navigation, ETA |
| Personal info (name, email, phone) | Account | Registration / support |
| Photos / documents | App functionality | KYC: licence, registration, insurance, selfie, equipment |
| Financial info | App functionality | Bank / withdraw for payouts |
| Messages | App functionality | Customer–provider chat |
| Device / app activity | App functionality, analytics | Notifications, diagnostics as applicable |

- Data is used to provide roadside assistance services between customers and providers.
- See full policy: https://ryvo.arcadexit.com/privacy-policy/
- Encryption in transit: yes (HTTPS)
- Users can request deletion via contact: enquiries@ryvo.arcadexit.com

## Upload steps

1. Open [Google Play Console](https://play.google.com/console)
2. Create app → **Ryvo Driver** → package `com.ryvo.driver`
3. Complete Store listing (paste short/full description; upload icon + feature graphic)
4. Set Privacy policy URL and contact email
5. Complete Data safety + Content rating
6. Create production (or closed testing) release → upload `app-release.aab`
7. Register upload keystore SHA-1 / SHA-256 on Google Maps + Firebase Android apps

## Keystore reminder

Credentials are in `store/KEYSTORE_CREDENTIALS.txt` (gitignored). Back up the keystore and passwords securely — required for every future update.
