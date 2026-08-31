import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';

/// Widget invisible qui affiche un message visible chaque fois qu'une
/// navigation directe (URL, lien interne) vers une route interdite au
/// rôle de l'utilisateur a été bloquée par le routeur — sans ça, le
/// refus est silencieux (l'utilisateur atterrit sur le tableau de bord
/// sans comprendre pourquoi).
class AccessDeniedTrigger extends ConsumerWidget {
  const AccessDeniedTrigger({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(accessDeniedRouteProvider, (previous, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous ne disposez pas des autorisations nécessaires.'),
        ),
      );
      ref.read(accessDeniedRouteProvider.notifier).state = null;
    });
    return const SizedBox.shrink();
  }
}
