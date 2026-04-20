# 🟣 StrideTrack

StrideTrack is a premium, high-performance Flutter pedometer application designed with a stunning **Neon Purple & Black** aesthetic. It leverages hardware-level sensors to provide real-time, accurate step tracking with a futuristic user experience.

![License](https://img.shields.io/badge/license-MIT-blueviolet)
![Flutter](https://img.shields.io/badge/flutter-%2302569B.svg?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)

---

## ✨ Features

- **🚀 Real-time Tracking**: Connects directly to the Android Sensor Hub for precision counting.
- **⚡ Incremental Delta Logic**: Advanced algorithm that handles phone reboots and sensor resets without losing a single step.
- **🌑 Cyberpunk Aesthetics**: A beautiful "Dark Mode" UI featuring neon glows, glassmorphism, and mesh gradients.
- **📊 Activity Log**: Detailed history view with comparative progress bars for the last 30 days.
- **🔄 Smart Sync**: Pull-to-refresh functionality to manually trigger sensor re-synchronization.
- **📱 Fully Responsive**: Optimized for both Portrait and Landscape orientations.
- **🔋 Battery Efficient**: Uses the dedicated hardware `TYPE_STEP_COUNTER` to minimize CPU wake-locks and save battery.

---

## 🛠️ Technology Stack

- **Framework**: [Flutter](https://flutter.dev)
- **Language**: [Dart](https://dart.dev)
- **State Management**: `StatefulWidget` with optimized rebuilds.
- **Persistence**: `shared_preferences` for reliable local storage.
- **Sensors**: `pedometer` package for hardware integration.
- **Styling**: `google_fonts` (Outfit) & `animations` (Shared Axis Transition).

---

## 🏗️ Architecture: The "Precision" Algorithm

StrideTrack uses an **Incremental Delta System** instead of simple cumulative subtraction. 

1. **Delta Calculation**: It measures the difference between every sensor broadcast.
2. **Reboot Protection**: If the hardware counter resets to 0 (after a device restart), the app detects the drop and "stitches" the new steps onto the existing daily total.
3. **Persistence**: The app saves the last known sensor state every few minutes, ensuring that even if the app is killed by the OS, your steps are "caught up" the next time you open it.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code
- A physical Android device (Step counting sensors are typically not available in emulators)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/stridetrack.git
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Permissions**
   Ensure `ACTIVITY_RECOGNITION` is requested (handled automatically at runtime by the app).

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 🎨 UI Showcase

- **Home View**: Centered Neon Progress Circle with Calories and Distance stats.
- **History View**: Scrollable list of past days with progress indicators.
- **Landscape View**: Adaptive dashboard layout for sideways use.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

## 🤝 Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

Developed with ❤️ by Antigravity AI
