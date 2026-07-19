sealed class Failure {
  final String debugDetail;
  const Failure(this.debugDetail);
}

class StorageFailure extends Failure {
  const StorageFailure(super.debugDetail);
}

class MigrationFailure extends Failure {
  const MigrationFailure(super.debugDetail);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.debugDetail);
}

/// A local repository or database operation could not be completed.
class PersistenceFailure extends Failure {
  const PersistenceFailure(super.debugDetail);
}

/// Values in incompatible currencies reached an operation without conversion.
class CurrencyFailure extends Failure {
  const CurrencyFailure(super.debugDetail);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.debugDetail);
}

class BackupIncompatibleFailure extends Failure {
  const BackupIncompatibleFailure(super.debugDetail);
}
