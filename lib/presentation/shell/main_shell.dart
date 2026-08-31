import 'package:flutter/material.dart';
import 'sidebar_menu.dart';
import 'notification_bell.dart';
import 'startup_alert_trigger.dart';
import 'auto_backup_trigger.dart';
import 'startup_draft_checker.dart';
import 'access_denied_trigger.dart';

/// Layout principal de l'application une fois connecté : sidebar fixe
/// à gauche + zone de contenu scrollable à droite. Reçoit le contenu
/// de la page courante via GoRouter (ShellRoute).
///
/// Une cloche de notification flotte en haut à droite sur toutes les
/// pages, un déclencheur invisible affiche une popup d'alerte de
/// stock au premier affichage du shell pendant la session, et un
/// autre déclenche silencieusement une sauvegarde automatique
/// quotidienne si aucune n'a déjà été faite aujourd'hui.
class MainShell extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const MainShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              SidebarMenu(currentRoute: currentRoute),
              Expanded(child: child),
            ],
          ),
          const Positioned(
            top: 16,
            right: 24,
            child: NotificationBell(),
          ),
          const StartupAlertTrigger(),
          const StartupDraftChecker(),
          const AutoBackupTrigger(),
          const AccessDeniedTrigger(),
        ],
      ),
    );
  }
}
