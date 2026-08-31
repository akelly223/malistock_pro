import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MalistockProApp extends ConsumerWidget {
  const MalistockProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MaliStock Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
      // Requis pour que showDatePicker(locale: Locale('fr', 'FR'))
      // (sélecteur de date des pièces commerciales) trouve des
      // MaterialLocalizations françaises au lieu de planter faute de
      // délégué supportant 'fr'.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      locale: const Locale('fr', 'FR'),
    );
  }
}
