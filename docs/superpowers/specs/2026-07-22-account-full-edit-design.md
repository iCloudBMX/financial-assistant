# Kartalarni to'liq tahrirlash — dizayn

**Sana:** 2026-07-22
**Holat:** Tasdiqlangan, amalga oshirishga tayyor

## Muammo

Kartalar (Hisoblar) sahifasida hisob yaratilgandan keyin kartaga bosilganda
faqat **balansni** tuzatish oynasi ochiladi (`showBalanceAdjustSheet`). Nom,
tur va byudjet rolini o'zgartirishning yo'li yo'q. Foydalanuvchi to'liq
tahrirlash imkoniyatini so'ramoqda.

## Yechim (qisqacha)

Kartaga bosilganda **to'liq tahrirlash** oynasi ochiladi — nom, tur, byudjet
roli va balans bir joyda. Mavjud yaratish oynasi (`account_edit_sheet.dart`)
allaqachon shu maydonlarga ega, shuning uchun uni yangi sheet yozish o'rniga
ikki rejimli (yaratish / tahrirlash) qilib kengaytiramiz. Endi keraksiz bo'lib
qoladigan `balance_adjust_sheet.dart` o'chiriladi.

## Tafsilotlar

### 1. Sheet — ikki rejim (`lib/features/accounts/account_edit_sheet.dart`)

Kirish nuqtasi parametrlanadi:

```dart
Future<void> showAccountEditSheet(
  BuildContext context,
  WidgetRef ref, {
  int? accountId,          // null → yaratish, aks holda → tahrirlash
});
```

- **Yaratish rejimi** (`accountId == null`) — hozirgidek: sarlavha
  "Yangi hisob", Saqlash → `createAccount`. Xatti-harakat o'zgarmaydi.
- **Tahrirlash rejimi** (`accountId != null`):
  - Sarlavha: "Hisobni tahrirlash".
  - Maydonlar boshlang'ich qiymatlar bilan to'ldiriladi:
    - Nomi = `account.name`
    - Turi = `account.type` (tanlangan chip)
    - Byudjet roli = `account.role` (tanlangan chip)
    - Balans = **joriy haqiqiy balans** (`AccountWithBalance.balance`),
      ochilish balansi emas.
  - Saqlash tugmasi: "Saqlash".
  - Sheet uchun kerakli ma'lumot (`Account` + joriy balans) ochilishdan oldin
    o'qiladi — `showBalanceAdjustSheet` dagi kabi `settingsProvider` /
    repozitoriy orqali. Joriy balansni `accountsControllerProvider` dagi
    `AccountWithBalance` ro'yxatidan olamiz.

Saqlashda **faqat o'zgargan** maydonlar yoziladi (keraksiz DB yozuvi va soxta
"Balans tuzatish" yozuvidan qochish uchun). Bir maydon ham o'zgarmagan bo'lsa,
hech narsa yozilmaydi va oyna yopiladi.

### 2. Balans semantikasi

Balans maydoni joriy haqiqiy balans bilan to'ldiriladi. Foydalanuvchi uni
o'zgartirsa **va** yangi qiymat joriysidan farq qilsa — ledger'ga "Balans
tuzatish" yozuvi qo'shiladi (mavjud `adjustBalance` orqali). Tegilmasa yoki
qiymat o'zgarmasa — yozuv qo'shilmaydi. Bu tarixni buzmaydi (ochilish balansi
bevosita qayta yozilmaydi).

### 3. Kartaga bosish (`lib/features/accounts/accounts_screen.dart`)

`_AccountCard.onTap` endi:

```dart
onTap: () => showAccountEditSheet(context, ref, accountId: it.account.id),
```

`showBalanceAdjustSheet` chaqiruvi olib tashlanadi (u yagona ishlatilgan joy
edi). Arxivlash tugmasi o'zgarmaydi.

### 4. Repozitoriy (`lib/data/accounts/account_repository.dart`)

Yangi metod qo'shiladi (turni o'zgartirish uchun — hozir yo'q):

```dart
Future<void> setType(int id, AccountType type);
```

Drift implementatsiyasi `type` ustunini yozadi (nom ustuniga o'xshab, ChoiceChip
qiymati `type.name` sifatida). `rename`, `setRole`, `adjustBalance` allaqachon
mavjud.

### 5. Kontroller (`lib/features/accounts/accounts_controller.dart`)

Diff'ni qo'llovchi bitta metod qo'shiladi:

```dart
Future<void> edit({
  required int id,
  String? name,
  AccountType? type,
  AccountRole? role,
  Money? realBalance,  // faqat balans o'zgarganda beriladi
});
```

Metod berilgan (null bo'lmagan) maydonlarni mos repozitoriy/ledger chaqiruvlari
bilan qo'llaydi va oxirida **bir marta** `_invalidate()` qiladi (har biriga
alohida emas). `realBalance` berilsagina `adjustBalance` chaqiriladi. Sheet
o'zi qaysi maydon o'zgarganini aniqlab, faqat o'shalarni uzatadi.

### 6. Tozalash

`lib/features/accounts/balance_adjust_sheet.dart` o'chiriladi (ishlatilmaydi).
Unga bog'liq testlar va golden galereyadagi yozuvlar shunga mos yangilanadi
yoki olib tashlanadi.

## Testlar

- **Tahrirlash rejimi — to'ldirish:** mavjud hisob uchun sheet ochilganda
  nom/tur/rol/balans joriy qiymatlar bilan ko'rsatiladi.
- **Faqat o'zgargan maydon yoziladi:** faqat nom o'zgartirilsa, `rename`
  chaqiriladi, `setType`/`setRole`/`adjustBalance` chaqirilmaydi.
- **Balans o'zgarganda tuzatish yozuvi:** balans yangi qiymatga o'zgartirilsa,
  ledger'ga "Balans tuzatish" yozuvi qo'shiladi.
- **Balansga tegilmasa yozuv yo'q:** faqat tur/rol o'zgartirilsa, ledger'da
  yangi yozuv paydo bo'lmaydi.
- **Turni o'zgartirish:** `setType` DB'da `type` ustunini yangilaydi.
- **Yaratish rejimi regressiyasi:** `accountId` bermasdan ochilganda avvalgidek
  yangi hisob yaratiladi.

## Ta'sir ko'lami

- `lib/features/accounts/account_edit_sheet.dart` — kengaytiriladi.
- `lib/features/accounts/accounts_screen.dart` — `onTap` o'zgaradi.
- `lib/features/accounts/accounts_controller.dart` — `edit` qo'shiladi.
- `lib/data/accounts/account_repository.dart` — `setType` qo'shiladi.
- `lib/features/accounts/balance_adjust_sheet.dart` — o'chiriladi.
- Testlar/goldenlar — yangilanadi.
- Schema o'zgarishi **yo'q** (barcha ustunlar allaqachon mavjud).
