# 🏦 Dibi Family - Application de Gestion de Cotisations & Tontines de Famille

![Flutter](https://img.shields.io/badge/Flutter-3.24.0-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.5.0-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%26%20Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-APK%20Ready-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

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
```bash
git clone https://github.com/votre-compte/dibi_family.git
cd dibi_family
```

### Étape 2 : Installer les dépendances
```bash
flutter pub get
```

### Étape 3 : Exécuter l'application sur un appareil connecté
```bash
flutter run
```

### Étape 4 : Générer l'APK de Release
```bash
flutter build apk --release
```

---

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
