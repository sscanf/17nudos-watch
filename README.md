# 17nudos for Apple Watch

Apple Watch app showing live data from the [17nudos.com](https://www.17nudos.com) weather station in Castelldefels (Barcelona).

- **Wind:** current speed, average, gust, direction and 15-minute trend (green above 8 kn, as on the website). The compass arrow points to where the wind comes from; tap it for a full-screen compass with exact degrees and the direction range over the last 15 minutes.
- **Conditions:** temperature, humidity, pressure, 15-minute average and maximum gust.
- **Chart** of the wind over the last 3 hours.
- **Forecast:** hourly AEMET forecast published by 17nudos.com, as a 12-hour chart with wind direction; tap it for the full hour-by-hour list.
- **Wind alarm:** notification when the gust, average or current wind goes above a threshold. Swipe right from the first screen to open the settings. With the app closed, watchOS checks in the background (up to about 4 times per hour when the complication is on the watch face).
- **Webcams** (Escola Garbí and towards Sitges): live stream snapshot, refreshed every few minutes, with a full-screen view and Digital Crown zoom.
- **Complication** for the watch face (circular, rectangular, corner and inline).

Weather data and webcam images belong to 17nudos.com and their respective owners, and the forecast to AEMET; the license below covers only the app's source code.

## Requirements

- Xcode 16 or later
- watchOS 10 or later

## Installation

1. Open `Nudos.xcodeproj` in Xcode.
2. In *Signing & Capabilities*, select your team for both the **NudosWatch** and **NudosComplication** targets, and change the bundle identifiers to your own (the complication's must start with the app's).
3. Select the **NudosWatch** scheme, choose your Apple Watch as the destination and press ▶︎.

## Project structure

| Folder | Contents |
|---|---|
| `NudosWatch/` | Watch app (screens, webcams, state) |
| `NudosComplication/` | WidgetKit complication |
| `Shared/` | Models, station abstraction and colors, shared by both targets |
| `Shared/Stations/` | One data source per weather network (currently only 17nudos.com) |
| `Config/` | Complication Info.plist |

## Adding a station

The app reads all its data through the `StationSource` protocol (`Shared/Station.swift`). To support another station, implement it in `Shared/Stations/` (only the live reading is required; history and forecast are optional) and add the station to `Station.all`. For now 17nudos.com is the only station.

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE): you may use, modify and share it **for noncommercial purposes**.

**Commercial use:** any commercial or for-profit use requires a separate commercial license. Contact [ocasamitjana@icloud.com](mailto:ocasamitjana@icloud.com).

Copyright 2026 Oscar Casamitjana
