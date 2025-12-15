# TeleTable Robot Control App

A Flutter application for controlling robots with joystick controls, route planning, and diary functionality. Features a dark theme with cyan accent color (#00f0ff).

## 🚀 Features

### ✅ Completed Features
- **🎮 Joystick Control**: Custom-built joystick widget for manual robot control
- **🔄 Manual/Automatic Switch**: Toggle between manual and automatic control modes
- **🗺️ Route Planning**: Interactive map interface for planning robot routes
- **🔐 Login System**: Secure authentication with persistent login state
- **📖 Diary/Journal**: Create, edit, and manage diary entries with tags
- **🌙 Dark Theme**: Custom dark theme with cyan accent color (#00f0ff)
- **📱 Responsive UI**: Optimized for mobile devices with intuitive navigation

### 🔧 Architecture

```
lib/
├── main.dart                           # App entry point
├── theme/
│   └── app_theme.dart                 # Dark theme with cyan accents
├── providers/                         # State management
│   ├── auth_provider.dart            # Authentication state
│   ├── robot_control_provider.dart   # Robot control logic
│   └── diary_provider.dart          # Diary management
├── screens/                          # Main app screens
│   ├── login_screen.dart            # User authentication
│   ├── home_screen.dart             # Dashboard with quick actions
│   ├── control_screen.dart          # Robot control interface
│   ├── route_planning_screen.dart   # Route planning interface
│   └── diary_screen.dart           # Diary management
└── widgets/
    └── joystick_widget.dart         # Custom joystick control
```

## 🎨 Design System

### Color Palette
- **Primary**: #00F0FF (Cyan)
- **Background**: #121212 (Dark)
- **Surface**: #1E1E1E
- **Cards**: #2D2D2D

### UI Components
- **Custom Joystick**: Interactive circular joystick with directional indicators
- **Mode Switch**: Toggle between manual and automatic modes
- **Route Map**: Interactive grid-based route planning interface
- **Diary Cards**: Clean card-based layout for journal entries

## 📱 App Screens

### 🏠 Home Screen
- Welcome dashboard with quick action cards
- Navigation to all main features
- User profile and logout options

### 🎮 Control Screen
- **Connection Status**: Visual indicator for robot connection
- **Mode Switch**: Toggle between Manual/Automatic control
- **Speed Control**: Slider for adjusting robot speed
- **Joystick Control**: Custom joystick for manual movement (manual mode only)
- **Emergency Stop**: Large red button for immediate stopping

### 🗺️ Route Planning Screen
- **Interactive Map**: Grid-based map for route planning
- **Point Management**: Add, edit, and delete route points
- **Route Visualization**: Connected points showing planned path
- **Route Execution**: Send routes to robot for automatic execution

### 📖 Diary Screen
- **Entry List**: Chronological list of diary entries
- **CRUD Operations**: Create, read, update, and delete entries
- **Tagging System**: Organize entries with custom tags
- **Search & Filter**: Find entries by content or tags

## 🛠️ Technical Implementation

### State Management
- **Provider Pattern**: Used for reactive state management
- **Local Storage**: SharedPreferences for authentication persistence
- **Memory Management**: Efficient disposal of resources

### Custom Widgets
- **JoystickWidget**: Fully custom implementation with:
  - Circular boundary constraints
  - Real-time position feedback
  - Visual directional indicators
  - Touch gesture handling

### Navigation
- **GoRouter**: Modern declarative routing
- **Authentication Guards**: Route protection based on login state
- **Deep Linking**: Support for direct navigation

## 🔮 Future Robot Integration

The app is designed with placeholders for actual robot communication:

### Control Commands
- Movement commands (x, y coordinates)
- Speed adjustments
- Mode switching (manual/automatic)
- Emergency stop signals

### Route Execution
- Route point coordinates
- Execution status monitoring
- Real-time position updates

### Communication Protocol
- WebSocket for real-time updates
- HTTP REST API for configuration
- Error handling and retry logic

## 📡 Backend Integration

### Diary System
Complete API documentation available in `BACKEND_DIARY_API.md`:
- RESTful API endpoints
- Authentication with JWT tokens
- CRUD operations for diary entries
- Search and filtering capabilities
- Offline synchronization support

### Robot Control (Future)
- Command queue management
- Status monitoring
- Telemetry data collection
- Error reporting and diagnostics

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.7.2 or higher
- Dart SDK
- Android Studio / VS Code
- iOS development setup (for iOS deployment)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/TeleTable-StartUp-Lab/App.git
   cd teletable_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Build for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## 📦 Dependencies

### Core Dependencies
- `go_router: ^14.2.7` - Modern routing solution
- `provider: ^6.1.1` - State management
- `shared_preferences: ^2.2.2` - Local data persistence

### HTTP & Communication
- `http: ^1.1.0` - Basic HTTP requests
- `dio: ^5.4.0` - Advanced HTTP client with interceptors

### UI Components
- `flutter_joystick: ^0.0.1` - Joystick component base
- `flutter_map: ^6.1.0` - Mapping capabilities (future use)
- `font_awesome_flutter: ^10.6.0` - Icon library

### Utilities
- `lottie: ^2.7.0` - Animations (future use)
- `latlong2: ^0.8.1` - Geographic calculations (future use)

## 🔧 Development Setup

### VS Code Extensions (Recommended)
- Flutter
- Dart
- Flutter Intl
- Bracket Pair Colorizer

### Debug Configuration
```json
{
  "name": "Launch Debug",
  "request": "launch",
  "type": "dart",
  "program": "lib/main.dart",
  "args": ["--debug"]
}
```

## 📱 Supported Platforms

- ✅ Android (API 21+)
- ✅ iOS (iOS 11+)
- 🔄 Web (Future implementation)
- 🔄 Desktop (Future implementation)

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

### Widget Tests
Located in `test/` directory covering:
- Widget rendering
- User interactions
- State changes
- Navigation flows

## 🎯 Development Roadmap

### Phase 1: Core App (✅ Complete)
- [x] Authentication system
- [x] Basic UI structure
- [x] Joystick control widget
- [x] Route planning interface
- [x] Diary functionality

### Phase 2: Robot Integration (🔄 Upcoming)
- [ ] WebSocket communication
- [ ] Real robot control commands
- [ ] Status monitoring
- [ ] Error handling

### Phase 3: Advanced Features (🔮 Future)
- [ ] Offline mode support
- [ ] Advanced route algorithms
- [ ] Video streaming integration
- [ ] Multi-robot support
- [ ] Cloud synchronization

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

**TeleTable StartUp Lab**
- Robot Control System Development
- Mobile App Development
- Backend API Development

## 📞 Support

For questions and support, please contact:
- Email: support@teletable.com
- GitHub Issues: [Create an issue](https://github.com/TeleTable-StartUp-Lab/App/issues)

---

**Built with ❤️ using Flutter**
