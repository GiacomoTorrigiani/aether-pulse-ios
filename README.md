# ⚡ Aether Pulse — iOS Neural Bio-Rhythm & Quantum Flow Engine

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2014.0%2B-blue?style=for-the-badge&logo=apple" alt="iOS Support"/>
  <img src="https://img.shields.io/badge/Engine-Flutter%203.29%20%7C%20Dart%203.11-02569B?style=for-the-badge&logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/CI%2FCD-GitHub%20Actions%20macOS-2088FF?style=for-the-badge&logo=github-actions" alt="GitHub Actions"/>
  <img src="https://img.shields.io/badge/Format-.IPA%20Sideload%20Ready-green?style=for-the-badge" alt="IPA"/>
</p>

---

## 🌌 Overview
**Aether Pulse** is an innovative neuro-acoustic entrainment and circadian bio-hacking iOS application engineered for peak cognitive performance, deep parasympathetic restoration, and flow states.

Built to run fluidly on iPhone with **120Hz ProMotion**, true OLED dark-mode aesthetics, custom Skia/Impeller hardware canvas rendering, and zero CocoaPods bloatware.

---

## 🚀 Key Features

### 1. 🧬 Neural Resonance Waveform Synthesizer
- **Real-Time Entrainment**: Multi-harmonic mathematical wave generator tuned to Solfeggio carrier frequencies (432 Hz Pythagorean harmonic scale, 528 Hz transformation frequency).
- **5 Brainwave Resonance States**:
  - **Delta (2.5 Hz)**: Deep slow-wave sleep & cellular immunity regeneration.
  - **Theta (6.0 Hz)**: REM activation, twilight hypnagogic vision & intuitive memory.
  - **Alpha (10.0 Hz)**: Superlearning, relaxed alertness & anxiety dissolution.
  - **Beta (18.0 Hz)**: High-speed logical analysis & executive processing.
  - **Gamma (40.0 Hz)**: Simultaneous cross-hemispheric neural synchrony.
- **Interactive Oscilloscope**: Live hardware canvas responding to touch with custom phase shifts, harmonic amplitudes, and ambient particle fields.

### 2. 🪐 Quantum Bio-Particle Matrix
- 80+ kinetic quantum particles governed by real-time gravitational physics, velocity damping, and boundary rebound.
- **Touch Attractor**: Dragging across the display creates dynamic gravitational wells that pull particles into swirling vortexes.
- **Shockwave Burst**: Double-tapping the screen triggers a plasma shockwave dispersing particles radially.
- Dynamic constellation proximity lines mapping neural interconnectivity.

### 3. 🫁 Sacred Geometry Respiration & HRV Coherence Coach
- Guided bio-feedback breathwork with expanding/contracting Sacred Flower-of-Life geometry:
  - **4-4-4-4 Box Breathing**: Tactical nervous system equilibrium (used by Navy SEALs).
  - **4-7-8 Vagus Reset**: Parasympathetic activation for rapid stress dissolution and sleep induction.
  - **5.5s Heart Coherence**: Cardiovascular and autonomic heart rate variability (HRV) synchrony.
- Smooth iOS Haptic Feedback cues on each respiratory transition.

### 4. ⏰ Chronobiological AI Engine
- Real-time chronobiology algorithm synchronizing with your device clock.
- Dynamically computes your current biological circadian phase:
  - *Cortisol Awakening Phase* (06:00 - 09:00)
  - *Prefrontal Executive Peak* (09:00 - 12:00)
  - *Post-Prandial Rest & Digestion* (12:00 - 14:00)
  - *Creative Divergence & Synthesis* (14:00 - 17:00)
  - *Neuromuscular Peak & Motor Velocity* (17:00 - 20:00)
  - *Melatonin Induction & Screen Twilight* (20:00 - 23:00)
  - *Glymphatic Deep Brain Detox* (23:00 - 06:00)
- Interactive 24-hour circular dial with energy capacity gauge.

### 5. ⏱️ Quantum Deep Work HUD
- Cyberpunk focus HUD with 25m, 45m, and 90m ultradian sprint cycles.
- Integrated micro-distraction log counter to train neuro-attentional stamina.

---

## 🛠️ Compiling the `.ipa` without a Mac (GitHub Actions)

Since you don't have a Mac, this project comes preconfigured with a complete automated **GitHub Actions macOS CI/CD pipeline** (`.github/workflows/build_ios.yml`).

### How It Works:
1. Every time code is pushed to this repository or a release tag (`v1.0.0`) is created, GitHub automatically spins up a **macOS Apple Silicon runner** in the cloud.
2. The runner checks out the repository, installs the Flutter SDK, and runs:
   ```bash
   flutter build ios --release --no-codesign
   ```
3. It packages `Runner.app` into an `.ipa` file:
   ```bash
   mkdir -p Payload
   cp -r build/ios/iphoneos/Runner.app Payload/
   zip -r -9 AetherPulse.ipa Payload
   ```
4. It publishes the `.ipa` directly to **GitHub Actions Artifacts** and **GitHub Releases** for immediate one-click download!

---

## 📲 How to Install `AetherPulse.ipa` on your iPhone

You do NOT need a paid Apple Developer account ($99/year) to run this app on your iPhone. Use any free sideloading method:

### Option A: Sideloadly (Recommended for Windows)
1. Download [Sideloadly](https://sideloadly.io/) on your Windows PC.
2. Connect your iPhone via USB.
3. Drag & drop `AetherPulse.ipa` into Sideloadly.
4. Enter your free Apple ID and click **Start**.
5. On your iPhone, go to **Settings > General > VPN & Device Management** and tap **Trust**.
6. Open **Aether Pulse** and enjoy!

### Option B: AltStore
1. Install [AltServer](https://altstore.io/) on your PC.
2. Transfer the `.ipa` to your iPhone (via iCloud Drive, AirDrop, or local file transfer).
3. Open the `.ipa` with **AltStore** to install.

### Option C: TrollStore / Scarlet
- Compatible directly on device with TrollStore (iOS 14.0 - 17.0) or Scarlet on-device installer.

---

## 💻 Local Development
```bash
# Analyze code
flutter analyze

# Run unit & smoke tests
flutter test

# Run app (Windows / Chrome / Android / iOS Simulator if macOS available)
flutter run
```
