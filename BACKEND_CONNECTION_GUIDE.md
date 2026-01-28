# Backend Connection Guide

## Current Status
Your Flutter app is now properly configured to connect to the backend with persistent JWT token storage.

## Backend URL Configuration

The backend URL is configured in `lib/services/api_service.dart`. You need to change it based on where you're running the app:

### 1. iOS Simulator (Running on Mac)
```dart
static const String baseUrl = 'http://localhost:3003';
```
✅ **This is currently set** - Works for iOS Simulator

### 2. Android Emulator
```dart
static const String baseUrl = 'http://10.0.2.2:3003';
```
The Android emulator uses `10.0.2.2` to access the host machine's localhost.

### 3. Physical Device (iPhone/Android)
```dart
static const String baseUrl = 'http://YOUR_COMPUTER_IP:3003';
```
Replace `YOUR_COMPUTER_IP` with your computer's actual IP address on the local network.

**To find your computer's IP:**
- **macOS**: System Settings → Network → Your connection → Details → IP address
- **Or in terminal**: `ipconfig getifaddr en0` (WiFi) or `ipconfig getifaddr en1` (Ethernet)

Example:
```dart
static const String baseUrl = 'http://192.168.1.100:3003';
```

## Key Changes Made

### 1. Persistent Token Storage
- Tokens are now saved to SharedPreferences
- Token persists across app restarts
- Auto-loads on app startup

### 2. Token Validation
- App validates token on startup by calling `/me`
- Automatically logs out if token is invalid/expired

### 3. Network Permissions Already Set
- ✅ iOS: `Info.plist` has `NSAppTransportSecurity` configured
- ✅ Android: `AndroidManifest.xml` has `INTERNET` permission

## Testing the Connection

1. **Start Backend**
   ```bash
   cd ../backend
   docker-compose up
   ```

2. **Configure URL**
   - Open `lib/services/api_service.dart`
   - Set the correct `baseUrl` for your device/simulator
   - Save the file

3. **Full Rebuild** (IMPORTANT!)
   ```bash
   flutter clean
   flutter run
   ```
   Hot reload won't apply the URL change - you need a full rebuild.

4. **Test Login**
   - Register a new account
   - Login with credentials
   - Check if diary loads

## Debugging Connection Issues

### Check Backend is Running
```bash
curl http://localhost:3003/
```
Should return backend response.

### Check iOS Simulator Can Reach Backend
From within your app, the diary screen should load entries. If you see "Operation not permitted":
1. Verify `Info.plist` has network permissions (already added)
2. Do a full rebuild with `flutter clean && flutter run`

### Check Android Emulator
If using Android emulator and getting connection errors:
- Change URL to `http://10.0.2.2:3003`
- Full rebuild

### Check Physical Device
If testing on a physical device:
1. Find your computer's IP: `ipconfig getifaddr en0`
2. Update `baseUrl` to `http://YOUR_IP:3003`
3. Ensure device and computer are on the same WiFi network
4. Full rebuild

## Common Issues

### "Operation not permitted"
- **Cause**: iOS security blocking HTTP to localhost
- **Fix**: Already added NSAppTransportSecurity to Info.plist, but requires full rebuild

### "Connection refused"
- **Cause**: Backend not running or wrong URL
- **Fix**: Start backend with `docker-compose up`, verify with `curl`

### "404 Not Found"
- **Cause**: Wrong endpoint path
- **Fix**: Already configured correctly, matches working frontend

### Token Not Persisting
- **Cause**: Was using in-memory storage
- **Fix**: ✅ Now using SharedPreferences (already fixed)

## What's Different from Working Frontend

The working React frontend uses:
```javascript
const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:3003';
```

Your Flutter app now:
```dart
static const String baseUrl = 'http://localhost:3003';
```

Both connect to the same backend at `localhost:3003`. The key difference is:
- **Web/Browser**: Can access `localhost` directly (browser runs on same machine)
- **iOS Simulator**: Can access `localhost` (simulates being on same machine)
- **Android Emulator**: Needs `10.0.2.2` (different network namespace)
- **Physical Device**: Needs your computer's actual IP address

## Next Steps

1. ✅ Backend is already running (you confirmed this)
2. ✅ Permissions are already added
3. ✅ Token storage is now persistent
4. **Do a full rebuild:**
   ```bash
   flutter clean
   flutter run
   ```
5. **Test login and diary loading**

If diary still doesn't load after full rebuild, the issue is likely:
- Backend not accessible at the configured URL
- Need to use different URL for your test environment
