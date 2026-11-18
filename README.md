# UMMU AYMAN OUTFITS — Flutter app (setup kamili)

App ya simu ya daftari la duka. Skrini zote zimetengenezwa kama ulivyozikubali kwenye picha (folder `picha/`, pamoja na video `UMMU-AYMAN-APP-FLOW-NZIMA.mp4`).

---

## 1. Mahitaji
- Flutter **3.22+** (Dart 3.3+) — `flutter --version`
- Android Studio (Android SDK) au VS Code + simu ya Android/emulator
- (iOS) Mac + Xcode

## 2. Kuendesha kwa mara ya kwanza
Fungua terminal ndani ya folder hili (`ummu_app`):
```bash
# 1. tengeneza folders za android/ios (code ya lib/ haiguswi)
flutter create --org com.ummuayman --project-name ummu_ayman --platforms android,ios .

# 2. pakua packages
flutter pub get

# 3. endesha
flutter run
```
App inaanza kwenye **PIN**. Kwa sasa inatumia data za mfano (mock) — **PIN ni `1234`**.

> Kama `flutter create` itauliza kuandika upya faili lolote ndani ya `lib/`, **usikubali** (code ya app iko tayari). `test/widget_test.dart` itakayotengenezwa ifute (inarejea `MyApp` isiyokuwepo).

## 3. Mipangilio (`lib/config.dart`)
```dart
const bool kUseMock = true;                     // true = data za mfano, false = API halisi
const String kBaseUrl = 'http://10.0.2.2:8000'; // emulator → PC yako; simu halisi → IP ya PC (mf. http://192.168.1.20:8000)
const bool kUseFirebase = false;                // true baada ya kuweka Firebase (sehemu 6)
const int kPinLength = 4;
```

## 4. Android (baada ya `flutter create`)
`android/app/src/main/AndroidManifest.xml`:
```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:label="Ummu Ayman"
        android:usesCleartextTraffic="true"   <!-- kwa http:// wakati wa majaribio; ondoa ukitumia https -->
        ...>
        ...
    </application>

    <!-- kufungua WhatsApp (wa.me) -->
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
    </queries>
</manifest>
```
`android/app/build.gradle` → `minSdk = 23` (inahitajika na Firebase).

iOS: `ios/Runner/Info.plist` ongeza
```xml
<key>LSApplicationQueriesSchemes</key><array><string>https</string><string>whatsapp</string></array>
```

## 5. Kuunganisha na API halisi (FastAPI)
1. Tengeneza backend kwa kufuata **`API-FASTAPI-MONGODB.md`** (endpoints 27).
2. Endesha: `uvicorn app.main:app --host 0.0.0.0 --port 8000`
3. Tengeneza duka + PIN: `python scripts/create_shop.py --pin 1234 ...`
4. `lib/config.dart`: `kUseMock = false`, `kBaseUrl = 'http://<IP ya PC>:8000'`
5. `flutter run`

Code yote ya mtandao iko `lib/api/api.dart` (`HttpApi`). Token inahifadhiwa kwenye `shared_preferences`; kila kosa la server linaonyeshwa kwa ujumbe wa `detail`.

### API zinaitwa wapi
| Skrini (faili) | API |
|---|---|
| PIN (`pin_screen.dart`) | `POST /auth/pin`, kisha `POST /devices` |
| Nyumbani (`home_screen.dart`) | `GET /home?date=`; menyu: `PUT /auth/pin`, `POST /auth/logout` |
| Mauzo ya leo (`sales_screen.dart`) | `GET /daily/{date}`, `GET /products`, `GET /expenses/names`, `PUT /daily/{date}` |
| Stock (`stock_screen.dart`) | `GET /products`, `POST /products` |
| Bidhaa / aina (`product_screen.dart`) | `POST /products/{id}/variants`, `PATCH /variants/{id}`, `DELETE /variants/{id}`, `PATCH /products/{id}`, `DELETE /products/{id}` |
| Risiti (`receipts_screen.dart`) | `GET /receipts?date=`, `POST /receipts`, `GET /receipts/{id}`, `POST /receipts/{id}/cancel`, `GET /me` |
| Ripoti (`reports_screen.dart`) | `GET /reports/week|month|year?date=`, `GET /reports/day/{date}` |

## 6. Notifications (Firebase)
1. https://console.firebase.google.com → Add project → **Add app → Android**, package: `com.ummuayman.ummu_ayman`
2. Pakua `google-services.json` → weka `android/app/`
3. Rahisi zaidi:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
4. `lib/config.dart` → `kUseFirebase = true`
5. Server: Service account key → `firebase-service-account.json` (angalia API MD sehemu 9)

Notifications 5: **stock_out** (imeisha), **stock_low** (inakaribia kuisha), **close_day** (21:00 kama hujahifadhi mauzo), **weekly_report** (Jumapili 21:30), **new_receipt**. Code: `lib/services/notifications.dart`.

## 7. Muundo wa code
```
lib/
  main.dart                 # inaanza: PIN (au Shell kama tayari ameingia)
  config.dart               # mock / URL / Firebase
  theme.dart                # rangi (bluu #0369A1, nyeupe), font Inter
  utils/format.dart         # pesa 1,250,000; tarehe za Kiswahili; kutafuta majina
  models/models.dart        # Product, Variant, Receipt, DailySheet, Report ...
  api/api.dart              # Api (abstract) + HttpApi (FastAPI)
  api/mock_api.dart         # data za mfano (PIN 1234)
  widgets/ui.dart           # vitufe vidogo, dialog za katikati, jedwali, Statement
  services/pdf.dart         # PDF ya risiti (A5) na ripoti (A4)
  services/notifications.dart
  screens/
    pin_screen.dart         # duara + kufuli, vidoti 4, vitufe vya jedwali, inajikagua yenyewe
    shell.dart              # menyu ya chini: Nyumbani, Mauzo, Stock, Ripoti, Risiti
    home_screen.dart        # faida ya leo, makundi ya stock, dirisha la kundi (C), vilivyouzwa leo
    sales_screen.dart       # daftari: bidhaa → gharama → hesabu → Hifadhi/Hariri
    stock_screen.dart       # bidhaa zote + Bidhaa mpya (haina / ina aina)
    product_screen.dart     # + Aina juu, kadi za aina, ongeza idadi / bei / futa
    receipts_screen.dart    # orodha, risiti mpya, risiti rasmi (PDF + WhatsApp)
    reports_screen.dart     # wiki / mwezi / mwaka, grafu, jedwali, stock, PDF
picha/                      # picha 36 za skrini + video ya flow nzima
API-FASTAPI-MONGODB.md      # maelekezo kamili ya backend
```

## 8. Icons na fonts
- Icons ni **Material Icons** zilizo ndani ya Flutter (nyeusi) — hakuna faili za picha za kuongeza.
- Font **Inter** inapakuliwa na `google_fonts` mara ya kwanza (inahitaji intaneti mara moja). Kuitumia bila intaneti: weka faili za Inter `assets/fonts/` na `GoogleFonts.config.allowRuntimeFetching = false`.
- Icon ya app (launcher): weka picha yako `assets/icon.png`, kisha tumia package `flutter_launcher_icons`.

## 9. Kutengeneza APK
```bash
flutter build apk --release
# faili: build/app/outputs/flutter-apk/app-release.apk
```

## 10. Kanuni za muundo (zisibadilishwe)
- Skrini nyeupe, bluu #0369A1, icons nyeusi, hakuna icons za bidhaa.
- Kijani = PIN sahihi tu. Nyekundu = makosa, "imeisha", kufuta tu.
- Hakuna asilimia wala mishale nyekundu kwenye Ripoti. Hakuna toast. Vitufe vidogo, vyembamba.
- Hakuna splash. Dialogs zote katikati zenye ✕.

## 11. Kumbuka
Code hii haikuweza kujaribiwa (compile) hapa nilipoitengenezea. Ukipata kosa lolote kwenye `flutter run`, nitumie ujumbe wa kosa nitakurekebishia.
