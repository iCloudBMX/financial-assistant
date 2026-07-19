import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../core/result/failure.dart';
import '../../core/result/result.dart';
import '../../data/mortgage/mortgage_model.dart';
import '../../data/mortgage/mortgage_repository.dart';
import '../../providers/app_providers.dart';

class MortgageController {
  final Ref ref;
  MortgageController(this.ref);

  MortgageRepository get _repo => ref.read(mortgageRepositoryProvider);

  void _bump() =>
      ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

  Future<Result<int>> create(MortgageDraft draft) async {
    final v = _validateDraft(draft);
    if (v != null) return Err(v);
    final id = await _repo.create(draft);
    _bump();
    return Ok(id);
  }

  Future<Result<void>> update(int id, MortgageDraft draft) async {
    final v = _validateDraft(draft);
    if (v != null) return Err(v);
    await _repo.update(id, draft);
    _bump();
    return const Ok(null);
  }

  ValidationFailure? _validateDraft(MortgageDraft d) {
    if (d.name.trim().isEmpty) return const ValidationFailure('name required');
    if (d.initialLoanMinor <= 0) return const ValidationFailure('initial loan must be > 0');
    if (d.openingPrincipalMinor <= 0) return const ValidationFailure('opening principal must be > 0');
    if (d.annualRateBp < 0) return const ValidationFailure('rate cannot be negative');
    if (d.mandatoryPaymentMinor <= 0) return const ValidationFailure('mandatory payment must be > 0');
    return null;
  }

  Future<Result<void>> recordPayment({
    required int mortgageId,
    required MortgagePaymentSplit split,
    required int accountId,
    String? note,
    DateTime? occurredAt,
  }) async {
    final v = _validateSplit(split);
    if (v != null) return Err(v);
    await _repo.recordPayment(
      mortgageId: mortgageId,
      split: split,
      accountId: accountId,
      note: note,
      occurredAt: occurredAt,
    );
    await _advanceDueDate(mortgageId);
    await _closeIfPaidOff(mortgageId);
    _bump();
    return const Ok(null);
  }

  Future<Result<void>> recordExtraPayment({
    required int mortgageId,
    required Money amount,
    required int accountId,
    String? note,
    DateTime? occurredAt,
  }) async {
    if (amount.minorUnits <= 0) {
      return const Err(ValidationFailure('extra payment must be > 0'));
    }
    await _repo.recordPayment(
      mortgageId: mortgageId,
      split: MortgagePaymentSplit(
          totalMinor: amount.minorUnits, principalMinor: amount.minorUnits),
      accountId: accountId,
      isExtra: true,
      note: note,
      occurredAt: occurredAt,
    );
    await _closeIfPaidOff(mortgageId);
    _bump();
    return const Ok(null);
  }

  Future<void> closeMortgage(int id) async {
    await _repo.setStatus(id, MortgageStatus.closed);
    _bump();
  }

  ValidationFailure? _validateSplit(MortgagePaymentSplit s) {
    if (s.totalMinor <= 0) return const ValidationFailure('total must be > 0');
    if (s.principalMinor < 0 ||
        s.interestMinor < 0 ||
        s.commissionMinor < 0 ||
        s.insuranceMinor < 0 ||
        s.otherMinor < 0) {
      return const ValidationFailure('payment parts cannot be negative');
    }
    if (!s.isBalanced) {
      return const ValidationFailure('the parts must add up to the total');
    }
    return null;
  }

  Future<void> _advanceDueDate(int mortgageId) async {
    final m = await _repo.byId(mortgageId);
    if (m == null) return;
    await _repo.setNextPaymentDate(
        mortgageId, addMonths(m.nextPaymentDate, 1));
  }

  Future<void> _closeIfPaidOff(int mortgageId) async {
    if (await _repo.currentPrincipalMinor(mortgageId) <= 0) {
      await _repo.setStatus(mortgageId, MortgageStatus.closed);
    }
  }
}

final mortgageControllerProvider =
    Provider<MortgageController>((ref) => MortgageController(ref));
