# FuelWindow

Flutter app for metabolic fueling guidance.

## Run on a connected iPhone

1. Connect the iPhone by USB and unlock it.
2. On the iPhone, trust this Mac if iOS asks.
3. Open `ios/Runner.xcworkspace` in Xcode.
4. In Xcode, select the `Runner` target, then set **Signing & Capabilities > Team** to your Apple ID team.
5. Keep the bundle identifier as `com.cjquan.fuelwindow`, or change it to another unique reverse-DNS id if Xcode says it is unavailable.
6. Back in this folder, run:

```sh
flutter pub get
flutter devices
flutter run -d <your-iphone-device-id>
```

If the app installs but does not open, check the iPhone under **Settings > General > VPN & Device Management** and trust the developer certificate for your Apple ID.
