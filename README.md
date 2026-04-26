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

## Camera Nutrition Label Scanning

The iPhone app sends the captured label image to the `food-parser` Supabase Edge Function. No separate OCR API is required: the edge function uses Gemini vision to read the label and structured JSON output to return the nutrition object the app expects.

Set the Gemini key as a Supabase secret, not in the Flutter `.env` file:

```sh
supabase secrets set GEMINI_API_KEY=your-gemini-key
supabase functions deploy food-parser --no-verify-jwt
```

Then make sure the Flutter `.env` points at the deployed function:

```sh
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
FOOD_PARSER_URL=https://your-project.supabase.co/functions/v1/food-parser
```

Gemini image input supports JPEG, PNG, WEBP, HEIC, and HEIF, so iPhone camera photos should work directly.
