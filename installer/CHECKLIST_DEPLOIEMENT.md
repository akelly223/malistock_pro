# Checklist de déploiement — avant livraison chez un commerçant

À parcourir intégralement avant chaque installation chez un client
réel, pas seulement la première fois.

## Avant de quitter ton poste de développement

- [ ] `flutter build windows --release` exécuté sans erreur
- [ ] Testé en double-cliquant directement sur l'exe du dossier
      Release (pas seulement via `flutter run`)
- [ ] Testé un cycle complet : créer un article, créer un client,
      faire une vente, vérifier la facture PDF, faire un achat
      fournisseur, vérifier le PDF achat
- [ ] Testé la sauvegarde ZIP (Paramètres > Exporter une sauvegarde)
      et vérifié que le fichier .zip se crée bien
- [ ] Testé la connexion avec un compte employé (si le commerçant
      prévoit d'avoir des vendeurs) : vérifié qu'il ne voit que
      Dashboard/Articles/Clients/Factures/Devis, sans prix d'achat
- [ ] `StockMali_Setup.exe` généré et testé sur une machine Windows
      "propre" (pas celle de développement)
- [ ] Numéro de version (`MyAppVersion` dans `setup.iss`) à jour et
      noté quelque part pour le suivi

## Sur place, chez le commerçant (premier jour)

- [ ] Vérifier la configuration Windows minimale : Windows 10 ou 11,
      64 bits (`ArchitecturesAllowed=x64compatible` dans le script —
      ne fonctionnera pas sur un Windows 32 bits ancien)
- [ ] Lancer `StockMali_Setup.exe`, vérifier que l'installation se
      termine sans erreur et que les raccourcis Bureau + Menu
      Démarrer sont bien créés
- [ ] Lancer l'application depuis le raccourci Bureau (pas depuis
      le dossier d'installation directement, pour valider le vrai
      parcours du commerçant)
- [ ] Créer le compte administrateur avec le commerçant lui-même
      présent — c'est lui qui doit choisir son identifiant et son
      mot de passe, jamais toi à sa place
- [ ] **Noter ces identifiants sur papier**, lui remettre, lui dire
      explicitement de les conserver en lieu sûr (il n'existe pas de
      "mot de passe oublié" automatique pour l'instant — la procédure
      de récupération nécessite un accès technique au fichier SQLite)
- [ ] Proposer les données de démonstration UNIQUEMENT s'il veut
      explorer l'app avant de saisir ses vraies données — sinon
      répondre "Non" et saisir directement son catalogue réel
- [ ] Configurer les Paramètres entreprise avec lui : nom du
      commerce, téléphone, adresse, logo si disponible
- [ ] Faire ensemble une vente test avec un vrai article de son
      catalogue, vérifier que la facture imprimée/PDF lui convient
- [ ] **Faire une première sauvegarde ZIP ensemble**, lui montrer où
      elle se trouve (`Documents\MaliStockPro\sauvegardes\`),
      et lui recommander de copier ce fichier sur une clé USB après
      chaque journée de travail au début

## Points à expliquer explicitement au commerçant (oral, pas juste écrit)

- Où sont stockées ses données réellement (`Documents\MaliStockPro\`)
  et que cela reste sur SON ordinateur, jamais envoyé ailleurs
- Comment faire une sauvegarde manuelle (bouton dans Paramètres)
- Que désinstaller puis réinstaller l'application ne supprime pas
  ses données, mais qu'il vaut quand même mieux sauvegarder avant
  toute manipulation qu'il ne comprend pas entièrement
- Qu'un employé (s'il en a) ne peut pas voir ses prix d'achat ni ses
  fournisseurs — c'est voulu, pas un bug
- Qu'il doit garder une trace de son mot de passe administrateur

## Suivi après installation (J+7, J+30)

- [ ] Contact de suivi pour vérifier qu'aucun blocage n'est apparu
      à l'usage réel (souvent différent des tests en interne)
- [ ] Vérifier que des sauvegardes ont bien été faites régulièrement
- [ ] Collecter les retours sur ce qui manque ou gêne dans l'usage
      quotidien réel — la liste d'audit qu'on a construite ensemble
      vient de suppositions, l'usage réel révèle souvent d'autres
      priorités
