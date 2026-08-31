import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../presentation/commercial_documents/providers/commercial_document_providers.dart';

/// Dropdown de sélection du taux de TVA, chargé depuis la table [tva_rates].
class TvaRateSelector extends ConsumerWidget {
  final double? value;
  final ValueChanged<double> onChanged;
  final bool compact;

  const TvaRateSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvaAsync = ref.watch(tvaRatesProvider);

    return tvaAsync.when(
      loading: () => const SizedBox(
        width: 80,
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const Icon(Icons.error_outline, color: AppColors.danger),
      data: (rates) {
        // Si le taux courant n'est pas dans la liste (ex: données historiques
        // avec 0%), on l'ajoute dynamiquement pour éviter un assert Flutter.
        final tauxDispos = rates.map((r) => r.taux).toSet();
        final valeurEffective = (value != null && tauxDispos.contains(value))
            ? value
            : (rates.isNotEmpty ? rates.first.taux : 0.0);

        if (compact) {
          return DropdownButton<double>(
            value: valeurEffective,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: rates
                .map((r) => DropdownMenuItem(
                      value: r.taux,
                      child: Text(
                        '${r.taux.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ))
                .toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          );
        }

        return DropdownButtonFormField<double>(
          value: valeurEffective,
          decoration: const InputDecoration(labelText: 'TVA'),
          items: rates
              .map((r) => DropdownMenuItem(
                    value: r.taux,
                    child: Text(r.libelle),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        );
      },
    );
  }
}
