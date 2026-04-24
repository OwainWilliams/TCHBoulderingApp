# TCH Bouldering Tracker

A Garmin Connect IQ watch app for logging bouldering sessions. Track problems by grade, record completions vs. attempts, time each problem, and sync session data to a cloud API.

---

## Features

- **Grade-based logging** — 10 colour-coded grades (Grey → Black)
- **Sent / Tried tracking** — Log each problem as completed or attempted
- **Live timers** — Session clock and per-problem stopwatch updated every second
- **Session summary** — Post-session breakdown by grade with upload status
- **Cloud sync** — POST session JSON to a configurable API endpoint; retries on next launch if offline
- **FIT file recording** — Each session saved as a Rock Climbing activity on the device
- **46 supported devices** — Forerunner 255/265/955/965, fēnix 6/7, Venu 3, vivoactive 5/6, Epix, Enduro, MARQ, Edge, and more

---

## Requirements

### Development

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (API level 5.2.0 or later)
- Visual Studio Code with the [Monkey-C extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c), **or** the Garmin Eclipse plugin
- A free [Garmin developer account](https://developer.garmin.com/) for sideloading to a real device

### Runtime

- A supported Garmin watch (see [Supported Devices](#supported-devices))
- Garmin Connect mobile app (iOS or Android) for cloud sync

---

## Project Structure

```
GarminBouldering/
├── source/
│   ├── BoulderingApp.mc       # App entry point, session state, API upload
│   ├── HomeView.mc            # Home screen (idle + active session display)
│   ├── GradePickerView.mc     # Scrollable grade selector
│   ├── ProblemActiveView.mc   # Live problem attempt timer
│   └── SummaryView.mc        # Post-session stats and upload status
├── resources/
│   ├── strings/strings.xml    # All UI string constants
│   ├── properties/properties.xml  # Default API settings
│   ├── settings/settings.xml  # User-configurable settings (Garmin Connect)
│   ├── drawables/             # App launcher icon
│   ├── layouts/               # Unused (all UI drawn in code)
│   └── menus/                 # Unused (all menus drawn in code)
├── manifest.xml               # App metadata, permissions, device list
└── monkey.jungle              # Build configuration
```

---

## Setup

### 1. Install the SDK

Download and install the [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/). Use it to install:
- The Connect IQ SDK (5.2.0 or later)
- Device simulator images for your target device (e.g. `fr955`)

### 2. Configure VS Code (recommended)

Install the [Monkey-C extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c), then point it at your SDK installation in settings:

```json
"monkeyC.sdkPath": "/path/to/connectiq-sdk"
```

### 3. Clone / open the project

```bash
git clone <repo-url>
cd GarminBouldering
```

Open the folder in VS Code. The extension will detect `monkey.jungle` automatically.

### 4. Build

**VS Code**: press `F5` to build and launch in the simulator, or use the command palette → *Monkey-C: Build for Device*.

**Command line**:
```bash
monkeyc -f monkey.jungle -o bin/BoulderingApp.prg -d fr955 -y developer_key.der
```

> If you add new resource files (e.g. `properties.xml`, `settings.xml`), delete the `bin/` folder before rebuilding to avoid stale-cache crashes.

### 5. Sideload to a real device

1. Put the watch in developer mode: **Settings → System → Developer Mode**
2. Connect via USB and copy `bin/BoulderingApp.prg` to `GARMIN/APPS/` on the device

---

## Configuration (Work in progress)

Just now you need to change the code and sideload it, rather than within the app. Hopefully I can fix this at some point. 

Two settings can be configured via the **Garmin Connect app** (phone → watch app settings):

| Setting | Default | Description |
|---|---|---|
| `ApiEndpoint` | `https://owain.codes/umbraco/api/bouldering/postsession` | URL the session JSON is posted to |
| `ApiKey` | *(see properties.xml)* | Bearer / header key sent with each request |

Settings are picked up on next app launch. In the simulator the settings dialog may not appear — the app falls back to the hardcoded defaults in `properties/properties.xml`.

### API payload format

```json
{
  "deviceId": "<unique-device-id>",
  "sessionDate": "2026-04-24T14:30:00",
  "totalDurationSec": 3600,
  "totalProblems": 12,
  "completedCount": 8,
  "attemptedCount": 4,
  "problems": [
    { "grade": "Blue", "outcome": "Completed", "durationSec": 45 },
    { "grade": "Purple", "outcome": "Attempted", "durationSec": 120 }
  ]
}
```

---

## How to Use

### Starting a session

1. Launch **TCH Bouldering** from the watch app list
2. On the home screen press **START** (the action button) to begin recording

### Logging a problem

1. From the home screen press **SELECT** to open the grade picker
2. Scroll with **UP / DOWN** to highlight your grade
3. Press **SELECT** to confirm — the problem timer starts
4. Climb the problem, then:
   - **UP** — log as **Sent** (completed)
   - **DOWN** — log as **Tried** (attempted)
   - **BACK** — cancel this attempt and return to the grade picker

After logging, you return to the grade picker at the same grade so you can quickly log another attempt at the same problem.

### Ending a session

From the home screen:
- **DOWN** → **Yes** — save the session, generate a FIT file, and upload to the API
- **BACK** → **Yes** — discard the session (no FIT file, no upload)

### Session summary

After saving you'll see:
- Total problems / Sent / Tried counts
- Per-grade breakdown (coloured dots with sent/total ratios)
- Upload status (green = uploaded, grey = pending sync, red = error code)

Press **BACK** to exit the app.

### Offline behaviour

If the watch isn't synced with the Garmin Connect app at session end, the payload is saved to watch storage. On the next launch the app automatically retries the upload. The summary screen shows "Will upload when synced" until the upload succeeds.

---

## Grade Reference

| # | Name | Colour |
|---|---|---|
| 0 | Grey | ![grey](https://placehold.co/12x12/808080/808080) |
| 1 | Green | ![green](https://placehold.co/12x12/00aa00/00aa00) |
| 2 | Orange | ![orange](https://placehold.co/12x12/ff8800/ff8800) |
| 3 | Blue | ![blue](https://placehold.co/12x12/0055ff/0055ff) |
| 4 | Purple | ![purple](https://placehold.co/12x12/8800aa/8800aa) |
| 5 | Pink | ![pink](https://placehold.co/12x12/ff55aa/ff55aa) |
| 6 | Red | ![red](https://placehold.co/12x12/cc0000/cc0000) |
| 7 | White | ![white](https://placehold.co/12x12/ffffff/ffffff) |
| 8 | Yellow | ![yellow](https://placehold.co/12x12/ffdd00/ffdd00) |
| 9 | Black | ![black](https://placehold.co/12x12/111111/111111) |

Grades match the colour system used at TCH (The Climbing Hangar) gyms. Adjust `GRADES[]` and the colour palette in `GradePickerView.mc` to match your local gym.

---

## Supported Devices

Forerunner 255, 255S, 255M, 255SM, 265, 265S, 955, 965 · fēnix 6, 6S, 6X, 6 Pro, 6S Pro, 6X Pro, 7, 7S, 7X, 7 Pro, 7S Pro, 7X Pro · Venu 3, 3S · vivoactive 5, 6 · Epix Gen 2, 2S, Pro · Epix (Gen 2) 42mm · Enduro 2, 3 · MARQ Gen 2 (Athlete, Aviator, Captain, Commander, Golfer, Driver) · Edge 1040, 1050 · D2 Mach 1, 1 Pro, Air

---

## Known Limitations

- `Toybox.Application.Properties.getValue()` crashes on the fr955 simulator; the app uses the deprecated `App.getApp().getProperty()` with hardcoded fallbacks instead
- The simulator settings menu (App Settings) may not appear — always test with hardcoded defaults in the simulator
- No automatic grade detection; all input is manual

---

## Permissions

The app requests three Connect IQ permissions:

| Permission | Reason |
|---|---|
| `Communications` | HTTP POST to the session API |
| `Fit` | ActivityRecording for the FIT file |
| `UserProfile` | `device.uniqueIdentifier` included in the API payload |
