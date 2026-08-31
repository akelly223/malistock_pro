import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../alerts/providers/stock_alerts_provider.dart';

/// Cloche de notification flottante, superposée en haut à droite de
/// toutes les pages de l'application via le shell principal. Affiche
/// un badge avec le nombre d'alertes de stock actives et navigue vers
/// la page dédiée au clic.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(stockAlertsCountProvider);

    return countAsync.when(
      data: (count) => _BellButton(count: count),
      loading: () => const _BellButton(count: 0),
      error: (_, __) => const _BellButton(count: 0),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int count;

  const _BellButton({required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.push('/alerts'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                count > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: count > 0 ? AppColors.danger : AppColors.textSecondary,
                size: 22,
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
