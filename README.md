**Built for the Fantom Code Hackathon**

We built a discreet, automated women's safety and distress-detection application built with Flutter. Unlike traditional SOS apps that require the user to actively open the app and press a visible panic button—which can be prevented by an attacker—Fox-Hound operates using a **Stealth UI** and **Passive Sensor Monitoring** to detect distress automatically.

---

## ✨ Key Features

### 1. 🥷 Stealth UI
The home screen of the app is completely blacked out, looking like the phone is locked or asleep. It features a nearly invisible manual SOS trigger (set to 5% opacity). This prevents an attacker from realizing a safety app is active and forcing the user to close it.

### 2. 💥 Automated Kinematic Distress Detection
The app continuously monitors the device's accelerometer (`sensors_plus`) to detect physical struggles or accidents:
- **Jerk/Struggle Detection:** Identifies sudden, violent movements or changes in acceleration (magnitude > 24.0g or rapid delta spikes) within a 1.5-second window.
- **Fall Detection:** Uses a multi-step algorithm to detect a state of free-fall (< 2.2g) immediately followed by a hard impact (> 21.0g).

### 3. 🎙️ Acoustic SOS Trigger
Using the device's microphone (`noise_meter`), the app constantly monitors ambient decibel levels. If it detects a sudden loud noise, such as a scream or a crash (threshold > 80dB), it automatically triggers the distress protocol.

### 4. ⏱️ Fail-Safe SOS Countdown
To prevent false positives (e.g., dropping your phone on the couch), triggering the distress system initiates a **20-second countdown timer**:
- **I AM SAFE:** Cancels the SOS and returns to Stealth Mode.
- **EXTEND TIME:** Adds 10 seconds to the timer if the user needs more time to reach the phone.
- **TIMEOUT:** If the timer hits zero without user intervention, the system assumes the user is incapacitated and automatically triggers the final SOS protocol (Location Sharing & Contact Alerting).

---

## 🛠️ Technology Stack

* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Sensors:** `sensors_plus` (Accelerometer stream processing)
* **Audio:** `noise_meter` (Ambient decibel calculation)
* **Permissions:** `permission_handler` (Microphone access management)

---

## 🚀 How to Run the Project

### Prerequisites
- Flutter SDK installed ([Setup Guide](https://docs.flutter.dev/get-started/install))
- A physical Android or iOS device (Sensors and microphone testing **will not work accurately on a standard emulator**).

### Installation
1. **Clone the repository:**
   ```bash
   git clone [https://github.com/YourUsername/fox-hound-safety.git](https://github.com/YourUsername/fox-hound-safety.git)
   cd fox-hound-safety
2. **Install Dependencies:**
    ```bash
    flutter pub get
3. **Run the app:**
    ```bash 
    flutter run