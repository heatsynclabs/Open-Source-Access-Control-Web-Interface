# .well-known Directory

## ⚠️ IMPORTANT: DO NOT COMMIT THESE FILES TO THE MOBILE APP REPO

This directory and its contents belong on the **web server** (`members.heatsynclabs.org`), **NOT** in the mobile app repository.

---

## 📁 Files in This Directory

### `apple-app-site-association`

**Purpose:** Enables password autofill for iOS devices

**Used by:**

- iOS Password AutoFill
- iCloud Keychain
- 1Password (iOS)
- LastPass (iOS)
- Dashlane (iOS)
- Bitwarden (iOS)
- Other iOS password managers

**Contains:**

- Apple Team ID: `D8DLTSQZBB`
- Bundle ID: `com.heatsynclabs.app`

**Must be served at:**

```
https://members.heatsynclabs.org/.well-known/apple-app-site-association
```

**Requirements:**

- Content-Type: `application/json`
- HTTPS only
- No file extension
- Publicly accessible (no authentication)

---

### `assetlinks.json`
**Purpose:** Enables password autofill for Android devices

**Used by:**

- Google Smart Lock
- 1Password (Android)
- LastPass (Android)
- Dashlane (Android)
- Bitwarden (Android)
- Other Android password managers

**Contains:**

- Package name: `com.heatsynclabs.app`
- SHA-256 certificate fingerprint from Google Play Console

**Must be served at:**

```
https://members.heatsynclabs.org/.well-known/assetlinks.json
```

**Requirements:**

- Content-Type: `application/json`
- HTTPS only
- Publicly accessible (no authentication)

---

## 🚀 Deployment

### Where These Files Should Be

**✅ Correct Location:**

```
Web Server: members.heatsynclabs.org
Path: /.well-known/

Files:
  - apple-app-site-association (no extension)
  - assetlinks.json
```

**❌ Incorrect Location:**

```
Mobile App Repo: heatsync-labs-app/
DO NOT commit these files to the mobile app repository
```

### Deployment Process

1. **Copy files to web server:**

   ```bash
   # SSH to web server
   scp apple-app-site-association user@server:/srv/web//members.heatsynclabs.org/.well-known/
   scp assetlinks.json user@server:/srv/web/members.heatsynclabs.org/.well-known/
   ```

2. **Verify permissions:**

   ```bash
   chmod 644 .well-known/apple-app-site-association
   chmod 644 .well-known/assetlinks.json
   ```

3. **Configure web server to serve as JSON:**

   **Apache (.htaccess):**

   ```apache
   <Files "apple-app-site-association">
       ForceType application/json
   </Files>

   <Files "assetlinks.json">
       ForceType application/json
   </Files>
   ```

---

## 🧪 Testing

### Verify Files Are Accessible

```bash
# Test iOS file
curl https://members.heatsynclabs.org/.well-known/apple-app-site-association

# Test Android file
curl https://members.heatsynclabs.org/.well-known/as/srv/web/setlinks.json

# Check Content-Type headers
curl -I https://members.heatsynclabs.org/.well-known/apple-app-site-association
curl -I https://members.heatsynclabs.org/.well-known/assetlinks.json
```

**Expected Response:**

- HTTP Status: `200 OK`
- Content-Type: `application/json`
- Body: Valid JSON content

### Validate with Official Tools

**iOS - Apple CDN:**

```bash
# Check if Apple has cached your file (can take 24-48 hours)
curl https://app-site-association.cdn-apple.com/a/v1/members.heatsynclabs.org
```

**Android - Google Validator:**

1. Go to: [https://developers.google.com/digital-asset-links/tools/generator](https://developers.google.com/digital-asset-links/tools/generator)
2. Enter domain: `members.heatsynclabs.org`
3. Enter package: `com.heatsynclabs.app`
4. Click "Test statement"

---

## 📝 Maintenance

### When to Update These Files

**Update `apple-app-site-association` when:**

- Apple Team ID changes
- App bundle identifier changes (`com.heatsynclabs.app`)
- Adding/removing iOS app variants

**Update `assetlinks.json` when:**

- Android package name changes (`com.heatsynclabs.app`)
- App signing certificate changes (new keystore)
- SHA-256 fingerprint changes (check Google Play Console)

### How to Update

1. **Get latest values:**

   - iOS Team ID: App Store Connect → Membership
   - Android SHA-256: Google Play Console → Release → Setup → App signing

2. **Update files** in this directory

3. **Redeploy to web server**

4. **Clear cache** (if using CDN like Cloudflare):

   - Purge cache for both files
   - Wait 5-10 minutes for propagation

5. **Test** using commands above

---

## ⚠️ Security Notes

### Do Not Modify Without Understanding

These files establish a trust relationship between:

- The mobile app (`com.heatsynclabs.app`)
- The website domain (`members.heatsynclabs.org`)

**Incorrect configuration can:**

- Break password autofill
- Cause security warnings
- Prevent users from logging in smoothly

**Always:**

- Use correct Team ID and SHA-256 fingerprint
- Serve files over HTTPS
- Use `application/json` Content-Type
- Keep files publicly accessible

### Version Control

**Mobile App Repo (.gitignore):**

```
apple-app-site-association
assetlinks.json
.well-known/
```

**Website Repo:**

```
# These files SHOULD be committed to your website repo
public/.well-known/apple-app-site-association
public/.well-known/assetlinks.json
```

---

## 🆘 Troubleshooting

### Password autofill not working?

**iOS:**

1. Check file is accessible over HTTPS
2. Verify Content-Type is `application/json`
3. Confirm Team ID is correct (`D8DLTSQZBB`)
4. Wait 24-48 hours for Apple CDN to cache
5. Rebuild iOS app if you just added Associated Domains
6. Ensure credentials are saved for `members.heatsynclabs.org` (exact domain)

**Android:**

1. Check file is accessible over HTTPS
2. Verify SHA-256 fingerprint matches Google Play Console
3. Ensure package name is correct (`com.heatsynclabs.app`)
4. Clear app data and re-save credentials
5. Check autofill service is enabled in Android settings

### Still having issues?

1. **Check server logs** for 404 or 403 errors
2. **Verify DNS** points to correct server
3. **Test with curl** to see actual response
4. **Check CDN/caching** - clear if applicable
5. **Validate JSON** syntax is correct

---

## 📧 Contact

**For questions about these files:**

- Check mobile app repo documentation first
- Review official Apple/Google documentation
- Contact: developers@heatsynclabs.org

---

**Last Updated:** October 2025
**Mobile App Version:** 1.0
**Team ID:** D8DLTSQZBB
**Package:** com.heatsynclabs.app

