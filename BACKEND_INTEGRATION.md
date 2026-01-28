# Backend Integration Guide

This document explains how the TeleTable Flutter app is connected to the backend server.

## Backend Repository

The backend server code is available at: https://github.com/TeleTable-StartUp-Lab/backend.git

## Backend Configuration

### Running the Backend

1. **Clone the backend repository:**
   ```bash
   git clone https://github.com/TeleTable-StartUp-Lab/backend.git
   cd backend
   ```

2. **Start the backend with Docker:**
   ```bash
   docker compose up --build
   ```
   
   This will start:
   - PostgreSQL database
   - Redis
   - Backend server on `http://localhost:3003`

3. **Or use the helper script:**
   ```bash
   ./docker.sh dev:start
   ```

### Backend API Endpoints

The backend runs on port **3003** by default. Key endpoints:

#### Authentication
- `POST /register` - Create new user account
- `POST /login` - Login and get JWT token
- `GET /me` - Get current user info (requires JWT)

#### Diary
- `GET /diary` - Get all diary entries for authenticated user
- `POST /diary` - Create new diary entry
- `POST /diary` - Update existing diary entry (with id)
- `DELETE /diary` - Delete diary entry

#### Robot Control (for future use)
- `GET /status` - Get robot status
- `GET /nodes` - Get available navigation nodes
- `POST /routes/select` - Select navigation route

## Flutter App Configuration

### API Service Location

The API service is located at: `lib/services/api_service.dart`

### Backend URL Configuration

The default backend URL is set to `http://localhost:3003` in `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'http://localhost:3003';
```

### Testing on Different Devices

#### iOS Simulator
- Use `http://localhost:3003` (works as-is)

#### Android Emulator
- Change the URL to `http://10.0.2.2:3003`
- The Android emulator maps `10.0.2.2` to the host machine's `localhost`

#### Real Device (Phone/Tablet)
- Change the URL to your computer's IP address
- Example: `http://192.168.1.100:3003`
- Make sure your phone and computer are on the same WiFi network

### Changing the Backend URL

Edit `lib/services/api_service.dart`:

```dart
class ApiService {
  // Change this URL based on where you're testing:
  // - Simulator/Desktop: http://localhost:3003
  // - Android Emulator: http://10.0.2.2:3003
  // - Real Device: http://YOUR_COMPUTER_IP:3003
  static const String baseUrl = 'http://localhost:3003';
  
  // ... rest of the code
}
```

## How It Works

### Authentication Flow

1. **Registration:**
   - User fills in name, email, and password
   - App sends `POST /register` to backend
   - Backend creates user account and returns user info
   - App automatically logs in the user

2. **Login:**
   - User enters email and password
   - App sends `POST /login` to backend
   - Backend validates credentials and returns JWT token
   - App stores token in SharedPreferences
   - App calls `GET /me` to get user details
   - Token is automatically included in all subsequent requests

3. **Logout:**
   - App clears stored token from SharedPreferences
   - User is redirected to login screen

### Diary Integration

The diary feature now uses the backend API instead of local storage:

1. **Loading Entries:**
   - App calls `GET /diary` with JWT token
   - Backend returns all diary entries for the authenticated user
   - Entries are displayed in the UI

2. **Creating Entry:**
   - User fills in title, content, and working minutes
   - App sends `POST /diary` with entry data
   - Backend creates entry and returns the created entry with ID and timestamps

3. **Updating Entry:**
   - User edits an existing entry
   - App sends `POST /diary` with entry ID
   - Backend updates the entry and returns updated data

4. **Deleting Entry:**
   - User confirms deletion
   - App sends `DELETE /diary` with entry ID
   - Backend removes the entry

### Data Format

The backend uses a slightly different format than the app's original design:

**Backend Format:**
```json
{
  "id": "uuid",
  "working_minutes": 60,
  "text": "Title\nContent body",
  "created_at": "2026-01-28T10:00:00Z",
  "updated_at": "2026-01-28T10:00:00Z"
}
```

**App Format:**
```dart
DiaryEntry(
  id: "uuid",
  title: "Title",
  content: "Content body",
  workingMinutes: 60,
  createdAt: DateTime(...),
  updatedAt: DateTime(...)
)
```

The `DiaryProvider` automatically converts between these formats.

## Error Handling

The app includes comprehensive error handling:

1. **Network Errors:**
   - If the backend is not reachable, the app shows an error message
   - Users can retry the operation

2. **Authentication Errors:**
   - Invalid credentials show a specific error message
   - Expired tokens redirect to login screen

3. **Validation Errors:**
   - Backend validation errors are displayed to the user
   - Examples: "Email already exists", "Invalid credentials"

## Testing the Integration

1. **Start the backend server:**
   ```bash
   cd backend
   ./docker.sh dev:start
   ```

2. **Run the Flutter app:**
   ```bash
   cd teletable_app
   flutter run
   ```

3. **Test the features:**
   - Register a new account
   - Login with your credentials
   - Create diary entries
   - Edit and delete entries
   - Logout and login again to verify persistence

## Troubleshooting

### "Failed to connect to backend"

**Problem:** App can't reach the backend server

**Solutions:**
1. Verify backend is running: `docker ps` should show running containers
2. Check backend logs: `docker compose logs backend`
3. Verify the URL in `api_service.dart` matches your setup
4. For Android emulator, use `10.0.2.2` instead of `localhost`
5. For real device, use your computer's IP address

### "Invalid credentials" on login

**Problem:** Backend rejects login attempt

**Solutions:**
1. Verify you registered the account first
2. Check backend logs for detailed error message
3. Try registering a new account

### Diary entries not loading

**Problem:** Diary screen shows empty or error

**Solutions:**
1. Verify you're logged in (check for JWT token)
2. Check network connection
3. Look at backend logs: `docker compose logs backend`
4. Try creating a new entry to test the connection

## Backend Documentation

For detailed API documentation, see the backend repository:
- [Authentication API](https://github.com/TeleTable-StartUp-Lab/backend/tree/main/docs/auth.md)
- [Diary API](https://github.com/TeleTable-StartUp-Lab/backend/tree/main/docs/diary.md)
- [Robot API](https://github.com/TeleTable-StartUp-Lab/backend/tree/main/docs/robot.md)

## Next Steps

Future enhancements could include:
1. WebSocket integration for real-time robot control
2. Offline mode with local caching
3. Push notifications for robot events
4. Multi-user collaboration features
