# VPN Client Specification

## 1. Project Overview

**Project Name**: NebulaVPN

**Core Functionality**: A cross-platform VPN client (Windows/Android) with core features matching v2rayng - VPN connection management, server node selection, real-time traffic statistics, and a sci-fi themed user interface.

## 2. Technology Stack & Choices

| Component | Choice |
|-----------|--------|
| Framework | Flutter 3.41.7 |
| Language | Dart 3.11.5 |
| State Management | flutter_bloc (BLoC pattern) |
| Architecture | Clean Architecture (Presentation/Domain/Data layers) |
| VPN Core | v2ray-core via platform channels |
| Local Storage | shared_preferences, sqflite |
| Network | dio for HTTP requests |
| UI Components | Custom sci-fi themed widgets |

### Key Dependencies
- `flutter_bloc` - State management
- `equatable` - Value equality for BLoC states
- `get_it` - Dependency injection
- `shared_preferences` - Key-value storage
- `sqflite` - SQLite database for server nodes
- `dio` - HTTP client
- `connectivity_plus` - Network connectivity
- `uuid` - Unique ID generation
- `intl` - Internationalization

## 3. Feature List

### Core VPN Features
- VPN connection/disconnection toggle
- Server node selection and management
- Import VPN configuration (VMess/VLESS/Shadowsocks)
- Connection status display
- Auto-reconnect on network change

### Statistics & Monitoring
- Real-time upload/download speed
- Total data transferred (session/total)
- Connection duration timer
- Current server location display (IP-based geolocation)
- Ping latency display

### Server Management
- Add/Edit/Delete server nodes
- Server latency test
- Server speed test
- Server grouping/categorization
- Configuration import via QR code or URL

### Settings
- Auto-start on boot
- Kill switch toggle
- DNS settings
- Route configuration
- Log viewing

## 4. UI/UX Design Direction

### Overall Visual Style
- **Theme**: Cyberpunk/Sci-Fi aesthetic with dark theme as default
- **Primary Colors**: Deep space black (#0D1117), Electric cyan (#00F5FF), Neon purple (#9D4EDD)
- **Accent Colors**: Hot pink (#FF006E), Electric blue (#3A86FF)
- **Typography**: Modern sans-serif (Orbitron for headers, Roboto for body)

### Layout Approach
- **Navigation**: Bottom navigation bar with 4 tabs (Home, Servers, Statistics, Settings)
- **Home Screen**: 
  - Large circular connection button (center)
  - Animated ring indicator showing connection status
  - Current server info card
  - Real-time speed gauges (upload/download)
  - Location info with animated globe icon
- **Server List**: Card-based list with flags, latency indicators, and quick-connect
- **Statistics**: Charts for daily/weekly traffic, animated counters
- **Settings**: Clean list-based settings with sci-fi toggles

### Visual Effects
- Glowing borders and shadows
- Gradient backgrounds with subtle particle effects
- Animated connection state transitions
- Pulse animations for active connections
- Glass-morphism cards
- Neon glow on interactive elements

## 5. Platform-Specific Considerations

### Android
- Use Android VPN Service API
- Handle VPN permission requests
- Support split tunneling
- Background service for persistent connection

### Windows
- Use Windows VPN APIs or v2ray-core directly
- System tray integration
- Auto-start capability
- Native notifications
