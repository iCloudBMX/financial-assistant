import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/result/failure_messages.dart';
import 'data/db/db_open.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'financial_assistant.db');

  final result = await openAppDatabase(dbPath: dbPath);
  result.when(
    ok: (db) => runApp(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const App(),
      ),
    ),
    err: (failure) => runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(userMessage(failure), textAlign: TextAlign.center),
          ),
        ),
      ),
    )),
  );
}
