/// Mode de calcul d'une remise globale.
enum RemiseType { montant, pourcentage }

/// Représente la remise globale appliquée à un document (devis,
/// facture, achat), exprimée soit en montant fixe (FCFA) soit en
/// pourcentage du sous-total. Centralise le calcul pour garantir un
/// comportement strictement identique dans les trois modules.
class RemiseGlobale {
  final double valeur;
  final RemiseType type;

  const RemiseGlobale({
    this.valeur = 0,
    this.type = RemiseType.montant,
  });

  static const RemiseGlobale zero = RemiseGlobale();

  /// Calcule le montant de remise en FCFA pour un sous-total donné.
  /// Le pourcentage est borné à 100% : une remise ne peut jamais
  /// dépasser le sous-total, donc jamais rendre le total négatif.
  double montantPour(double sousTotal) {
    if (type == RemiseType.pourcentage) {
      final pourcentageBorne = valeur.clamp(0, 100);
      return sousTotal * (pourcentageBorne / 100);
    }
    // Remise en montant fixe : ne peut pas non plus dépasser le
    // sous-total, par cohérence (un total ne doit jamais être négatif).
    return valeur.clamp(0, sousTotal == 0 ? 0 : sousTotal);
  }

  /// Libellé d'affichage pour le récapitulatif, ex: "20% (20 000 FCFA)"
  /// pour un pourcentage, ou simplement le montant pour une remise fixe.
  String libelleAvecDetail(double sousTotal) {
    if (type == RemiseType.pourcentage) {
      final pourcentageBorne = valeur.clamp(0, 100);
      return '${pourcentageBorne.toStringAsFixed(0)}%';
    }
    return '';
  }

  RemiseGlobale copyWith({double? valeur, RemiseType? type}) {
    return RemiseGlobale(
      valeur: valeur ?? this.valeur,
      type: type ?? this.type,
    );
  }
}
