<<<<<<< HEAD
# 🏦 Dibi Family - Application de Gestion de Cotisations & Tontines de Famille
=======
#  KOTA
>>>>>>> 45e8253d1bb1bbd76c954062f10238922a7458e9

![Flutter](https://img.shields.io/badge/Flutter-3.24.0-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.5.0-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%26%20Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-APK%20Ready-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

<<<<<<< HEAD
**Dibi Family** est une application mobile moderne et intuitive conçue pour simplifier, sécuriser et automatiser la gestion des tontines, cotisations de groupe et finances familiales en Côte d'Ivoire et en Afrique de l'Ouest.

---

## ✨ Fonctionnalités Principales

### 🔐 Authentification Rapide & Sécurisée
- **Connexion Google Sign-In** : Inscription et connexion en 1 clic avec le bouton officiel Google.
- **Connexion Téléphone (+225)** : Saisie directe par nom et numéro de téléphone à 10 chiffres (`07`, `05`, `01`).
- **Code PIN Aléatoire Dynamique** : Génération automatique d'un code PIN de sécurité à 4 chiffres unique pour chaque nouvel utilisateur, modifiable à tout moment dans le profil.

### 📌 Création, Partage & Adhésion aux Cagnottes
- **Création instantanée** : Définition du nom de la tontine, de l'objectif financier global (FCFA) et de la cotisation mensuelle.
- **Codes & QR Codes Uniques** : Génération automatique d'un code d'accès unique (ex: `DIBI-366-570`) et d'un QR Code haute définition.
- **Adhésion instantanée** : Scanner de caméra intégré (avec flash et inversion) ou saisie manuelle de code.
- **Transparence totale des membres** : Chaque participant voit les vrais noms, numéros de téléphone et le badge ⭐ **Trésorier** identifiant le créateur du groupe.

### 💳 Passerelle de Paiement Intégrée
- **Guichet Unique Jeko Africa (`pay.jeko.africa`)** : Intégration directe du guichet de paiement sécurisé acceptant **Wave**, **Orange Money**, **MTN Mobile Money**, **Moov Money** et les **Cartes Bancaires**.
- **Gestion des Déclarations** : Soumission des versements par les membres (`status: pending`) et confirmation/validation sécurisée par le Trésorier (`status: verified`).

### 💬 Espace Chat Interactif & Notifications
- **Chat en temps réel** : Discussion sécurisée réservée aux membres de la tontine.
- **Fonctionnalités avancées** :
  - **Répondre** à un message avec boîte de citation.
  - **Modifier** et **Supprimer** ses propres messages.
  - **Mentions `@`** façon WhatsApp avec liste d'autocomplétion des membres.
  - **Indicateur de saisie animé (`...`)** affiché aux autres participants quand un membre écrit.
  - **Auto-scroll automatique vers le bas** et classement du plus ancien au plus récent.

### 🥳 Clôture Automatique & Célébration
- **Animation de Félicitations** : Déclenchement d'un bandeau de célébration `🎉 FÉLICITATIONS ! 🎉` dès que l'objectif financier est atteint.
- **Fermeture automatique** : Passage de la cagnotte au statut `Clôturée` et fermeture sécurisée du Chat.

---

## 🛠️ Stack Technique

- **Frontend** : Flutter 3.24, Dart 3.5, Material Design 3.
- **Backend & Temps Réel** : Google Cloud Firestore, Firebase Authentication.
- **Paiements** : Jeko Africa Checkout V1 (`pay.jeko.africa`).
- **Scanner & QR Code** : `mobile_scanner`, `qr_flutter`.
- **Incompatibilités & Offline** : Cache local Firestore avec `persistenceEnabled: true` pour un démarrage instantané en moins de 0.5s.

---

## 🚀 Installation & Démarrage

### Prérequis
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.24.0 ou supérieur)
- Android Studio / VS Code avec extension Flutter
- Un terminal Android ou émulateur connecté via ADB

### Étape 1 : Cloner le projet
=======
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

>>>>>>> 45e8253d1bb1bbd76c954062f10238922a7458e9
```bash
git clone https://github.com/votre-compte/dibi_family.git
cd dibi_family
```

<<<<<<< HEAD
### Étape 2 : Installer les dépendances
=======
### 2. Installer les dépendances

>>>>>>> 45e8253d1bb1bbd76c954062f10238922a7458e9
```bash
flutter pub get
```

<<<<<<< HEAD
### Étape 3 : Exécuter l'application sur un appareil connecté
=======
### 3. Configurer Firebase

Ajoute les fichiers de configuration Firebase nécessaires selon votre environnement :

- `google-services.json` pour Android
- `firebase_options.dart` si tu utilises FlutterFire

### 4. Lancer l’application

>>>>>>> 45e8253d1bb1bbd76c954062f10238922a7458e9
```bash
flutter run
```

<<<<<<< HEAD
### Étape 4 : Générer l'APK de Release
```bash
flutter build apk --release
=======
Pour un lancement sur un appareil Android connecté :

```bash
flutter run --device-id <device_id>
>>>>>>> 45e8253d1bb1bbd76c954062f10238922a7458e9
```

---

<<<<<<< HEAD
## 🛡️ Configuration des Règles Firestore (`firestore.rules`)

Assurez-vous de publier les règles de sécurité suivantes dans votre **Console Firebase** (`Firestore Database > Rules`) :

```firestore
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    match /invitations/{inviteCode} {
      allow read, create: if request.auth != null;
    }

    match /cotisations/{cotisationId} {
      allow create, get: if request.auth != null;
      allow list: if request.auth != null && request.auth.uid in resource.data.members;

      allow update: if request.auth != null && (
        request.auth.uid in resource.data.members ||
        request.auth.uid in request.resource.data.members
      );

      allow delete: if request.auth != null && request.auth.uid == resource.data.ownerId;

      match /messages/{messageId} {
        allow read, create: if request.auth != null;
        allow update, delete: if request.auth != null && (
          request.auth.uid == resource.data.senderId ||
          request.auth.uid == resource.data.createdBy
        );
      }

      match /typing/{userId} {
        allow read, write: if request.auth != null;
      }

      match /expenses/{expenseId} {
        allow read, create, update, delete: if request.auth != null;
      }

      match /transactions/{transactionId} {
        allow read, create, update, delete: if request.auth != null;
      }
    }
  }
}
```

---

## 📝 Auteur & Licence

Développé pour la communauté **Dibi Family**.  
Publié sous la licence **MIT**.
=======
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
>>>>>>> 45e8253d1bb1bbd76c954062f10238922a7458e9
