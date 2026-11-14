import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class CagnoteRepository {
  final _db = FirebaseFirestore.instance;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Enregistre ou met à jour le profil utilisateur (génère un PIN aléatoire unique si absent)
  Future<void> enregistrerProfil({
    required String name,
    required String phone,
    String? photoUrl,
    String? pinCode,
    List<String>? paymentMethods,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final existingPin = userDoc.data()?['pinCode'] as String?;

    // Génération d'un PIN aléatoire unique à 4 chiffres (ex: 8391) si aucun PIN n'existe encore
    final finalPin = pinCode ?? existingPin ?? (1000 + Random().nextInt(9000)).toString();

    final data = <String, dynamic>{
      'name': name,
      'phone': phone,
      'pinCode': finalPin,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (paymentMethods != null) data['paymentMethods'] = paymentMethods;

    await _db.collection('users').doc(user.uid).set(data, SetOptions(merge: true));

    // Mettre à jour membersInfo dans toutes les cotisations du membre
    try {
      final myCotas = await _db
          .collection('cotisations')
          .where('members', arrayContains: user.uid)
          .get();

      for (final doc in myCotas.docs) {
        await doc.reference.set({
          'membersInfo': {
            user.uid: {
              'name': name,
              'phone': phone,
              if (photoUrl != null) 'photoUrl': photoUrl,
            }
          }
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Met à jour le code PIN de sécurité
  Future<void> enregistrerPin(String pinCode) async {
    final user = currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'pinCode': pinCode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Met à jour les moyens de paiement préférés
  Future<void> enregistrerMoyensPaiement(List<String> methods) async {
    final user = currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'paymentMethods': methods,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Écoute les cotisations de l'utilisateur en direct
  Stream<QuerySnapshot<Map<String, dynamic>>> ecouterMesCotisations() {
    final user = currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('cotisations')
        .where('members', arrayContains: user.uid)
        .snapshots();
  }

  /// Crée une cotisation avec les informations des membres embarquées
  Future<String> creerCotisation({
    required String name,
    required double targetAmount,
    required double monthlyAmount,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");

    final random = Random();
    final cotRef = _db.collection('cotisations').doc();

    String myName = "Trésorier";
    String myPhone = "+225 -- -- -- --";

    try {
      final myProfileSnap = await _db.collection('users').doc(user.uid).get();
      if (myProfileSnap.exists) {
        myName = myProfileSnap.data()?['name'] as String? ?? "Trésorier";
        myPhone = myProfileSnap.data()?['phone'] as String? ?? "+225 -- -- -- --";
      }
    } catch (_) {}

    for (int essai = 0; essai < 10; essai++) {
      final code = "DIBI-${100 + random.nextInt(900)}-${100 + random.nextInt(900)}";
      final inviteRef = _db.doc('invitations/$code');

      try {
        await cotRef.set({
          'name': name,
          'ownerId': user.uid,
          'montantTotal': targetAmount,
          'sommeParMembre': monthlyAmount,
          'statut': 'ouverte',
          'inviteCode': code,
          'members': [user.uid],
          'membersInfo': {
            user.uid: {
              'name': myName,
              'phone': myPhone,
            }
          },
          'paid': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        await inviteRef.set({'cotisationId': cotRef.id});

        try {
          await envoyerMessage(
            cotisationId: cotRef.id,
            senderName: "Bot IA",
            message: "Bienvenue dans la cotisation $name ! La cagnotte est ouverte.",
          );
        } catch (_) {}

        return cotRef.id;
      } catch (e) {
        if (essai == 9) rethrow;
      }
    }
    throw Exception("Impossible de créer la cotisation. Veuillez vérifier votre connexion réseau.");
  }

  /// Rejoint une cotisation et enregistre les informations du membre dans membersInfo
  Future<String> rejoindreParCode(String code) async {
    final user = currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");

    final match = RegExp(r'DIBI-\d{3}-\d{3}', caseSensitive: false).firstMatch(code);
    final cleanCode = match != null ? match.group(0)!.toUpperCase() : code.trim().toUpperCase();

    String? cotisationId;

    try {
      final inviteSnap = await _db.doc('invitations/$cleanCode').get();
      if (inviteSnap.exists) {
        cotisationId = inviteSnap.data()?['cotisationId'] as String?;
      }
    } catch (_) {}

    if (cotisationId == null) {
      try {
        final cotQuery = await _db
            .collection('cotisations')
            .where('inviteCode', isEqualTo: cleanCode)
            .get();

        if (cotQuery.docs.isNotEmpty) {
          cotisationId = cotQuery.docs.first.id;
        }
      } catch (_) {}
    }

    if (cotisationId == null) {
      throw Exception("Code DIBI introuvable ($cleanCode). Créez une nouvelle cotisation ou réessayez.");
    }

    String myName = "Membre";
    String myPhone = "+225 -- -- -- --";

    try {
      final myProfileSnap = await _db.collection('users').doc(user.uid).get();
      if (myProfileSnap.exists) {
        myName = myProfileSnap.data()?['name'] as String? ?? "Membre";
        myPhone = myProfileSnap.data()?['phone'] as String? ?? "+225 -- -- -- --";
      }
    } catch (_) {}

    final cotRef = _db.collection('cotisations').doc(cotisationId);

    try {
      await cotRef.set({
        'members': FieldValue.arrayUnion([user.uid]),
        'membersInfo': {
          user.uid: {
            'name': myName,
            'phone': myPhone,
          }
        }
      }, SetOptions(merge: true));
    } catch (_) {}

    try {
      await envoyerMessage(
        cotisationId: cotisationId,
        senderName: "Bot IA",
        message: "$myName a rejoint la cotisation.",
      );
    } catch (_) {}

    return cotisationId;
  }

  /// Migration / Remplissage automatique des noms et numéros manquants dans une cotisation
  Future<void> migrerNomsMembres(String cotisationId, List<dynamic> members) async {
    try {
      final cotRef = _db.collection('cotisations').doc(cotisationId);
      final cotSnap = await cotRef.get();
      if (!cotSnap.exists) return;

      final cotData = cotSnap.data();
      final membersInfo = Map<String, dynamic>.from(cotData?['membersInfo'] ?? {});
      bool needsUpdate = false;

      for (final memberObj in members) {
        final memberId = memberObj.toString();
        final currentInfo = membersInfo[memberId] as Map<String, dynamic>?;

        if (currentInfo == null || currentInfo['name'] == null || currentInfo['name'].toString().contains('Membre')) {
          final userSnap = await _db.collection('users').doc(memberId).get();
          if (userSnap.exists) {
            final uData = userSnap.data();
            final name = uData?['name'] as String?;
            final phone = uData?['phone'] as String?;
            if (name != null && name.isNotEmpty && !name.contains('Membre')) {
              membersInfo[memberId] = {
                'name': name,
                'phone': phone ?? "+225 -- -- -- --",
              };
              needsUpdate = true;
            }
          }
        }
      }

      if (needsUpdate) {
        await cotRef.update({'membersInfo': membersInfo});
      }
    } catch (_) {}
  }

  /// Écoute les détails d'une cotisation
  Stream<DocumentSnapshot<Map<String, dynamic>>> ecouterCotisation(String cotisationId) {
    return _db.collection('cotisations').doc(cotisationId).snapshots();
  }

  /// Soumet une déclaration de versement par un membre (statut pending)
  Future<void> soumettreDeclarationVersement({
    required String cotisationId,
    required String memberName,
    required double amount,
    required String paymentMethod,
    required String period,
    String? transactionRef,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");

    final cotRef = _db.collection('cotisations').doc(cotisationId);

    final txnDoc = cotRef.collection('transactions').doc();
    await txnDoc.set({
      'cotisationId': cotisationId,
      'memberId': user.uid,
      'memberName': memberName,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'period': period,
      'transactionRef': transactionRef ?? txnDoc.id,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await envoyerMessage(
      cotisationId: cotisationId,
      senderName: "Bot IA",
      message: "$memberName a déclaré un versement de ${amount.toInt()} FCFA ($paymentMethod) pour $period. En attente de validation par le trésorier.",
    );
  }

  /// Validation d'un versement déclaré par le trésorier
  Future<void> validerVersementTresorier({
    required String cotisationId,
    required String transactionId,
    required String memberId,
    required String memberName,
    required double amount,
    required String paymentMethod,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");

    final cotRef = _db.collection('cotisations').doc(cotisationId);
    final cotSnap = await cotRef.get();

    if (!cotSnap.exists || cotSnap.data()?['ownerId'] != user.uid) {
      throw Exception("Seul le trésorier est autorisé à valider les versements.");
    }

    await cotRef.collection('transactions').doc(transactionId).update({
      'status': 'verified',
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': user.uid,
    });

    await cotRef.update({
      'paid': FieldValue.arrayUnion([memberId]),
    });

    await envoyerMessage(
      cotisationId: cotisationId,
      senderName: "Bot IA",
      message: "Le trésorier a confirmé la réception du versement de $memberName (${amount.toInt()} FCFA via $paymentMethod).",
    );
  }

  /// Rejet d'un versement non reçu par le trésorier
  Future<void> rejeterVersementTresorier({
    required String cotisationId,
    required String transactionId,
    required String memberName,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");

    final cotRef = _db.collection('cotisations').doc(cotisationId);
    final cotSnap = await cotRef.get();

    if (!cotSnap.exists || cotSnap.data()?['ownerId'] != user.uid) {
      throw Exception("Seul le trésorier est autorisé à rejeter les versements.");
    }

    await cotRef.collection('transactions').doc(transactionId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': user.uid,
    });

    await envoyerMessage(
      cotisationId: cotisationId,
      senderName: "Bot IA",
      message: "Le versement déclaré par $memberName n'a pas été confirmé par le trésorier.",
    );
  }

  /// Ajoute une dépense à la cotisation
  Future<void> ajouterDepense({
    required String cotisationId,
    required String title,
    required double amount,
    required String category,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('expenses')
        .add({
      'title': title,
      'amount': amount,
      'category': category,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await envoyerMessage(
      cotisationId: cotisationId,
      senderName: "Bot IA",
      message: "Nouvelle dépense ajoutée : $title ($amount FCFA)",
    );
  }

  /// Écoute les dépenses de la cotisation
  Stream<QuerySnapshot<Map<String, dynamic>>> ecouterDepenses(String cotisationId) {
    return _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('expenses')
        .snapshots();
  }

  /// Écoute l'historique des transactions
  Stream<QuerySnapshot<Map<String, dynamic>>> ecouterTransactions(String cotisationId) {
    return _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('transactions')
        .snapshots();
  }

  /// Envoie un message avec support Réponse (Reply)
  Future<void> envoyerMessage({
    required String cotisationId,
    required String senderName,
    required String message,
    String? replyToSender,
    String? replyToText,
  }) async {
    final user = currentUser;

    final data = <String, dynamic>{
      'senderId': user?.uid ?? 'system',
      'senderName': senderName,
      'message': message,
      'isEdited': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (replyToSender != null && replyToText != null) {
      data['replyToSender'] = replyToSender;
      data['replyToText'] = replyToText;
    }

    await _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('messages')
        .add(data);
  }

  /// Modifie un message existant du membre
  Future<void> modifierMessage({
    required String cotisationId,
    required String messageId,
    required String newMessage,
  }) async {
    await _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'message': newMessage,
      'isEdited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime un message du membre
  Future<void> supprimerMessage({
    required String cotisationId,
    required String messageId,
  }) async {
    await _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  /// Clôture automatiquement la cotisation
  Future<void> cloturerCotisation(String cotisationId) async {
    await _db.collection('cotisations').doc(cotisationId).update({
      'statut': 'terminee',
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Écoute les messages de chat (ordonnés du plus ancien en haut au plus récent en bas)
  Stream<QuerySnapshot<Map<String, dynamic>>> ecouterMessages(String cotisationId) {
    return _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Met à jour l'état "en train d'écrire" dans le chat
  Future<void> mettreAJourSaisieChat({
    required String cotisationId,
    required String userName,
    required bool isTyping,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('typing')
        .doc(user.uid)
        .set({
      'userName': userName,
      'isTyping': isTyping,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Écoute les membres qui écrivent
  Stream<QuerySnapshot<Map<String, dynamic>>> ecouterMembresEnTrainDecrire(String cotisationId) {
    return _db
        .collection('cotisations')
        .doc(cotisationId)
        .collection('typing')
        .snapshots();
  }

  /// Écoute le profil d'un membre
  Stream<DocumentSnapshot<Map<String, dynamic>>> ecouterProfil(String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }
}
