# Règles de Développement & Architecture BiblioGenius

Pour maintenir la stabilité du projet (particulièrement l'architecture hybride Rust/Flutter), merci de respecter les règles suivantes lors de tout développement :

## 1. Architecture Rust/FFI/Flutter

Ce projet utilise une architecture hybride complexe :

- **Frontend** : Flutter
- **Bridge** : `flutter_rust_bridge` (FFI)
- **Backend Local** : Rust (Axum)
- **Base de données** : SQLite (gérée par `sea_orm` côté Rust)

**Points critiques :**

- **Démarrage & Race Conditions** : Le serveur Rust tourne localement. Au démarrage de l'app, il peut y avoir une latence avant que le port ne soit lié. Utilisez toujours les wrappers HTTP robustes (`_getLocalDio()` dans `ApiService`) qui incluent des mécansimes de *retry*, plutôt que des appels Dio bruts qui risquent d'échouer avec "Connection refused".
- **Données & Normalisation** : Soyez vigilants sur la cohérence des données entre les couches.
  - *Exemple* : Flutter peut normaliser l'interface ("Read"), mais les requêtes SQL (Rust) sont souvent *case-sensitive*. Assurez-vous que vos requêtes backend (`sea_orm`) gèrent ces variations (`Condition::any()`) ou que les données sont strictement normalisées.

## 2. Prévention des Régressions

Avant de considérer une tâche comme terminée, vérifiez impérativement :

- **L'Autocomplétion** : Doit fonctionner immédiatement au lancement de l'app (pas d'erreur de connexion).
- **Les Statistiques** : Vérifiez que les compteurs (ex: Badge "Lecteur") reflètent fidèlement les données locales.
- **La Recherche** : Vérifiez la priorisation des sources (ex: BNF pour les utilisateurs français) et les timeouts.

Cette architecture est puissante mais exige de la rigueur pour éviter les désynchronisations entre le monde Dart et le monde Rust.
