// Task 9: mortgage create/edit sheet (§13.1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../data/mortgage/mortgage_model.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_money_field.dart';
import '../../ui/components/velora_sheet.dart';
import 'mortgage_controller.dart';

/// Percent string ("18.5") -> integer basis points (1850), no float on the
/// value path — splits on `.` exactly like Money.tryParse, two fraction digits.
int? parseRateToBp(String text) {
  final cleaned = text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final parts = cleaned.split('.');
  if (parts.length > 2) return null;
  final major = parts[0].isEmpty ? '0' : parts[0];
  if (!RegExp(r'^\d+$').hasMatch(major)) return null;
  var bp = int.parse(major) * 100;
  if (parts.length == 2 && parts[1].isNotEmpty) {
    if (!RegExp(r'^\d+$').hasMatch(parts[1])) return null;
    final frac = parts[1].padRight(2, '0').substring(0, 2);
    bp += int.parse(frac);
  }
  return bp;
}

Future<void> showMortgageEditSheet(BuildContext context, WidgetRef ref,
    {Mortgage? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MortgageEditSheet(existing: existing),
  );
}

class _MortgageEditSheet extends ConsumerStatefulWidget {
  final Mortgage? existing;
  const _MortgageEditSheet({this.existing});
  @override
  ConsumerState<_MortgageEditSheet> createState() => _MortgageEditSheetState();
}

class _MortgageEditSheetState extends ConsumerState<_MortgageEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _initial;
  late final TextEditingController _opening;
  late final TextEditingController _rate;
  late final TextEditingController _mandatory;
  PaymentType _type = PaymentType.annuity;
  PayoffStrategy _strategy = PayoffStrategy.unclear;
  late DateTime _nextPayment;
  String? _error;

  static const _uzs = CurrencyRegistry.uzs;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    Money m(int v) => Money(v, _uzs);
    _name = TextEditingController(text: e?.name ?? '');
    _initial = TextEditingController(
        text: e == null ? '' : m(e.initialLoanMinor).formatNumber());
    _opening = TextEditingController(
        text: e == null ? '' : m(e.openingPrincipalMinor).formatNumber());
    _rate = TextEditingController(
        text: e == null
            ? ''
            : '${e.annualRateBp ~/ 100}.${(e.annualRateBp % 100).toString().padLeft(2, '0')}');
    _mandatory = TextEditingController(
        text: e == null ? '' : m(e.mandatoryPaymentMinor).formatNumber());
    _type = e?.paymentType ?? PaymentType.annuity;
    _strategy = e?.payoffStrategy ?? PayoffStrategy.unclear;
    _nextPayment = e?.nextPaymentDate ?? DateTime.now();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextPayment,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextPayment = picked);
  }

  @override
  void dispose() {
    for (final c in [_name, _initial, _opening, _rate, _mandatory]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final initial = Money.tryParse(_initial.text, _uzs);
    final opening = Money.tryParse(_opening.text, _uzs);
    final mandatory = Money.tryParse(_mandatory.text, _uzs);
    final rateText = _rate.text.trim();
    final bp = rateText.isEmpty ? 0 : parseRateToBp(rateText); // int?
    if (_name.text.trim().isEmpty ||
        initial == null ||
        opening == null ||
        mandatory == null ||
        (rateText.isNotEmpty && bp == null)) {
      setState(() => _error = 'Maydonlarni to\'ldiring');
      return;
    }
    final e = widget.existing;
    final draft = MortgageDraft(
      name: _name.text.trim(),
      bank: e?.bank ?? '',
      initialLoanMinor: initial.minorUnits,
      openingPrincipalMinor: opening.minorUnits,
      annualRateBp: bp ?? 0,
      startDate: e?.startDate ?? DateTime.now(),
      endDate: e?.endDate,
      mandatoryPaymentMinor: mandatory.minorUnits,
      nextPaymentDate: _nextPayment,
      paymentType: _type,
      payoffStrategy: _strategy,
      currencyCode: e?.currencyCode ?? 'UZS',
    );
    final ctrl = ref.read(mortgageControllerProvider);
    final res = e == null
        ? await ctrl.create(draft)
        : await ctrl.update(e.id, draft);
    if (!mounted) return;
    if (!res.isOk) {
      setState(() => _error = 'Saqlashda xatolik');
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VeloraSheetScaffold(
      title: widget.existing == null ? 'Yangi ipoteka' : 'Ipotekani tahrirlash',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('Kredit ma\'lumotlari'),
          const SizedBox(height: VeloraSpacing.sm),
          TextField(
              key: const Key('mortgage-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nomi')),
          const SizedBox(height: VeloraSpacing.md),
          VeloraMoneyField(
              key: const Key('mortgage-initial'),
              controller: _initial,
              currency: _uzs,
              label: 'Boshlang\'ich summa'),
          const SizedBox(height: VeloraSpacing.md),
          VeloraMoneyField(
              key: const Key('mortgage-opening'),
              controller: _opening,
              currency: _uzs,
              label: 'Joriy qarz qoldig\'i'),
          const SizedBox(height: VeloraSpacing.md),
          TextField(
              key: const Key('mortgage-rate'),
              controller: _rate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Yillik foiz (%)')),
          const SizedBox(height: VeloraSpacing.lg),
          const _SectionLabel('To\'lov rejasi'),
          const SizedBox(height: VeloraSpacing.sm),
          VeloraMoneyField(
              key: const Key('mortgage-mandatory'),
              controller: _mandatory,
              currency: _uzs,
              label: 'Majburiy oylik to\'lov'),
          const SizedBox(height: VeloraSpacing.md),
          DropdownButtonFormField<PaymentType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'To\'lov turi'),
            items: const [
              DropdownMenuItem(
                  value: PaymentType.annuity, child: Text('Annuitet')),
              DropdownMenuItem(
                  value: PaymentType.custom, child: Text('Individual')),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: VeloraSpacing.md),
          InkWell(
            key: const Key('mortgage-date'),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Keyingi to\'lov sanasi',
                suffixIcon: Icon(Icons.event_outlined),
              ),
              child: Text(_nextPayment.toString().split(' ').first),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: VeloraSpacing.sm),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      primaryAction: VeloraPrimaryButton(
        key: const Key('mortgage-save'),
        label: 'Saqlash',
        onPressed: _save,
      ),
    );
  }
}

/// A muted group heading used to break the form into "loan data" and "payment
/// plan" sections (§6.9's two-step setup, presented as one scrollable sheet).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: VeloraColors.muted),
    );
  }
}
