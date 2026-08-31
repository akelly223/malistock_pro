import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/backup_service.dart';

/// Liste des sauvegardes déjà créées, les plus récentes en premier.
final backupListProvider = FutureProvider.autoDispose<List<File>>((ref) async {
  return BackupService.listerSauvegardes();
});
