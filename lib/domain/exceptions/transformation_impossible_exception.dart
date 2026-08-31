import '../entities/document_type.dart';

/// Levée quand une transformation demandée n'est pas autorisée
/// par les règles du cycle commercial.
class TransformationImpossibleException implements Exception {
  final String sourceNumero;
  final DocumentType sourceType;
  final DocumentStatut sourceStatut;
  final DocumentType cibleType;
  final String? raison;

  const TransformationImpossibleException({
    required this.sourceNumero,
    required this.sourceType,
    required this.sourceStatut,
    required this.cibleType,
    this.raison,
  });

  @override
  String toString() {
    final message = raison ??
        '${sourceType.libelle} (${sourceStatut.libelle}) → ${cibleType.libelle} non autorisé';
    return 'Transformation impossible pour "$sourceNumero" : $message';
  }
}
