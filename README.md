#  KOTA

![Flutter](https://img.shields.io/badge/Flutter-3.24.0-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.5.0-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%26%20Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-APK%20Ready-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

KOTA est une application mobile pensée pour simplifier la gestion des tontines, des cotisations de groupe et des finances familiales en Côte d’Ivoire et en Afrique de l’Ouest.

L’application permet à un groupe de créer une cagnotte, d’inviter des membres, de suivre les contributions, de valider les paiements, de discuter en temps réel et d’atteindre un objectif de façon claire, sécurisée et transparente.

---

##  Présentation

KOTA combine les fonctionnalités d’une tontine digitale, d’un espace de discussion interne et d’une passerelle de paiements dans une même expérience mobile fluide.

Elle a été conçue pour les familles, groupes de travail, amis et associations qui souhaitent organiser des contributions régulières sans friction, tout en gardant une visibilité totale sur les cotisations et les participants.

---

##  Fonctionnalités principales

### 1. Authentification rapide et sécurisée
- Connexion via Google Sign-In
- Connexion par téléphone avec format ivoirien (+225)
- Code PIN à 4 chiffres généré automatiquement et modifiable
- Gestion de profil utilisateur simple et sécurisée

### 2. Création et gestion des tontines
- Création d’une tontine avec nom, objectif global et cotisation mensuelle
- Génération automatique d’un code unique d’accès
- Génération de QR Code pour l’adhésion rapide
- Rejoindre une cagnotte par scan ou saisie manuelle du code
- Visualisation des membres, rôles et statut de chacun

### 3. Paiements et validation des versements
- Intégration du guichet Jeko Africa
- Paiement via Wave, Orange Money, MTN Mobile Money, Moov Money et cartes bancaires
- Soumission des versements par les membres
- Validation sécurisée par le trésorier
- Suivi du statut des paiements : pending, verified, etc.

### 4. Chat interne du groupe
- Discussion en temps réel entre membres
- Réponses à des messages via citation
- Modification et suppression des messages personnels
- Mentions @ avec autocomplétion des membres
- Indicateur de saisie animé lors de la rédaction d’un message
- Scroll automatique vers le bas et historique lisible

### 5. Clôture automatique et célébration
- Détection automatique de l’atteinte de l’objectif financier
- Animation de félicitations à l’arrivée du seuil cible
- Fermeture sécurisée de la cagnotte
- Blocage du chat une fois la tontine clôturée

---

##  Stack technique

- Frontend : Flutter 3.24 + Dart 3.5
- UI : Material Design 3
- Backend : Firebase Authentication + Cloud Firestore
- Temps réel : Firestore avec synchronisation native
- Paiements : Jeko Africa Checkout
- Scanning QR : mobile_scanner
- Génération QR : qr_flutter
- Performance : persistence Firestore activée pour un démarrage rapide

---

##  Structure du projet

```text
lib/
  app/
  core/
  features/
  models/
  services/
  widgets/
  main.dart
```

Le projet est organisé autour des fonctionnalités métier : authentification, tontines, paiements, chat, profil utilisateur et gestion de données.

---

##  Prérequis

Avant de lancer l’application, assure-toi d’avoir installé :

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.24 ou supérieure)
- Android Studio ou VS Code avec l’extension Flutter
- Un émulateur Android ou un appareil connecté via ADB
- Un projet Firebase configuré

---

##  Installation et démarrage

### 1. Cloner le dépôt

```bash
git clone https://github.com/votre-compte/dibi_family.git
cd dibi_family
```

### 2. Installer les dépendances

```bash
flutter pub get
```

### 3. Configurer Firebase

Ajoute les fichiers de configuration Firebase nécessaires selon votre environnement :

- `google-services.json` pour Android
- `firebase_options.dart` si tu utilises FlutterFire

### 4. Lancer l’application

```bash
flutter run
```

Pour un lancement sur un appareil Android connecté :

```bash
flutter run --device-id <device_id>
```

---

##  Fonctionnalités métier clés

- Création de tontines en quelques secondes
- Invitation de membres via code ou QR
- Déclaration de versements en temps réel
- Validation par le trésorier
- Échange de messages sécurisés dans le groupe
- Suivi transparent des cotisations et des objectifs
- Clôture automatique au moment où la cible est atteinte

---

##  Cas d’usage

KOTA s’adresse notamment à :

- familles organisant des cotisations mensuelles,
- groupes d’amis qui souhaitent une caisse commune,
- petites associations ou communautés,
- entreprises ou équipes qui veulent gérer des contributions entre collègues.

---

##  Licence

Ce projet est distribué sous licence MIT.

---

##  Auteur

Développé par : Dibi Christian Manuel

Projet conçu pour la gestion moderne des tontines et cotisations de groupe, avec un focus sur la simplicité d’usage, la sécurité et la transparence.

Si vous souhaitez personnaliser ou étendre cette application, vous pouvez la faire évoluer selon vos besoins métiers et vos règles de gestion locale.
