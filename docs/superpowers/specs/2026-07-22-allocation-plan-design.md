# Taqsimlash rejasi (Allocation Plan) — Design

**Sana:** 2026-07-22
**Holat:** Approved (brainstorming) — implementation plan kutilmoqda
**Bog'liq:** [Budget model redesign](2026-07-21-account-role-budgeting-design.md) (Model A: kunlik limit Sarf-roli karta balanslaridan)

## 1. Muammo va maqsad

Model A da kunlik sarf limiti faqat **Sarf-roli kartalar** balansini o'qiydi
(`safeLimitProvider`); Zaxira / Kredit / Jamg'arma kartalar rol bo'yicha
poolga kirmaydi. Demak pulni himoya qilish (favqulodda zaxira, kredit
to'lovi, maqsad) uchun uni Sarf kartadan boshqa roldagi kartaga **ko'chirish**
kerak — shunda Sarf balansi (va kunlik limit) faqat sarflashga ochiq pulni
ko'rsatadi.

Hozirgi taqsimlash tizimi pulni abstrakt **buketlarga** (`majburiy xarajat`,
`erkin budjet`, `maqsad`, `ipoteka`) yozadi — bu faqat `incomeAllocationsTable`
dagi hisobot yozuvi; kartalar o'rtasida pul **ko'chirmaydi** va Model A da
kunlik limitga umuman ta'sir qilmaydi. Ya'ni bu tizim maqsadga xizmat
qilmaydi.

**Maqsad:** foydalanuvchi oldindan **tayyor turadigan** taqsimlash rejasini
(karta-ga-karta o'tkazmalar to'plami) tuzadi va **kerakli paytda o'zi buyruq
berib** ishga tushiradi. Reja real transfer'lar orqali pulni Sarf kartadan
belgilangan kartalarga ko'chiradi.

### Nima uchun avtomatik emas

Kirim har doim ham avtomat tushmaydi (naqd, qo'lda kiritilgan va h.k.). Shuning
uchun taqsimlash kirim hodisasiga bog'lanmaydi — provodkalar tayyor turadi,
foydalanuvchi qulay paytda "Qo'llash" bosadi.

## 2. Talablar (qaror qilingan)

1. **Qo'lda, buyruq bilan** — avtomatik emas; reja saqlanadi, foydalanuvchi
   ishga tushiradi.
2. **Bitta tugma → hammasi** — barcha qatorlar bir vaqtda, ustuvorlik (tartib)
   bo'yicha bajariladi.
3. Reja = bitta **belgilangan manba karta** (odatda asosiy Sarf) + tartiblangan
   qatorlar: `(manzil karta, belgilangan summa)`.
4. Summa turi: **faqat belgilangan summa** (foiz yo'q, qoldiq yo'q).
5. Hovuz = manba kartaning **joriy balansi**; qatorlar tartib bo'yicha
   to'ldiriladi, pul tugaguncha. Oxirgi to'ldiriladigan qator qisman olishi
   mumkin; qolganlari 0 oladi (kamomad).
6. Bajarishdan oldin **qisqa tasdiq** ko'rsatiladi (har manzil +summa, manbada
   qancha qolishi, kamomad ogohlantirishi). Tasdiqdan keyin bajariladi.
7. Bajarish = real **karta-ga-karta o'tkazma** (mavjud transfer ledger
   mexanizmi) — kirim/chiqim sifatida hisoblanmaydi.
8. Eski abstrakt-buket taqsimlash tizimi **to'liq olib tashlanadi**.
9. Maqsadlar (goals) o'z mustaqil "Mablag' qo'shish / Yechish" yo'lini saqlaydi
   (`ContributionSource.manual`) — o'zgarmaydi. "Kirimdan avtomatik goal
   to'ldirish" yo'qoladi (Model A redirect'ining tabiiy natijasi).

### Ko'lamdan tashqari (out of scope)

- Jamg'arma kartani maqsadga bog'lab, o'tkazma goal progress'ini avtomatik
  yangilashi (kelajakdagi ish; hozir goal progress alohida `goalContributions`
  orqali).
- Foiz/qoldiq usullari, bir nechta reja, jadval bo'yicha avtomatik ishga
  tushirish.

## 3. Domen modeli

`core/allocation/` (eski buket modeli o'rniga):

- `AllocationRule` — `destinationAccountId` (int), `amountMinor` (int),
  `sortOrder` (int).
- `AllocationPlan` — `sourceAccountId` (int?), `rules` (`List<AllocationRule>`,
  `sortOrder` bo'yicha).
- `PlannedTransfer` — `destinationAccountId` (int), `amount` (Money) — hisoblangan
  natija.
- `Shortfall` — `destinationAccountId`, `requested`, `funded` (`shortBy` =
  requested − funded).
- `PlanApplyResult` — `transfers` (`List<PlannedTransfer>`), `totalMoved`
  (Money), `sourceRemaining` (Money), `shortfalls` (`List<Shortfall>`).

## 4. Sof engine

`core/allocation/allocation_engine.dart` — hech qanday I/O yo'q, to'liq unit
testlanadigan:

```dart
PlanApplyResult computePlanTransfers({
  required Money sourceBalance,
  required List<AllocationRule> rules, // sortOrder bo'yicha tartiblangan
});
```

**Mantiq:**

```
remaining = sourceBalance
har rule uchun (tartib bo'yicha):
  funded = min(rule.amount, max(0, remaining))
  agar funded < rule.amount: shortfalls += Shortfall(dest, requested, funded)
  agar funded > 0:
    transfers += PlannedTransfer(dest, funded)
    remaining -= funded
totalMoved   = Σ funded
sourceRemaining = remaining
```

- `funded == 0` bo'lgan qatorlar `transfers`ga qo'shilmaydi (nol o'tkazma yo'q),
  lekin shortfall sifatida qayd etiladi.
- Manba balansi 0 yoki manfiy bo'lsa — hech qanday transfer, hammasi shortfall.
- Bo'sh reja → bo'sh natija.

## 5. Ma'lumotlar (DB, schema v6 → v7)

**Qo'shiladi:**

- `AllocationPlanRulesTable`:
  - `id` — autoincrement PK
  - `destinationAccountId` — int (accounts FK)
  - `amountMinor` — int
  - `sortOrder` — int
- `AppSettingsTable.allocationSourceAccountId` — nullable int (butun reja uchun
  bitta manba karta). Mos ravishda `AppSettings` modeliga
  `allocationSourceAccountId` (int?) qo'shiladi + `copyWith`.

**Olib tashlanadi:**

- `AllocationDirectionsTable` (buket shabloni)
- `IncomeAllocationsTable` (buket hisoboti)
- `TransactionsTable.allocatedMinor` ustuni

**Migratsiya (v7):** yangi jadval va settings ustunini yaratish; eski ikki
jadval va `allocatedMinor` ustunini tashlash. SQLite ustun tashlash uchun
drift'ning jadval-qayta-yaratish yordamchisi ishlatiladi (mavjud
`migrations.dart` uslubiga mos). Migratsiya recovery testi
(`migration_recovery_test.dart`) yangilanadi.

## 6. Repository va providerlar

- `AllocationPlanRepository` (abstract + Drift impl):
  - `Future<AllocationPlan> plan()` — manba (settings'dan) + qatorlar.
  - `Future<void> saveRules(List<AllocationRule> rules)` — qatorlarni almashtirib
    yozadi (mavjud `saveTemplate` uslubidagi delete+insert, `sortOrder` =
    indeks).
  - `Future<void> setSource(int? accountId)` — settings orqali.
  - `Future<Result<void>> applyPlan(int sourceId, List<PlannedTransfer> transfers)`
    — **bitta `db.transaction`da** barcha o'tkazmalarni yozadi. Har o'tkazma
    mavjud ledger transfer shakli bilan (`transferOut`/`transferIn` juftligi,
    umumiy `transferId`). Bittasi xato → hammasi rollback (qisman holat yo'q).
- `allocationPlanProvider` (FutureProvider) — rejani o'qiydi;
  `ledgerRevisionProvider`ni kuzatadi.
- `applyPlan` muvaffaqiyatidan keyin `ledgerRevisionProvider` inkrement →
  `safeLimitProvider` va balanslar avtomatik qayta hisoblanadi.

## 7. UI

### "Taqsimlash rejasi" ekrani

Mavjud `features/allocation/allocation_template_screen.dart` qayta yoziladi.
Reja (Budjet) sarlavhasidagi `Icons.tune` ("Taqsimlash rejasi") havolasidan
ochiladi — bu ulanish allaqachon mavjud.

Tarkibi:

- Yuqorida **manba karta tanlagichi** (`AccountCardPicker`) — tanlangan manba
  Sarf bo'lishi shart emas, lekin odatda shu. O'zgarganda `setSource`.
- **Qatorlar ro'yxati** — har biri: manzil karta ikonasi + nomi + summa;
  tahrirlash (tap), o'chirish, sudrab tartiblash (`ReorderableListView`,
  mavjud uslub).
- **"Yangi qator"** tugmasi → kichik sheet: manzil karta tanlash
  (`AccountCardPicker`, manba bundan mustasno) + summa (`VeloraMoneyField`).
- Pastda **"Rejani qo'llash"** — coral primary (mavjud `_CoralPrimaryAction`
  uslubi). Manba tanlanmagan yoki qator yo'q bo'lsa o'chiq.

### Qo'llash oqimi

1. "Rejani qo'llash" bosiladi.
2. Joriy manba balansi + qatorlar → `computePlanTransfers`.
3. **Tasdiq sheet** ko'rsatiladi:
   - Har manzil: nom + `+summa`
   - "Manba (Sarf)'da qoladi: `sourceRemaining`"
   - Kamomad bo'lsa: ogohlantirish (qaysi qatorlar to'liq to'lanmadi), rang +
     ikona + matn (faqat rang emas — mavjud status qoidasi).
   - Tugmalar: "Bajarish" (coral) / "Bekor".
4. Tasdiqdan keyin `applyPlan` → natija snackbar
   (`totalMoved` ko'chirildi / kamomad haqida qisqa xabar).

### Chekka holatlar

- Manba tanlanmagan → "Qo'llash" o'chiq + yo'l-yo'riq matni.
- Manzil == manba → qator qo'shishda taqiqlanadi.
- Qator o'chirilgan/mavjud bo'lmagan kartaga ishora qilsa → ogohlantirilib,
  bajarishda o'tkazib yuboriladi (rollback emas).
- Manba balansi qatorlarni qoplamasa → kamomad; qisman bajariladi (talab 5).
- Valyuta: mavjud pattern — birlamchi valyuta qabul qilinadi (multi-currency
  ko'lamdan tashqari).

### Kirim oqimi o'zgarishi

`features/income_entry/income_entry_sheet.dart` da kirim saqlangach
`showAllocationChoice` **chaqiruvi olib tashlanadi** — kirim shunchaki
saqlanadi. Taqsimlash mustaqil "Qo'llash" orqali.

## 8. Olib tashlanadigan eski kod

O'chiriladi (va ularning testlari):

- `core/allocation/allocation_engine.dart` (eski buket engine — yangi bilan
  almashtiriladi), `allocation_models.dart` (eski buket modellari),
  `allocation_dynamic.dart` (goalBased resolve).
- `features/allocation/allocate_sheet.dart`,
  `features/allocation/income_allocation_prompt.dart`,
  `features/allocation/variable_budget_offer.dart`.
- Eski `features/allocation/allocation_controller.dart`,
  `data/allocation/allocation_repository.dart` (yangi bilan almashtiriladi).
- `data/db/default_allocation.dart` (buket seed) — yangi reja uchun seed
  kerak emas (bo'sh boshlaydi) yoki neytral bo'sh seed.
- Buket / natija label'lari (`allocation_result_labels.dart`, `bucketLabel`).
- DB: `AllocationDirectionsTable`, `IncomeAllocationsTable`,
  `TransactionsTable.allocatedMinor`.

**Saqlanadi:** Maqsadlar (goals) to'liq o'z holicha — mustaqil manual
contribute/withdraw. `ContributionSource.incomeAllocation` enum qiymati
mavjud tarix yozuvlari uchun qoladi; yangi kod faqat `manual` yozadi.

## 9. Test rejasi

- **Engine (unit):** aniq to'ldirish; kamomad (qisman oxirgi qator + keyingi
  qatorlar 0); bo'sh reja; manba balansi 0/manfiy; bitta qator; ko'p qator
  tartibi.
- **Repository:** `applyPlan` atomikligi (bir o'tkazma xato → butun rollback);
  balanslar to'g'ri o'zgarishi (manba −Σ, manzillar +); transfer kirim/chiqim
  emasligini tasdiqlash.
- **Widget/golden:** reja ekrani (manba + qatorlar + bo'sh holat); yangi-qator
  sheet; tasdiq sheet (oddiy + kamomad).
- **Integratsiya:** reja qo'llash → Sarf balansi kamayadi → `safeLimitProvider`
  kunlik limiti yangilanadi.
- **Migratsiya:** v6 → v7 recovery testi yangilanadi.

## 10. Arxitektura chegaralari

- **Sof hisob** (`computePlanTransfers`) I/O'dan ajratilgan — oson testlanadi,
  AI-navigatsiyaga qulay (loyiha yondashuviga mos).
- **Widgetlar qiymat iste'mol qiladi**, providerlarni emas — reja ekrani
  `AllocationPlan` / `PlanApplyResult` qiymatlarini oladi (mavjud Velora
  presentation-architecture chegarasi).
- **Atomik bajarish** repository qatlamida bitta tranzaksiyada.
