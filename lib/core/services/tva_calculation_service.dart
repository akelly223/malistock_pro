/// Résultat de calcul pour une ligne de document.
class DocumentLineTotals {
  final double totalHt;
  final double montantTva;
  final double totalTtc;

  const DocumentLineTotals({
    required this.totalHt,
    required this.montantTva,
    required this.totalTtc,
  });
}

/// Résultat de calcul pour l'ensemble d'un document.
class DocumentTotals {
  final double totalHt;
  final double totalTva;
  final double totalTtc;

  const DocumentTotals({
    required this.totalHt,
    required this.totalTva,
    required this.totalTtc,
  });
}

/// Service de calcul TVA — aucune dépendance à la base de données.
///
/// Formules :
///   total_ht    = quantite × prix_ht × (1 − remise_ligne / 100)
///   montant_tva = total_ht × taux_tva / 100
///   total_ttc   = total_ht + montant_tva
///
/// La remise globale est appliquée proportionnellement sur HT et TVA
/// avant d'être agrégée au niveau du document.
class TVACalculationService {
  const TVACalculationService();

  DocumentLineTotals calculerLigne({
    required double quantite,
    required double prixUnitaireHt,
    required double tauxTva,
    required double remiseLignePct,
  }) {
    final totalHt =
        quantite * prixUnitaireHt * (1 - remiseLignePct / 100);
    final montantTva = totalHt * tauxTva / 100;
    final totalTtc = totalHt + montantTva;
    return DocumentLineTotals(
      totalHt: _arrondir(totalHt),
      montantTva: _arrondir(montantTva),
      totalTtc: _arrondir(totalTtc),
    );
  }

  DocumentTotals calculerDocument({
    required List<DocumentLineTotals> lignes,
    required double remiseGlobalePct,
  }) {
    final facteur = 1 - remiseGlobalePct / 100;

    final sousTotalHt =
        lignes.fold(0.0, (sum, l) => sum + l.totalHt);
    final sousTotalTva =
        lignes.fold(0.0, (sum, l) => sum + l.montantTva);

    final totalHt = _arrondir(sousTotalHt * facteur);
    final totalTva = _arrondir(sousTotalTva * facteur);
    final totalTtc = _arrondir(totalHt + totalTva);

    return DocumentTotals(
      totalHt: totalHt,
      totalTva: totalTva,
      totalTtc: totalTtc,
    );
  }

  double _arrondir(double valeur) => (valeur * 100).round() / 100;
}
