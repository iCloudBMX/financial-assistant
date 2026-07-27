# Chiqim kiritish oynasini soddalashtirish

**Sana:** 2026-07-27
**Doira:** faqat chiqim (expense) kiritish oynasi. Kirim/mortgage/transfer oynalari o'zgarmaydi.

## Muammo

Foydalanuvchi: bitta chiqim kiritish ko'p vaqt oladi, oyna "qiyinlashib ketgan".
Aniqlangan sabablar (foydalanuvchi bilan):

1. Kategoriya tanlash noto'g'ri strukturalangan — 4 ta katta plitka + alohida qidiruv
   oynasi; kerakli kategoriya ko'pincha ko'rinmaydi.
2. Izoh (note) "Batafsil" ichida yashirin — ochish uchun qo'shimcha teginish.
3. Sana kamdan-kam kerak, lekin joy egallab, e'tiborni tortadi.

## Yechim (tasdiqlangan mockup: variant A — yoyilgan chiplar)

Chiqim oynasi tartibi (yuqoridan pastga):

1. **Sarlavha qatori:** "Chiqim" + o'ng tomonda kichik sana tugmasi ("📅 Bugun ›").
   Bosilganda `showDatePicker`. Default = bugun; odatda tegilmaydi.
2. **Summa** — o'zgarishsiz (katta, avtofokus, klaviatura darrov).
3. **Kategoriya** — yoyilgan chiplar (wrap, 2 qator). Eng ko'p/oxirgi ishlatilgan
   ~6 kategoriya + oxirida "Barchasi" chipi. Surish yo'q — hech biri yashirin emas.
   "Barchasi" mavjud to'liq ro'yxat oynasini (qidiruv + Majburiy/O'zgaruvchan) ochadi.
   Birinchi (eng oxirgi ishlatilgan) kategoriya oldindan tanlangan.
4. **Hisob** — ixcham chip qatori (nom + balans), tanlangani ajralib turadi.
   Chiqim oynasiga xos yangi kichik widget; umumiy `AccountCardPicker` karuseliga
   TEGILMAYDI (u kirim/mortgage/transferda ishlatiladi).
5. **Izoh** — doim ochiq matn maydoni (ixtiyoriy). "Batafsil" yo'q.
6. **Rejalashtirilgan xarajat** — past-urg'uli inline toggle (funksiya saqlanadi).
7. **Saqlash** — coral CTA, pastda mahkamlangan.

## O'zgaradigan/qo'shiladigan fayllar

- `lib/features/expense_entry/expense_entry_sheet.dart` — qayta tartib; `EntryDetailsSection`
  o'rniga inline izoh + planned toggle; sarlavhaga sana tugmasi; hisob chip qatori.
- `lib/ui/components/category_picker.dart` — 4 plitka o'rniga yoyilgan chiplar + "Barchasi"
  chipi. To'liq ro'yxat oynasi (`_CategorySheet`) saqlanadi.
- `lib/ui/components/velora_sheet.dart` — `VeloraSheetScaffold`ga ixtiyoriy `titleTrailing`
  parametri (default null; kirim oynasiga ta'sir yo'q).
- Yangi: chiqimga xos hisob chip qatori (kichik widget, `expense_entry_sheet.dart` ichida
  yoki alohida fayl).

## TEGILMAYDIGAN (umumiy komponentlar)

- `EntryDetailsSection` — kirim oynasi ishlatadi, o'zgarmaydi.
- `AccountCardPicker` — kirim/mortgage/transfer ishlatadi, o'zgarmaydi.
- `expense_entry_controller.dart` mantiqi (quick-pick tartibi, save) — o'zgarmaydi.

## Testlar

- `test/ui/components/category_picker_test.dart` — yangi chip strukturasiga moslash.
- Chiqim oynasi widget testlari — 'expense-note-field' endi doim ko'rinadi (Batafsil
  bosish shart emas); planned toggle key saqlanadi.
- Goldenlar (chiqim oynasi + foundation) qayta baza (re-baseline) talab qiladi.

## Chegaralar / kelajakka qoldirilgan

- Kirim oynasi ham xuddi shu chip ko'rinishiga o'tishi mumkin — hozir emas (doira faqat chiqim).
  Vaqtincha kirim (karusel) va chiqim (chiplar) ko'rinishi farq qiladi.
