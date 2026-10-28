# Ryvo — Google Play Listing Pack (Customer)

## App identity

| Field | Value |
|-------|--------|
| Title | Ryvo |
| Package name | `com.ryvo.customer` |
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
| `app-release.aab` | Signed release bundle (~58MB) | Ready (also at `build/app/outputs/bundle/release/`) |
| `UPLOAD_CERT_SHA.txt` | SHA-1 / SHA-256 for Maps & Firebase | Ready |

## Screenshot checklist (capture from a real device)

Phone (required):
- At least 2 screenshots
- JPEG or 24-bit PNG (no alpha)
- Recommended: 1080 × 1920 (portrait)

Suggested screens:
1. Home map / request help
2. Searching / provider assigned
3. Live tracking
4. Payment success
5. Bookings or vehicles

## Content rating notes

Expect questions about:
- Location (precise — find providers / pickup)
- User communication (in-app chat)
- Account creation
- Payments (Stripe)

App is for adults 18+ requesting roadside assistance.

## Data safety (summary for Play Console form)

| Data type | Purpose | Notes |
|-----------|---------|--------|
| Location (precise) | App functionality | Find providers, send help to pickup |
| Personal info (name, email, phone) | Account | Registration / support |
| Photos | App functionality | Optional vehicle photos |
| Financial info | App functionality | Payments via Stripe |
| Messages | App functionality | Customer–provider chat |
| Device / app activity | App functionality | Notifications |

- Privacy Policy: https://ryvo.arcadexit.com/privacy-policy/
- Encryption in transit: yes (HTTPS)
- Deletion requests: enquiries@ryvo.arcadexit.com

## Upload steps

1. Open [Google Play Console](https://play.google.com/console)
2. Create app → **Ryvo** → package `com.ryvo.customer`
3. Complete Store listing (paste short/full description; upload icon + feature graphic)
4. Set Privacy policy URL and contact email
5. Complete Data safety + Content rating
6. Create release → upload `app-release.aab`
7. Register upload keystore SHA-1 / SHA-256 on Google Maps + Firebase Android apps

## Keystore reminder

Credentials are in `store/KEYSTORE_CREDENTIALS.txt` (gitignored). Back up the keystore and passwords securely.
