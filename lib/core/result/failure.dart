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

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.debugDetail);
}

class BackupIncompatibleFailure extends Failure {
  const BackupIncompatibleFailure(super.debugDetail);
}
