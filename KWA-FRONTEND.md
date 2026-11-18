# UMMU AYMAN — Maelekezo kwa mtengenezaji wa Frontend (Flutter)

## 1. Server (API) iko hapa
| Kitu | Link |
|---|---|
| Base URL | `http://13.60.24.131` |
| Nyaraka (Swagger) | http://13.60.24.131/docs |
| OpenAPI JSON | http://13.60.24.131/openapi.json |

Endpoints zote ni **27**, na zote zimeshaunganishwa kwenye app (`lib/api/api.dart`). **Huna haja ya kuandika code ya API upya.**

## 2. Kuwasha app iongee na server
`lib/config.dart` tayari imewekwa hivi:
```dart
const bool kUseMock = false;
const String kBaseUrl = 'http://13.60.24.131';
```
(Ukitaka kuona app kwa data za mfano bila server: `kUseMock = true`, PIN `1234`.)

Kisha:
```bash
flutter create --org com.ummuayman --project-name ummu_ayman --platforms android,ios .
flutter pub get
```
**Muhimu (server ni http, si https):** `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application android:usesCleartextTraffic="true" ...>
```
Bila hii Android inazuia maombi yote → app itaonyesha kosa la mtandao.
Kisha `flutter run`.

## 3. Jinsi auth inavyofanya kazi
1. `POST /auth/pin` `{"pin":"1234"}` → `{"token":"..."}`
2. App inahifadhi token (`shared_preferences`) na kuituma kila ombi: `Authorization: Bearer <token>`
3. Ikipata `401` → inarudi kwenye skrini ya PIN.
4. Makosa yote yanakuja kama `{"detail":"ujumbe"}` → app inaonyesha `detail`.

## 4. Kila skrini inaita API gani
| Skrini | Faili | API |
|---|---|---|
| PIN | `pin_screen.dart` | `POST /auth/pin`, `POST /devices` |
| Nyumbani | `home_screen.dart` | `GET /home?date=YYYY-MM-DD`, `PUT /auth/pin`, `POST /auth/logout` |
| Mauzo ya leo | `sales_screen.dart` | `GET /daily/{date}`, `GET /products`, `GET /expenses/names`, `PUT /daily/{date}` |
| Stock | `stock_screen.dart` | `GET /products`, `POST /products` |
| Bidhaa (aina) | `product_screen.dart` | `POST /products/{id}/variants`, `PATCH /variants/{id}`, `DELETE /variants/{id}`, `PATCH /products/{id}`, `DELETE /products/{id}` |
| Risiti | `receipts_screen.dart` | `GET /receipts?date=`, `POST /receipts`, `GET /receipts/{id}`, `POST /receipts/{id}/cancel`, `GET /me` |
| Ripoti | `reports_screen.dart` | `GET /reports/week|month|year?date=`, `GET /reports/day/{date}` |
| (hiari) | — | `GET /variants/search?q=`, `DELETE /devices/{token}`, `GET /health` |

Muundo kamili wa JSON ya kila endpoint: `API-FASTAPI-MONGODB.md` (sehemu 6) au `/docs`.

## 5. Majaribio (fanya kwa mpangilio huu)
1. PIN sahihi → Nyumbani inafunguka. PIN mbaya → "PIN si sahihi".
2. Stock → + Bidhaa → "Udi" (haina aina) → inaonekana.
3. Kanzu → + Aina → aina mpya inaingia; hariri → ongeza idadi / bei.
4. Risiti → risiti mpya → stock inapungua → WhatsApp / PDF.
5. Mauzo ya leo → mistari ya risiti ipo → ongeza bidhaa + gharama → Hifadhi → Hariri → Hifadhi tena (stock isipungue mara mbili).
6. Nyumbani → faida ya leo = ile ya Mauzo ya leo.
7. Ripoti → Wiki / Mwezi / Mwaka → gusa siku.

Kosa lolote: angalia jina la field kwenye jibu la `/docs` dhidi ya `fromJson` kwenye `lib/models/models.dart` — lazima yalingane.

## 6. Kabla ya kuanza kutumia dukani
- Weka domain + HTTPS kwenye server (Nginx + Let's Encrypt), kisha `kBaseUrl = 'https://api.domain.co.tz'` na ondoa `usesCleartextTraffic`.
- Firebase (notifications): `FLUTTER-SETUP.md` sehemu 6.
- APK: `flutter build apk --release`.
