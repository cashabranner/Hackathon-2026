# FuelWindow Collaborator Setup

This guide is for collaborators cloning the repo and running the Flutter app on Android.

## 1. Install Local Tools

Install:

- Flutter SDK
- Android Studio
- Android SDK / Platform Tools
- An Android emulator, such as Android Studio's Medium Phone, or a physical Android device

Check that Flutter can see your tools:

```powershell
flutter doctor
flutter devices
```

If `flutter` is not on PATH, use your full Flutter SDK path instead.

Example:

```powershell
C:\path\to\flutter\bin\flutter.bat doctor
```

## 2. Clone And Install Dependencies

```powershell
git clone <repo-url>
cd Hackathon-2026
flutter pub get
```

## 3. Create `.env`

Copy the example file:

```powershell
Copy-Item .env.example .env
```

Fill in these public Supabase values:

```env
SUPABASE_URL=https://xdclhtejfrethopywdxb.supabase.co
SUPABASE_ANON_KEY=<public-supabase-publishable-or-anon-key>
FOOD_PARSER_URL=https://xdclhtejfrethopywdxb.supabase.co/functions/v1/food-parser
COACH_CHAT_URL=https://xdclhtejfrethopywdxb.supabase.co/functions/v1/coach-chat
```

Do not put Gemini, OpenAI, or other private AI provider keys in `.env`.

The AI key is stored server-side in Supabase Edge Function secrets. In this project, the deployed `food-parser` function currently reads the secret named:

```text
OPENAI_API_KEY
```

Even though the secret name says `OPENAI_API_KEY`, the current function treats that value as a Gemini API key.

## 4. Run On Android Emulator

Start an emulator from Android Studio, or from PowerShell if you have an AVD named `Medium_Phone`:

```powershell
C:\Users\n8bro\AppData\Local\Android\Sdk\emulator\emulator.exe -avd Medium_Phone
```

Check the device id:

```powershell
flutter devices
```

Run the app with `.env` values passed to Flutter:

```powershell
$defines = Get-Content .env | Where-Object {
  $_ -match '^\s*(SUPABASE_URL|SUPABASE_ANON_KEY|FOOD_PARSER_URL|COACH_CHAT_URL)\s*='
} | ForEach-Object {
  "--dart-define=$($_.Trim())"
}

flutter run -d emulator-5554 @defines
```

If your emulator id is different, replace `emulator-5554` with the device id from `flutter devices`.

## 5. What The Supabase Function Does

The Flutter app sends food descriptions to:

```text
https://xdclhtejfrethopywdxb.supabase.co/functions/v1/food-parser
```

The Supabase Edge Function calls Gemini and returns nutrition JSON. If the remote parser is unavailable, the app falls back to its local hardcoded parser.

In the app's food preview:

- `AI estimate` means the Supabase/Gemini parser was used.
- `Local estimate` means the fallback parser was used.

The AI Coach page sends recent dashboard metrics and chat messages to:

```text
https://xdclhtejfrethopywdxb.supabase.co/functions/v1/coach-chat
```

The same server-side Gemini secret is used for coach replies.

## 6. Supabase Access For Maintainers

Collaborators who only run the app need the public Supabase URL and publishable/anon key.

Collaborators who deploy database or function changes also need:

- access to the Supabase project/team
- Supabase CLI login
- permission to link the project, push migrations, deploy functions, and manage secrets

Useful commands:

```powershell
npx.cmd -y supabase@latest login
npx.cmd -y supabase@latest link --project-ref xdclhtejfrethopywdxb
npx.cmd -y supabase@latest db push
npx.cmd -y supabase@latest functions deploy food-parser --no-verify-jwt
npx.cmd -y supabase@latest functions deploy coach-chat --no-verify-jwt
```

To update the server-side Gemini key, set the Supabase Edge Function secret:

```powershell
npx.cmd -y supabase@latest secrets set OPENAI_API_KEY=<gemini-api-key>
```

Never commit `.env` or private API keys.
