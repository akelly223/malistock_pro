# MaliStock Pro (Flutter Desktop Windows)

Logiciel de gestion commerciale offline pour commerçants, alternative simplifiée à Sage Gestion Commerciale.

## État actuel du projet

Front-end complet et fonctionnel pour les modules suivants :

- **Authentification** : création du premier compte admin au lancement, puis connexion classique.
- **Dashboard** : ventes jour/semaine/mois, bénéfice du mois, factures du mois, alertes stock faible, produits les plus vendus, graphique des ventes sur 7 jours.
- **Articles** : liste avec recherche, création/modification/suppression, autocomplete intelligent (taper "ri" propose "Riz local", etc.).
- **Clients** : liste, fiche détail avec historique d'achats, dette, enregistrement de règlement.
- **Fournisseurs** : liste, création/modification rapide.
- **Devis** : création avec panier d'articles (autocomplete), conversion en facture sans ressaisie.
- **Factures** : création de vente rapide (panier, remises, choix client/magasin, encaissement avec mode de paiement), détail facture.
- **Dettes clients** : vue globale des clients débiteurs et montant total dû.
- **Magasins** : gestion multi-magasin (création, magasin principal).
- **Mouvements de stock** : historique complet + transfert entre magasins.
- **Paramètres** : écran préparé pour sauvegarde ZIP et logo société (branchement à l'étape suivante).

Architecture : Clean Architecture simplifiée (`domain` → entités/interfaces, `data` → Drift + repositories, `presentation` → écrans + providers Riverpod), navigation via GoRouter avec ShellRoute (sidebar persistante).

**Pas encore inclus** (prochaine étape) :
- Génération PDF réelle des factures/devis (le bouton existe déjà dans l'UI mais affiche un message d'attente)
- Service de sauvegarde export/import ZIP (l'écran Paramètres est prêt, la logique reste à câbler)
- Authentification fine des permissions employé vs admin sur certains écrans

## Mise en place de l'environnement (à faire quand tu seras prêt à tester sur Windows)

### Prérequis

1. **Flutter SDK** (canal stable, ≥ 3.22) installé et dans le PATH — vérifier avec `flutter --version`
2. Activer le support desktop Windows :
   ```
   flutter config --enable-windows-desktop
   ```
3. **Visual Studio 2022** avec le workload "Desktop development with C++"
4. Vérifier l'environnement :
   ```
   flutter doctor
   ```

### Étapes

1. Dézippe le projet, ouvre un terminal dans le dossier `malistock_pro/`
2. Installe les dépendances :
   ```
   flutter pub get
   ```
3. Génère le code Drift (fichiers `.g.dart` requis, absents de ce ZIP car auto-générés) :
   ```
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Génère le squelette natif Windows s'il manque :
   ```
   flutter create --platforms=windows .
   ```
5. Lance l'application en mode développement :
   ```
   flutter run -d windows
   ```
   ou pour un build final :
   ```
   flutter build windows
   ```

### En cas d'erreur

- **Visual Studio C++ manquant** → l'installer via Visual Studio Installer, relancer `flutter doctor`.
- **sqlite3_flutter_libs introuvable** → `flutter clean && flutter pub get`.
- **Conflits build_runner** → toujours utiliser `--delete-conflicting-outputs`.
- **Premier lancement** : aucun utilisateur n'existe en base, l'écran de connexion proposera automatiquement de créer le compte administrateur.

## Prochaine étape

- Génération PDF (factures/devis avec logo société)
- Service de sauvegarde (export/import ZIP), avec architecture préparée pour une synchronisation cloud Supabase future
- Packaging Windows final (Setup.exe via Inno Setup ou MSIX)
