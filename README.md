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

## 🏗️ Architecture: Custom Accelerometer-based Step Detection

StrideTrack uses a specialized **Digital Signal Processing (DSP)** pipeline to detect steps from raw accelerometer data:

1.  **Gravity removal**: Uses a low-pass filter to isolate linear acceleration.
2.  **Noise filtering**: Applies a moving average buffer to smooth jitter.
3.  **Peak detection**: Identifies local maxima using a sliding 3-point window.
4.  **Adaptive thresholding**: Dynamically adjusts sensitivity based on recent signal energy.
5.  **Gating logic**: Enforces realistic human step intervals (250ms - 2000ms).
6.  **Continuous Walking Verification**: Only counts steps after a pattern of 5 consecutive strides is confirmed, eliminating false positives from incidental movement.

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
4. Push to the Branch (`git push origin feature/AmazingFe# StrideTrack

A Flutter pedometer app built to track your daily steps accurately with a clean dark UI. Built for Android using hardware-level sensors.

![License](https://img.shields.io/badge/license-MIT-blueviolet)
![Flutter](https://img.shields.io/badge/flutter-%2302569B.svg?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)

---

## Features

- **Real-time Tracking** — connects directly to the Android Sensor Hub for accurate step counting.
- **Incremental Delta Logic** — handles phone reboots and sensor resets without losing your step count.
- **Dark UI** — neon purple and black theme with glassmorphism and mesh gradients.
- **Activity Log** — history view showing the last 30 days with progress bars.
- **Pull to Refresh** — manually trigger sensor re-synchronization.
- **Responsive Layout** — works in both portrait and landscape orientations.
- **Battery Efficient** — uses the hardware `TYPE_STEP_COUNTER` to minimize battery drain.

---

## Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **State Management**: StatefulWidget
- **Persistence**: shared_preferences
- **Sensors**: pedometer package
- **Fonts & Animations**: google_fonts (Outfit) & animations package

---

## How Step Detection Works

StrideTrack uses a custom accelerometer-based pipeline to detect steps accurately:

1. **Gravity removal** — low-pass filter to isolate linear acceleration
2. **Noise filtering** — moving average buffer to smooth out jitter
3. **Peak detection** — identifies steps using a sliding 3-point window
4. **Adaptive thresholding** — adjusts sensitivity based on recent signal energy
5. **Gating logic** — enforces realistic step intervals between 250ms and 2000ms
6. **Walking verification** — only starts counting after 5 consecutive strides to avoid false positives

---

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Android Studio or VS Code
- A physical Android device (emulators don't support step sensors)

### Installation

1. Clone the repository
```bash
   git clone https://github.com/irinejosee/stridetracker.git
```

2. Install dependencies
```bash
   flutter pub get
```

3. Run the app
```bash
   flutter run
```

Permissions for `ACTIVITY_RECOGNITION` are handled automatically at runtime.

---

## UI

- **Home screen** — neon progress circle with calories and distance stats
- **History screen** — scrollable list of past days with progress indicators
- **Landscape mode** — adaptive dashboard layout

---

## License

MIT License — see `LICENSE` for details.

---

## Contributing

Contributions are welcome! To contribute:

1. Fork the project
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a pull requestature`)
5. Open a Pull Request

---

