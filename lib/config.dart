/// MIPANGILIO YA APP
///
/// kUseMock = true  -> app inatumia data za mfano (bila server). PIN ya mfano: 1234
/// kUseMock = false -> app inaongea na FastAPI yako (kBaseUrl).
const bool kUseMock = false;

/// Anwani ya FastAPI.
/// - Android emulator: http://10.0.2.2:8000
/// - Simu halisi (wifi moja na PC): http://192.168.1.20:8000
/// - Server: https://api.domain-yako.co.tz
const String kBaseUrl = 'http://13.60.24.131';

/// Washa baada ya kuweka google-services.json (angalia FLUTTER-SETUP.md sehemu ya 6).
const bool kUseFirebase = false;

/// Idadi ya PIN
const int kPinLength = 4;
