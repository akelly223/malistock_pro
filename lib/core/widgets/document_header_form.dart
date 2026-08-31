import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/store.dart';
import '../../presentation/clients/providers/client_provider.dart';
import '../../presentation/stores/providers/store_provider.dart';

/// En-tête d'un formulaire de pièce commerciale :
/// client, magasin, date, référence externe, conditions de règlement.
///
/// Tous les champs sont optionnels côté UI — le FormScreen contrôle
/// lesquels afficher selon le type de document.
class DocumentHeaderForm extends ConsumerWidget {
  final int? clientId;
  final String? clientNom;
  final int? storeId;
  final DateTime dateDocument;
  final String? referenceExterne;
  final String? conditionsReglement;
  final bool showStore;
  final bool showReference;
  final bool showConditions;
  final bool readOnly;

  final ValueChanged<int?>? onClientChanged;
  final ValueChanged<int>? onStoreChanged;
  final ValueChanged<DateTime>? onDateChanged;
  final ValueChanged<String?>? onReferenceChanged;
  final ValueChanged<String?>? onConditionsChanged;

  const DocumentHeaderForm({
    super.key,
    this.clientId,
    this.clientNom,
    this.storeId,
    required this.dateDocument,
    this.referenceExterne,
    this.conditionsReglement,
    this.showStore = true,
    this.showReference = false,
    this.showConditions = false,
    this.readOnly = false,
    this.onClientChanged,
    this.onStoreChanged,
    this.onDateChanged,
    this.onReferenceChanged,
    this.onConditionsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(filteredClientsProvider);
    final storesAsync = ref.watch(storesListProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations', style: AppTextStyles.h3),
          const SizedBox(height: 16),

          // ── Ligne 1 : Client + Magasin ────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _ClientDropdown(
                  clientsAsync: clientsAsync,
                  selectedId: clientId,
                  readOnly: readOnly,
                  onChanged: onClientChanged,
                ),
              ),
              if (showStore) ...[
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _StoreDropdown(
                    storesAsync: storesAsync,
                    selectedId: storeId,
                    readOnly: readOnly,
                    onChanged: onStoreChanged,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ── Ligne 2 : Date ────────────────────────────────────────────
          _DateField(
            date: dateDocument,
            readOnly: readOnly,
            onChanged: onDateChanged,
          ),

          // ── Référence externe ─────────────────────────────────────────
          if (showReference) ...[
            const SizedBox(height: 14),
            _TextField(
              label: 'Référence externe (N° BC client…)',
              value: referenceExterne,
              readOnly: readOnly,
              onChanged: onReferenceChanged,
            ),
          ],

          // ── Conditions règlement ──────────────────────────────────────
          if (showConditions) ...[
            const SizedBox(height: 14),
            _TextField(
              label: 'Conditions de règlement',
              value: conditionsReglement,
              readOnly: readOnly,
              onChanged: onConditionsChanged,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets internes ─────────────────────────────────────────────────────────

class _ClientDropdown extends StatelessWidget {
  final AsyncValue<List<ClientEntity>> clientsAsync;
  final int? selectedId;
  final bool readOnly;
  final ValueChanged<int?>? onChanged;

  const _ClientDropdown({
    required this.clientsAsync,
    required this.selectedId,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return clientsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text('Erreur clients', style: TextStyle(color: AppColors.danger)),
      data: (clients) => DropdownButtonFormField<int?>(
        value: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Client',
          prefixIcon: Icon(Icons.person_outline),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('— Vente comptoir —',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ...clients
              .map((c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(c.nom),
                  ))
              .toList(),
        ],
        onChanged: readOnly ? null : (v) => onChanged?.call(v),
      ),
    );
  }
}

class _StoreDropdown extends StatelessWidget {
  final AsyncValue<List<StoreEntity>> storesAsync;
  final int? selectedId;
  final bool readOnly;
  final ValueChanged<int>? onChanged;

  const _StoreDropdown({
    required this.storesAsync,
    required this.selectedId,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return storesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text('Erreur magasins', style: TextStyle(color: AppColors.danger)),
      data: (stores) => DropdownButtonFormField<int>(
        value: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Magasin',
          prefixIcon: Icon(Icons.store_outlined),
        ),
        items: stores
            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nom)))
            .toList(),
        onChanged: readOnly ? null : (v) { if (v != null) onChanged?.call(v); },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime date;
  final bool readOnly;
  final ValueChanged<DateTime>? onChanged;

  const _DateField({
    required this.date,
    required this.readOnly,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: readOnly ? null : () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date du document',
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: readOnly ? null : const Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(DateFormatter.formatDate(date), style: AppTextStyles.body),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final String? value;
  final bool readOnly;
  final ValueChanged<String?>? onChanged;

  const _TextField({
    required this.label,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      readOnly: readOnly,
      decoration: InputDecoration(labelText: label),
      onChanged: readOnly ? null : (v) => onChanged?.call(v.isEmpty ? null : v),
    );
  }
}
