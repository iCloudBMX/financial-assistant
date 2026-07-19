sealed class Failure {
  final String debugDetail;
  const Failure(this.debugDetail);
}

/// A filesystem or artifact operation outside the live database failed.
///
/// Use for backup, import, export, snapshot, or restore-file I/O. Live
/// repository/database operations use [PersistenceFailure] instead.
class StorageFailure extends Failure {
  const StorageFailure(super.debugDetail);
}

/// Opening, migrating, or recovering the application database failed.
class MigrationFailure extends Failure {
  const MigrationFailure(super.debugDetail);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.debugDetail);
}

/// A live repository/database read, write, or transaction could not complete.
///
/// This means an in-app change was not persisted. Artifact/file I/O outside
/// the database uses [StorageFailure], while open/schema/recovery failures use
/// [MigrationFailure].
class PersistenceFailure extends Failure {
  const PersistenceFailure(super.debugDetail);
}

/// Values in incompatible currencies reached an operation without conversion.
///
/// Low-level `Money` arithmetic still throws its invariant error; Result-based
/// intent and repository boundaries translate known currency conflicts here.
class CurrencyFailure extends Failure {
  const CurrencyFailure(super.debugDetail);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.debugDetail);
}

class BackupIncompatibleFailure extends Failure {
  const BackupIncompatibleFailure(super.debugDetail);
}
