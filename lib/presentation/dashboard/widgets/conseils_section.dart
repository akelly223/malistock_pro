import 'package:flutter/material.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/dashboard_stats.dart';

class ConseilsSection extends StatelessWidget {
  final List<ConseilDashboard> conseils;

  const ConseilsSection({super.key, required this.conseils});

  @override
  Widget build(BuildContext context) {
    if (conseils.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFD9A226), size: 20),
            const SizedBox(width: 8),
            Text('Conseils intelligents', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: 12),
        ...conseils.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.couleurFond,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.couleur.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.icone, color: c.couleur, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.message,
                      style: AppTextStyles.body.copyWith(color: c.couleur),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
