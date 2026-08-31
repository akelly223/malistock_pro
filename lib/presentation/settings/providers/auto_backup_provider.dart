import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Indique si la tentative de sauvegarde automatique a déjà été
/// faite pendant cette session (réinitialisé à chaque relance de
/// l'application, comme pour les alertes de stock).
final autoBackupAttemptedProvider = StateProvider<bool>((ref) => false);
