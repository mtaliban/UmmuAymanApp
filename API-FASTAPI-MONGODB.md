# UMMU AYMAN OUTFITS — API kamili (FastAPI + MongoDB + Firebase)

> **Kwa AI/mtengenezaji:** soma faili hili lote kisha tengeneza backend nzima kama ilivyoelezwa hapa — endpoints **27**, majina ya fields, JSON, hesabu, notifications na majaribio. App ya Flutter (zip hii) tayari inaita endpoints hizi kwa majina haya haya (`lib/api/api.dart`, `lib/models/models.dart`). **Usibadilishe majina ya njia wala fields.**

---

## 0. App inafanya nini (kwa ufupi)

Daftari la duka la nguo. **Halimuuzii mtu online.** Mwenye duka anatumia simu yake:

| Skrini | Kazi |
|---|---|
| **PIN** | Anaingia kwa PIN ya namba 4 tu (hakuna namba ya simu). |
| **Nyumbani** | Faida halisi ya leo; makundi ya stock (jina + idadi); dirisha la kundi (kila aina: zilikuwa / zimeuzwa / zimebaki / buying / selling / faida); vilivyouzwa leo. |
| **Mauzo ya leo** | Usiku anaandika kama daftari: bidhaa alizouza bila risiti (jina → idadi → bei) + gharama (jina lolote) → Hifadhi. Mistari ya risiti za mchana inakuwepo tayari. |
| **Stock** | Bidhaa/makundi; bidhaa **yenye aina** (Kanzu → Alfurqan Kanzu, Kanzu ya Oman…) au **isiyo na aina** (Udi). Kuongeza aina, kuongeza mzigo, kubadilisha bei, kufuta. |
| **Risiti** | Risiti rasmi kwa mteja wa WhatsApp (imelipwa daima). Stock inapungua papo hapo. |
| **Ripoti** | Wiki / Mwezi / Mwaka: faida halisi, grafu, kwa siku/wiki/mwezi, bidhaa zinazouzika, stock. |

Pesa zote = **integer TSh** (hakuna desimali). Tarehe = `YYYY-MM-DD` kwa saa za **Africa/Dar_es_Salaam (UTC+3)**.

---

## 1. Teknolojia

- Python 3.11+, **FastAPI**, Uvicorn
- **MongoDB 6+** kupitia **Motor** (async). Atlas au local.
- Pydantic v2
- Auth: **JWT** (`pyjwt`) + PIN imehifadhiwa kwa **bcrypt** (`passlib[bcrypt]`)
- Notifications: **Firebase Cloud Messaging** kupitia `firebase-admin`
- Kazi za muda (21:00 n.k.): **APScheduler** (`AsyncIOScheduler`)

`requirements.txt`
```
fastapi==0.115.*
uvicorn[standard]==0.30.*
motor==3.5.*
pydantic==2.*
pydantic-settings==2.*
pyjwt==2.*
passlib[bcrypt]==1.7.*
firebase-admin==6.*
apscheduler==3.10.*
python-dotenv==1.*
httpx==0.27.*
pytest==8.*
pytest-asyncio==0.23.*
```

`.env`
```
MONGO_URL=mongodb://localhost:27017
DB_NAME=ummu_ayman
JWT_SECRET=badilisha-iwe-ndefu-sana-na-siri
JWT_DAYS=90
TZ_NAME=Africa/Dar_es_Salaam
FIREBASE_CREDENTIALS=./firebase-service-account.json   # acha tupu kama hutumii notifications
LOW_STOCK_THRESHOLD=2
CLOSE_DAY_REMINDER=21:00
WEEKLY_REPORT_TIME=SUN 21:30
```

Muundo wa folders
```
app/
  main.py              # FastAPI(), CORS, exception handlers, routers, indexes, scheduler
  config.py            # settings (.env)
  db.py                # Motor client, get_db(), create_indexes()
  auth.py              # hash/verify PIN, JWT, dependency current_shop
  tz.py                # today(), now() kwa TZ ya Tanzania
  schemas.py           # Pydantic models
  services/
    stock.py           # kupunguza/kuongeza stock kwa usalama + stock_movements
    summary.py         # hesabu za siku/kipindi
    reports.py         # wiki / mwezi / mwaka / siku
    notify.py          # FCM (stock_out, stock_low, close_day, weekly_report, new_receipt)
  routers/
    auth.py  me.py  devices.py  home.py  products.py  variants.py
    daily.py  expenses.py  receipts.py  reports.py
  jobs.py              # APScheduler jobs
scripts/
  create_shop.py       # kutengeneza duka + PIN
  seed_demo.py         # (hiari) data za mfano
tests/
  test_flow.py
```
Endesha: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`

---

## 2. Kanuni za jumla

1. **CORS**: `allow_origins=["*"]`, methods na headers zote.
2. **Auth**: kila endpoint (isipokuwa `POST /auth/pin` na `GET /health`) inahitaji `Authorization: Bearer <token>`. Bila token / token mbovu → `401 {"detail":"Ingia tena"}`.
3. **Makosa**: kila kosa ni `{"detail": "Ujumbe wa Kiswahili"}`. App inaonyesha `detail` kama ilivyo.
   Badilisha handler ya Pydantic 422 ili `detail` iwe **string moja**:
   ```python
   @app.exception_handler(RequestValidationError)
   async def _v(_, exc):
       e = exc.errors()[0]
       field = ".".join(str(x) for x in e["loc"][1:])
       return JSONResponse(status_code=422, content={"detail": f"{field}: {e['msg']}"})
   ```
4. **IDs**: MongoDB `_id` (ObjectId) inarudishwa kama `"id"` (string). Vivyo hivyo `product_id`, `variant_id`.
5. **shop_id**: kila document ina `shop_id`; kila query ichujwe kwa duka la token. (Server moja inaweza kuhudumia maduka mengi.)
6. **Stock haishuki chini ya 0** kamwe. Tumia update yenye sharti `{"qty": {"$gte": n}}`.
7. **Transactions**: Atlas/replica set → tumia `session.start_transaction()` kwa `POST /receipts`, `PUT /daily/{date}`, `POST /receipts/{id}/cancel`. Bila replica set → fanya kwa mpangilio na rudisha (rollback) mwenyewe ikishindikana.
8. **Unstructured**: MongoDB inaruhusu fields za ziada. Gharama (`expenses`), maelezo ya mteja, na bidhaa zinaweza kuwa na fields zozote za ziada (mf. `{"name":"Bando","amount":1000,"mtandao":"Vodacom","note":"wiki"}`) — **hifadhi kama zilivyo** na zirudishe kama zilivyo. Hakikisha tu `name` (string) na `amount` (int > 0) zipo.

---

## 3. Collections za MongoDB

### 3.1 `shops`
```json
{
  "_id": ObjectId,
  "name": "UMMU AYMAN OUTFITS",
  "phone": "0621 340 044",
  "email": "kambilatifah@gmail.com",
  "pin_hash": "$2b$12$...",
  "receipt_seq": 5,
  "settings": { "low_stock_threshold": 2, "close_day_reminder": "21:00" },
  "created_at": ISODate
}
```

### 3.2 `devices` (simu za kupokea notifications)
```json
{ "_id": ObjectId, "shop_id": ObjectId, "fcm_token": "f9Kx…", "platform": "android", "updated_at": ISODate }
```
Index: `(fcm_token)` unique.

### 3.3 `products` — bidhaa/kundi pamoja na **aina zake ndani (embedded)**
Bidhaa **isiyo na aina** ina aina MOJA yenye jina sawa na bidhaa (`has_types: false`). Hivyo mauzo yote yanarejea `variant_id` daima.
```json
{
  "_id": ObjectId,
  "shop_id": ObjectId,
  "name": "Kanzu",
  "name_lc": "kanzu",
  "has_types": true,
  "variants": [
    { "_id": ObjectId, "name": "Alfurqan Kanzu", "name_lc": "alfurqan kanzu",
      "qty": 6, "buying": 50000, "selling": 65000, "created_at": ISODate },
    { "_id": ObjectId, "name": "Kanzu ya Oman", "name_lc": "kanzu ya oman",
      "qty": 6, "buying": 30000, "selling": 40000, "created_at": ISODate }
  ],
  "created_at": ISODate,
  "updated_at": ISODate
}
```
Indexes: `(shop_id, name_lc)` unique; `(shop_id, "variants._id")`; text/regex kwenye `variants.name_lc`.

Kupunguza stock ya aina kwa usalama:
```python
res = await db.products.update_one(
    {"_id": pid, "shop_id": sid, "variants": {"$elemMatch": {"_id": vid, "qty": {"$gte": q}}}},
    {"$inc": {"variants.$.qty": -q}, "$set": {"updated_at": now()}})
if res.modified_count == 0:
    raise HTTPException(400, f"{name}: zipo {current_qty} tu")
```

### 3.4 `stock_movements` (historia ya kila badiliko la stock — audit + "Manunuzi")
```json
{ "shop_id": ObjectId, "product_id": ObjectId, "variant_id": ObjectId, "name": "Alfurqan Kanzu",
  "change": -2, "qty_after": 6, "buying": 50000,
  "reason": "receipt" | "daily" | "daily_revert" | "new" | "restock" | "receipt_cancel" | "delete",
  "ref_id": ObjectId|null, "date": "2026-11-17", "at": ISODate }
```
Index: `(shop_id, date)`. **Manunuzi ya kipindi** = Σ `change * buying` kwa `reason in ["new","restock"]` na `change > 0`.

### 3.5 `receipts`
```json
{
  "_id": ObjectId, "shop_id": ObjectId,
  "number": "0005",
  "date": "2026-11-17",
  "created_at": ISODate,
  "status": "paid" | "cancelled",
  "customer": { "name": "Said Hamad", "phone": "0712 445 900" },
  "items": [
    { "variant_id": ObjectId, "product_id": ObjectId, "name": "Alfurqan Kanzu",
      "qty": 2, "price": 65000, "discount": 5000, "buying": 50000 }
  ],
  "totals": { "qty": 3, "gross": 152000, "discount": 10000, "paid": 142000, "capital": 115000, "profit": 27000 }
}
```
`discount` ni **kwa kila kimoja**. `buying` ni nakala (snapshot) ya buying wakati wa kuuza.
Indexes: `(shop_id, date)`, `(shop_id, number)` unique.

### 3.6 `daily_sheets` (Mauzo ya leo — mstari mmoja kwa siku)
```json
{
  "_id": ObjectId, "shop_id": ObjectId, "date": "2026-11-17",
  "lines": [
    { "variant_id": ObjectId, "product_id": ObjectId, "name": "Kofia nyeusi",
      "qty": 2, "selling": 22000, "buying": 15000, "stock_selling": 22000 }
  ],
  "expenses": [
    { "name": "Usafirishaji", "amount": 2000 },
    { "name": "Bando", "amount": 1000, "mtandao": "Vodacom" }
  ],
  "saved_at": ISODate, "updated_at": ISODate
}
```
Index: `(shop_id, date)` unique.
**`lines` hazina mauzo ya risiti** — hayo yanasomwa kutoka `receipts` (ili yasihesabiwe mara mbili).

### 3.7 `notifications_log` (hiari)
`{shop_id, type, title, body, data, sent_at, ok}` — kuzuia kutuma ujumbe ule ule mara nyingi (mf. `stock_low` kwa aina ile ile siku moja).

---

## 4. Hesabu (lazima zilingane na app)

| Kitu | Fomula |
|---|---|
| Faida kimoja (aina) | `selling − buying` |
| Mtaji (aina) | `qty × buying` |
| Faida zote / Faida ukiuza | `qty × (selling − buying)` |
| Kiasi (mstari wa risiti) | `qty × (price − discount)` |
| Imelipwa (risiti) | `Σ kiasi` |
| Mauzo ya mstari (daftari) | `qty × selling` |
| **Mauzo ya siku** | `Σ receipts.totals.paid` (status=paid) `+ Σ daily.lines qty×selling` |
| **Mtaji wa vilivyouzwa** | `Σ receipts.totals.capital + Σ daily.lines qty×buying` |
| Faida ya bidhaa | `mauzo − mtaji` |
| Gharama | `Σ daily.expenses.amount` |
| **Faida halisi** | `mauzo − mtaji − gharama` |

`summary` popote = `{"sales", "capital", "expenses", "product_profit", "net"}`.

---

## 5. Orodha ya endpoints (27)

| # | Method | Njia | Skrini |
|---|---|---|---|
| 1 | POST | `/auth/pin` | PIN |
| 2 | POST | `/auth/logout` | Nyumbani → menyu → Toka |
| 3 | PUT | `/auth/pin` | Nyumbani → menyu → Badilisha PIN |
| 4 | GET | `/me` | Risiti rasmi / PDF (jina, simu, email ya duka) |
| 5 | POST | `/devices` | baada ya PIN (FCM token) |
| 6 | DELETE | `/devices/{token}` | Toka |
| 7 | GET | `/home?date=` | Nyumbani |
| 8 | GET | `/products` | Stock, Mauzo (kutafuta), Risiti mpya (kutafuta) |
| 9 | POST | `/products` | Stock → + Bidhaa mpya |
| 10 | PATCH | `/products/{id}` | badilisha jina |
| 11 | DELETE | `/products/{id}` | Futa bidhaa |
| 12 | POST | `/products/{id}/variants` | + Aina |
| 13 | PATCH | `/variants/{id}` | Ongeza idadi / badilisha bei |
| 14 | DELETE | `/variants/{id}` | Futa aina hii |
| 15 | GET | `/variants/search?q=` | (hiari) kutafuta upande wa server |
| 16 | GET | `/daily/{date}` | Mauzo ya leo |
| 17 | PUT | `/daily/{date}` | Mauzo ya leo → Hifadhi |
| 18 | GET | `/expenses/names` | Mapendekezo ya majina ya gharama |
| 19 | GET | `/receipts?date=` | Risiti |
| 20 | POST | `/receipts` | Risiti mpya → Tengeneza risiti |
| 21 | GET | `/receipts/{id}` | Risiti rasmi |
| 22 | POST | `/receipts/{id}/cancel` | Futa risiti (inarudisha stock) |
| 23 | GET | `/reports/week?date=` | Ripoti → Wiki |
| 24 | GET | `/reports/month?date=` | Ripoti → Mwezi |
| 25 | GET | `/reports/year?date=` | Ripoti → Mwaka |
| 26 | GET | `/reports/day/{date}` | Ripoti → gusa siku (dirisha) |
| 27 | GET | `/health` | — |

PDF za risiti na ripoti zinatengenezwa **ndani ya app** (package `pdf`), hazihitaji endpoint.

---

## 6. Maelezo ya kila endpoint

### 6.1 Auth

**1. `POST /auth/pin`**
```json
// request
{ "pin": "1234" }
// 200
{ "token": "eyJhbGciOi…", "shop": { "id": "…", "name": "UMMU AYMAN OUTFITS", "phone": "0621 340 044", "email": "kambilatifah@gmail.com" } }
```
- Duka moja kwa server (au tafuta duka kwa PIN — PIN iwe unique kwa duka). Linganisha kwa `bcrypt.verify`.
- Kosa → `401 {"detail":"PIN si sahihi"}`.
- Zuia kubahatisha: majaribio 5 mabaya ndani ya dakika 10 kwa IP/kifaa → `429 {"detail":"Subiri dakika 10"}`.
- JWT payload: `{"sub": shop_id, "exp": now + JWT_DAYS}`.

**2. `POST /auth/logout`** → `204`. (Hiari: weka token kwenye blacklist.) Hiari: futa pia kifaa kwa `DELETE /devices/{token}`.

**3. `PUT /auth/pin`**
```json
{ "old_pin": "1234", "new_pin": "5678" }
```
`new_pin` = tarakimu 4. Kosa → `400 {"detail":"PIN ya zamani si sahihi"}`. 200 → `{"ok": true}`.

**4. `GET /me`** → `{ "id", "name", "phone", "email" }`

### 6.2 Devices (FCM)

**5. `POST /devices`** `{ "fcm_token": "…", "platform": "android" | "ios" }` → upsert kwa `fcm_token`, weka `shop_id`. 200 `{"ok":true}`
**6. `DELETE /devices/{token}`** → `204`

### 6.3 Nyumbani

**7. `GET /home?date=2026-11-17`**
```json
{
  "date": "2026-11-17",
  "summary": { "sales": 364000, "capital": 265000, "expenses": 3000, "product_profit": 99000, "net": 96000 },
  "products": [
    {
      "id": "…", "name": "Kanzu", "has_types": true,
      "variants": [
        { "id": "…", "product_id": "…", "product_name": "Kanzu", "name": "Alfurqan Kanzu",
          "qty": 6, "buying": 50000, "selling": 65000, "sold_today": 2, "profit_today": 30000 },
        { "id": "…", "product_id": "…", "product_name": "Kanzu", "name": "Kanzu ya Oman",
          "qty": 6, "buying": 30000, "selling": 40000, "sold_today": 0, "profit_today": 0 }
      ]
    }
  ],
  "sold_today": [
    { "name": "Alfurqan Kanzu", "qty": 2, "buying": 50000, "selling": 65000, "profit": 30000 }
  ]
}
```
- `sold_today` / `profit_today` = risiti (paid) + daily.lines za tarehe hiyo, kwa aina.
- App inahesabu "Zilikuwa" = `qty + sold_today`, "Zimebaki" = `qty`.
- `sold_today` (orodha) = kwa jina la aina, `buying`/`selling` ni bei ya kimoja (wastani ikiwa ziliuzwa kwa bei tofauti), `profit` jumla.

### 6.4 Stock

**8. `GET /products`** → orodha (mpangilio wa `created_at`):
```json
[ { "id": "…", "name": "Udi", "has_types": false,
    "variants": [ { "id": "…", "product_id": "…", "product_name": "Udi", "name": "Udi", "qty": 6, "buying": 15000, "selling": 25000 } ] } ]
```

**9. `POST /products`**
```json
// haina aina
{ "name": "Mafuta ya nywele", "has_types": false, "qty": 12, "buying": 3000, "selling": 5000 }
// ina aina (aina zinaongezwa baadaye kwa #12)
{ "name": "Jalabia", "has_types": true }
```
- Jina lisilo tupu; `(shop_id, name_lc)` unique → `409 {"detail":"Bidhaa \"Udi\" ipo tayari"}`.
- Haina aina: tengeneza aina moja yenye jina sawa; `qty ≥ 0`, `buying > 0`, `selling > 0`. Andika `stock_movements` (`reason:"new"`) kama `qty>0`.
- `201` → product (muundo wa #8).

**10. `PATCH /products/{id}`** `{ "name": "Jina jipya" }` → kama `has_types=false` badilisha pia jina la aina yake. → product.

**11. `DELETE /products/{id}`** → `204`. Andika `stock_movements` (`reason:"delete"`) kwa kila aina yenye qty>0. Risiti na daily za zamani zinabaki (zina nakala ya jina).

**12. `POST /products/{id}/variants`**
```json
{ "name": "Kanzu ya Morocco", "qty": 5, "buying": 35000, "selling": 50000 }
```
- Kama bidhaa ilikuwa `has_types=false`: weka `has_types=true` (ile aina ya zamani inabaki kama aina ya kwanza — mtumiaji anaweza kuibadilisha jina kwa #13).
- Jina la aina unique ndani ya bidhaa → `409`.
- `stock_movements` (`reason:"new"`). `201` → variant (muundo wa variant kwenye #8).

**13. `PATCH /variants/{id}`** — kuongeza mzigo na/au kubadilisha bei/jina
```json
{ "add_qty": 10, "buying": 50000, "selling": 70000, "name": "Alfurqan Kanzu" }
```
- `add_qty ≥ 0` (0 = kubadilisha bei tu). `qty += add_qty`.
- Kama `add_qty>0`: `stock_movements` (`reason:"restock"`, `buying` mpya).
- Mauzo ya zamani **hayabadiliki** (yana snapshot ya buying).
- 200 → variant.

**14. `DELETE /variants/{id}`** → `204`. Kama ilikuwa aina ya mwisho ya bidhaa → futa bidhaa nzima.

**15. `GET /variants/search?q=aba%20ny`** → hadi 10:
```json
[ { "id": "…", "product_id": "…", "product_name": "Abaya", "name": "Abaya nyeusi", "qty": 5, "buying": 7000, "selling": 11000 } ]
```
Utafutaji: kila neno la `q` liwe mwanzo wa neno fulani kwenye jina (`aba ny` → "**Aba**ya **ny**eusi"). App ya sasa inatafuta upande wake (inapakua `/products`), hii ni kwa stock kubwa.

### 6.5 Mauzo ya leo (daftari)

**16. `GET /daily/2026-11-17`**
```json
{
  "date": "2026-11-17",
  "receipt_lines": [
    { "variant_id": "…", "name": "Alfurqan Kanzu", "qty": 2, "selling": 65000, "buying": 50000, "receipt_no": "0003" },
    { "variant_id": "…", "name": "Kofia nyeupe", "qty": 1, "selling": 25000, "buying": 20000, "receipt_no": "0003" }
  ],
  "lines": [
    { "variant_id": "…", "name": "Kofia nyeusi", "qty": 2, "selling": 22000, "buying": 15000, "stock_selling": 22000 },
    { "variant_id": "…", "name": "Viatu vya kufunga", "qty": 3, "selling": 33000, "buying": 25000, "stock_selling": 35000 }
  ],
  "expenses": [ { "name": "Usafirishaji", "amount": 2000 }, { "name": "Bando", "amount": 1000 } ],
  "saved_at": "2026-11-17T21:40:00+03:00",
  "summary": { "sales": 364000, "capital": 265000, "expenses": 3000, "product_profit": 99000, "net": 96000 }
}
```
- `receipt_lines`: kila item ya kila risiti `paid` ya siku hiyo; `selling = price − discount`, `receipt_no = number`.
- Siku isiyo na sheet → `lines: []`, `expenses: []`, `saved_at: null` (bado `receipt_lines` zinarudi).

**17. `PUT /daily/2026-11-17`** — Hifadhi (na Hariri ikihifadhiwa tena)
```json
{
  "lines": [
    { "variant_id": "…", "qty": 2, "selling": 22000 },
    { "variant_id": "…", "qty": 3, "selling": 33000 }
  ],
  "expenses": [
    { "name": "Usafirishaji", "amount": 2000 },
    { "name": "Bando", "amount": 1000, "mtandao": "Vodacom" }
  ]
}
```
Kanuni:
- `qty > 0`, `selling > 0`. Aina moja ikija mara mbili → **usiunganishe** (ni mistari tofauti ya daftari), ila kwa hesabu ya stock tumia jumla.
- `expenses`: `name` si tupu, `amount > 0`; fields nyingine zihifadhiwe kama zilivyo.
- Siku ijayo → `400 {"detail":"Huwezi kuandika siku ijayo"}`.
- **Stock kwa DELTA** (ili kuhifadhi mara mbili kusipunguze mara mbili):
  1. soma `old = daily_sheets.lines` (kama ipo).
  2. kwa kila `variant_id`: `delta = Σ new.qty − Σ old.qty`.
  3. `delta > 0` → hakikisha `qty ≥ delta` (vinginevyo `400 "<jina>: zipo N tu"`), kisha `$inc: -delta`.
  4. `delta < 0` → `$inc: +|delta|` (rudisha).
  5. `stock_movements` (`reason: "daily"` au `"daily_revert"`).
- Kila mstari mpya: chukua nakala ya `name`, `product_id`, `buying` (ya sasa), `stock_selling` (= selling ya stock). Kwa mstari uliokuwepo awali (aina ile ile), tumia `buying` ya zamani.
- Upsert `(shop_id, date)`, `saved_at = now`.
- Baada ya kuhifadhi: kagua `stock_out` / `stock_low` (sehemu 9).
- 200 → muundo wa #16.

**18. `GET /expenses/names`** → `["Usafirishaji","Bando","Chakula","Umeme","Kodi ya fremu"]`
Majina 10 yaliyotumika zaidi siku 60 zilizopita (aggregation `$unwind expenses → $group name → $sort count`), ukiunganisha na orodha ya kawaida hapo juu.

### 6.6 Risiti

**19. `GET /receipts?date=2026-11-17`** → risiti `paid` za siku hiyo, **mpya kwanza**:
```json
[ { "id": "…", "number": "0005", "date": "2026-11-17", "created_at": "2026-11-17T21:12:00+03:00",
    "customer": { "name": "Said Hamad", "phone": "0712 445 900" },
    "items": [ { "variant_id": "…", "name": "Alfurqan Kanzu", "qty": 2, "price": 65000, "discount": 5000, "buying": 50000 },
               { "variant_id": "…", "name": "Kofia nyeusi", "qty": 1, "price": 22000, "discount": 0, "buying": 15000 } ],
    "totals": { "qty": 3, "gross": 152000, "discount": 10000, "paid": 142000, "capital": 115000, "profit": 27000 } } ]
```

**20. `POST /receipts`**
```json
{ "customer": { "name": "Said Hamad", "phone": "0712 445 900" },
  "items": [ { "variant_id": "…", "qty": 2, "price": 65000, "discount": 5000 },
             { "variant_id": "…", "qty": 1, "price": 22000, "discount": 0 } ] }
```
- `customer.name` si tupu → `"Andika jina la mteja"`. `phone` hiari.
- `items ≥ 1`; `qty > 0`; `price > 0`; `0 ≤ discount ≤ price` (`"Punguzo ni kubwa kuliko bei"`).
- Stock haitoshi → `400 "<jina>: zipo N tu"` na **hakuna** kinachobadilika.
- Namba: `shops.find_one_and_update({_id}, {$inc:{receipt_seq:1}}, return_document=AFTER)` → `str(seq).zfill(4)`.
- Punguza stock (atomiki, sehemu 3.3), snapshot `name/product_id/buying`, hesabu `totals`, `date = today(TZ)`.
- `stock_movements` (`reason:"receipt"`), kisha notifications `new_receipt` + `stock_out`/`stock_low`.
- `201` → risiti (muundo wa #19).
- Mistari hii itaonekana yenyewe kwenye **Mauzo ya leo** (`receipt_lines`) na **Nyumbani**.

**21. `GET /receipts/{id}`** → risiti moja.
**22. `POST /receipts/{id}/cancel`** → `status:"cancelled"`, rudisha stock (`reason:"receipt_cancel"`). 200 `{"ok":true}`. Risiti iliyofutwa haihesabiwi kwenye mauzo/ripoti.

**WhatsApp:** app inafungua `https://wa.me/255712445900?text=<risiti>` — moja kwa moja kwenye namba ya mteja. PDF inatengenezwa kwenye simu ("Pakua PDF").

### 6.7 Ripoti

Muundo wa jibu (wote watatu):
```json
{
  "period": "week",
  "label": "16 Nov – 22 Nov 2026",
  "anchor": "2026-11-17",
  "has_next": false,
  "summary": { "sales": 2334000, "capital": 1686000, "expenses": 25000, "product_profit": 648000, "net": 623000 },
  "rows": [
    { "key": "2026-11-16", "label": "Jumatatu", "sub": "16 Nov", "short": "Jtt", "best_label": "Jumatatu 16",
      "sales": 260000, "capital": 190000, "expenses": 2000, "net": 68000, "current": false },
    { "key": "2026-11-17", "label": "Jumanne", "sub": "17 Nov", "short": "Jne", "best_label": "Jumanne 17",
      "sales": 364000, "capital": 265000, "expenses": 3000, "net": 96000, "current": true }
  ],
  "top":    [ { "name": "Viatu vya kufunga", "qty": 14, "profit": 140000 } ],
  "low":    [ { "name": "Kofia ya bao", "qty": 1, "profit": 4000 } ],
  "unsold": [ { "name": "Baibui la Oman", "qty": 3 } ],
  "capital_in_shop": 2234500,
  "purchases": 420000
}
```

**23. `GET /reports/week?date=`** — wiki ya Jumatatu hadi Jumapili yenye `date`.
- `rows`: siku moja moja **hadi leo tu** (siku zijazo hazirudishwi). `short`: `Jtt, Jne, Jtn, Alh, Iju, Jmo, Jpi`.
- `label`: `"16 Nov – 22 Nov 2026"`.

**24. `GET /reports/month?date=`** — mwezi mzima wa `date`.
- `rows`: wiki za mwezi: 1–7, 8–14, 15–21, 22–28, 29–mwisho; `key` = siku ya kwanza ya wiki (`"2026-11-08"`), `label`=`"Wiki 2"`, `sub`=`"8 – 14"` (wiki inayoendelea: `"15 – 17"`), `short`=`"W2"`. Hadi leo tu.
- `label`: `"Novemba 2026"`.

**25. `GET /reports/year?date=`** — Januari hadi mwezi wa sasa (kwa mwaka wa sasa). `key`=`"2026-11"`, `label`=`"Novemba"`, `short`=`"Nov"`, `sub`=`""`. `label` ya ripoti = `"2026"`.

Kwa zote:
- `summary` = jumla ya `rows`.
- `top` = aina 3 zenye **idadi kubwa** zaidi kipindini (qty desc); `profit` = faida yake kipindini.
- `low` = aina 3 zilizouzwa **kidogo** (zisizokuwa kwenye `top`, qty asc).
- `unsold` = aina zenye `qty > 0` ambazo **hazijauzwa kabisa** kipindini (hadi 5, qty desc).
- `capital_in_shop` = `Σ variants qty×buying` (sasa hivi).
- `purchases` = Manunuzi (sehemu 3.4) kipindini.
- `has_next` = kipindi kinachofuata kina siku ≤ leo.
- **Hakuna asilimia / ulinganisho** (app haionyeshi).
- Tumia aggregation (`$match {shop_id, date: {$gte, $lte}}` — string `YYYY-MM-DD` inapangika sawa na tarehe), `$unwind items/lines`, `$group`.

**26. `GET /reports/day/2026-11-15`**
```json
{ "date": "2026-11-15", "label": "Jumapili, 15 Nov",
  "items": [ { "name": "Viatu vya kufunga", "qty": 5, "profit": 50000 } ],
  "summary": { "sales": 510000, "capital": 362000, "expenses": 6000, "product_profit": 148000, "net": 142000 } }
```
`items` = risiti + daily kwa siku hiyo, kwa jina la aina, `profit desc`.

**27. `GET /health`** → `{"ok": true}` (bila auth).

---

## 7. Mfano wa service ya hesabu

```python
async def day_summary(db, sid, d: str) -> dict:
    sales = capital = expenses = 0
    async for r in db.receipts.find({"shop_id": sid, "date": d, "status": "paid"}, {"totals": 1}):
        sales += r["totals"]["paid"]; capital += r["totals"]["capital"]
    sheet = await db.daily_sheets.find_one({"shop_id": sid, "date": d})
    if sheet:
        for l in sheet["lines"]:
            sales += l["qty"] * l["selling"]; capital += l["qty"] * l["buying"]
        expenses = sum(e["amount"] for e in sheet.get("expenses", []))
    return {"sales": sales, "capital": capital, "expenses": expenses,
            "product_profit": sales - capital, "net": sales - capital - expenses}
```
Kwa kipindi kirefu (mwaka) tumia aggregation moja badala ya kuita siku kwa siku.

---

## 8. Muhtasari wa majina ya Kiswahili (kwa `label`)
- Siku: Jumatatu, Jumanne, Jumatano, Alhamisi, Ijumaa, Jumamosi, Jumapili
- Fupi: Jtt, Jne, Jtn, Alh, Iju, Jmo, Jpi
- Miezi: Januari, Februari, Machi, Aprili, Mei, Juni, Julai, Agosti, Septemba, Oktoba, Novemba, Desemba
- Fupi: Jan, Feb, Mac, Apr, Mei, Jun, Jul, Ago, Sep, Okt, Nov, Des

---

## 9. Notifications (Firebase Cloud Messaging)

Setup server: Firebase Console → Project settings → Service accounts → **Generate new private key** → hifadhi kama `firebase-service-account.json`, weka njia kwenye `.env`.
```python
import firebase_admin
from firebase_admin import credentials, messaging
firebase_admin.initialize_app(credentials.Certificate(settings.FIREBASE_CREDENTIALS))

async def send(db, sid, type_, title, body, data=None):
    tokens = [d["fcm_token"] async for d in db.devices.find({"shop_id": sid})]
    if not tokens: return
    msg = messaging.MulticastMessage(tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data={"type": type_, **(data or {})},
        android=messaging.AndroidConfig(priority="high"))
    res = messaging.send_each_for_multicast(msg)
    # ondoa tokens zilizokufa (UNREGISTERED / INVALID_ARGUMENT) kwenye `devices`
```

| # | `type` | Lini | Kichwa / Ujumbe |
|---|---|---|---|
| 1 | `stock_out` | aina ikifika `qty == 0` (baada ya risiti au daily) | "Imeisha" / "Abaya nyeusi imeisha kwenye stock" |
| 2 | `stock_low` | `0 < qty ≤ LOW_STOCK_THRESHOLD` (mara moja kwa siku kwa aina) | "Inakaribia kuisha" / "Kanzu ya Oman: zimebaki 2" |
| 3 | `close_day` | kila siku `CLOSE_DAY_REMINDER` (21:00) kama `daily_sheets` ya leo haina `saved_at` | "Funga hesabu ya leo" / "Andika mauzo ya leo na gharama kisha Hifadhi" |
| 4 | `weekly_report` | Jumapili 21:30 | "Ripoti ya wiki" / "Faida halisi wiki hii: 623,000" |
| 5 | `new_receipt` | risiti mpya (tuma kwa vifaa vingine vya duka tu, si kilichotengeneza — tuma `device` kwenye header `X-Device-Token`) | "Risiti mpya Na. 0005" / "Said Hamad · 142,000" |

`data.type` inatumika na app kufungua skrini husika (stock / mauzo / ripoti / risiti).
Jobs (APScheduler, TZ ya Tanzania):
```python
scheduler.add_job(remind_close_day, CronTrigger(hour=21, minute=0, timezone=TZ))
scheduler.add_job(weekly_report, CronTrigger(day_of_week="sun", hour=21, minute=30, timezone=TZ))
```

---

## 10. Scripts

`python scripts/create_shop.py --name "UMMU AYMAN OUTFITS" --phone "0621 340 044" --email kambilatifah@gmail.com --pin 1234`
→ inatengeneza `shops` (bcrypt PIN, `receipt_seq: 0`).

`python scripts/seed_demo.py` (hiari) → bidhaa za mfano zilizo kwenye `lib/api/mock_api.dart` ya app (Kanzu 4 aina, Abaya 4, Kofia 3, Viatu 3, Hijab 2, Mikoba 2, Udi, Tasbihi).

---

## 11. Majaribio (pytest + httpx.AsyncClient) — lazima yapite

1. PIN sahihi → token; PIN mbaya → `401 "PIN si sahihi"`; mara 6 mfululizo → `429`.
2. `POST /products` (haina aina, Udi 6×15,000/25,000) → aina moja jina "Udi"; jina lile lile tena → `409`.
3. `POST /products` (Kanzu, has_types) + `POST /products/{id}/variants` ×2 → `GET /products` ina aina 2.
4. `PATCH /variants/{id}` `{add_qty:10, selling:70000}` → qty 6→16, selling 70,000; `stock_movements` ina `restock`.
5. `POST /receipts` Alfurqan 2 × 65,000 punguzo 5,000 + Kofia 1 × 22,000 → `paid 142,000`, `discount 10,000`, number `"0001"`, stock imepungua; ijayo `"0002"`.
6. Risiti yenye qty kubwa kuliko stock → `400 "<jina>: zipo N tu"`, stock haibadiliki, `receipt_seq` haibadiliki.
7. `GET /daily/{leo}` → `receipt_lines` zina mistari ya risiti (na `receipt_no`).
8. `PUT /daily/{leo}` Kofia nyeusi 2 → stock 6→4. PUT tena Kofia nyeusi 3 → 6→3 (si 1). PUT bila Kofia → 6.
9. Gharama `{"name":"Bando","amount":1000,"mtandao":"Vodacom"}` → inarudi na `mtandao` palepale; `summary.expenses` sahihi; `net = sales − capital − expenses`.
10. `GET /home` → `products[].variants[].sold_today` = risiti + daily; `summary` = sawa na `/daily`.
11. `POST /receipts/{id}/cancel` → stock imerudi; risiti haipo kwenye `GET /receipts` wala ripoti.
12. `GET /reports/week` → `rows` hadi leo tu; `summary` = jumla ya rows; `best` inapatikana.
13. `GET /reports/month` → wiki 1–7, 8–14 …; `GET /reports/year` Novemba → rows 11 (hakuna Desemba).
14. `GET /reports/day/{d}` → `items` + `summary` sawa na mstari wa siku hiyo kwenye ripoti ya wiki.
15. `DELETE /variants/{id}` aina ya mwisho → bidhaa imefutwa.
16. Stock haiwezi kuwa hasi kwenye njia yoyote.

---

## 12. Kuunganisha na app

`lib/config.dart`:
```dart
const bool kUseMock = false;                      // tumia API halisi
const String kBaseUrl = 'http://192.168.1.20:8000';  // IP ya PC yenye FastAPI (wifi moja na simu)
const bool kUseFirebase = true;                   // baada ya kuweka google-services.json
```
Android emulator: `http://10.0.2.2:8000`. Server ya mtandaoni: `https://api.domain-yako.co.tz` (tumia HTTPS).
