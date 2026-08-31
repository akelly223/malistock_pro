import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/app_settings.dart';

final appSettingsProvider =
    FutureProvider.autoDispose<AppSettingsEntity>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getSettings();
});
