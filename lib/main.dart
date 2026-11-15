/*
PROMPT SPÉCIFICATION PAIEMENT :
Dans l'écran de paiement, permets au membre de sélectionner :
Wave ; Orange Money ; MTN Mobile Money ; Moov Money.
Récupère le montant réellement dû, la période de cotisation, le numéro du trésorier et l'identifiant de la famille depuis les sources de données existantes. Ne code pas en dur de montants, de numéros ou d'identifiants fictifs.
Pour Orange Money, MTN et Moov Money, utilise openUssdMenu() pour tenter d'ouvrir le menu USSD correspondant. Appelle copyPaymentDetails() pour copier les informations utiles au membre.
Pour Wave, utilise prepareWaveTransfer() pour copier les détails du transfert. N'invente pas de deep link Wave non vérifié et n'affirme pas que le transfert est automatiquement prérempli ou effectué.
Après le retour du membre, propose une action « J'ai effectué le paiement ». Enregistre la déclaration dans Firebase avec le statut pending, en utilisant les collections et conventions existantes. Ne crée pas de doublons si une déclaration existe déjà pour la même cotisation.
Le statut ne doit passer à verified qu'après confirmation de la réception réelle des fonds par le trésorier autorisé. Un retour depuis Wave ou le composeur téléphonique ne constitue jamais une preuve de paiement.
Gère les erreurs, les permissions, les montants invalides, les doubles clics et les états de chargement. Affiche des messages en français clairs pour l'utilisateur.
Respecte les règles de sécurité Firebase existantes. Un membre ne doit jamais pouvoir valider lui-même son paiement. N'expose aucune clé secrète dans le code Flutter.
Ne refais pas les écrans déjà terminés. Réutilise le design, les widgets et les composants du projet.
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'firebase_options.dart';
import 'cagnote_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await initializeDateFormatting('fr_FR', null);
  } catch (_) {}
  runApp(const DibiFamilyApp());
}

class DibiFamilyApp extends StatelessWidget {
  const DibiFamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kota',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E9C4A),
          primary: const Color(0xFF2E9C4A),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  void _garantirProfilExistant(User user) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await docRef.get();
      final nameVal = snap.data()?['name'] as String?;
      final pinVal = snap.data()?['pinCode'] as String?;

      final randomPin = pinVal ?? (1000 + Random().nextInt(9000)).toString();

      if (!snap.exists || nameVal == null || nameVal.trim().isEmpty) {
        final name = (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : "Membre Dibi";
        final phone = (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
            ? user.phoneNumber!
            : "+225 07 00 00 00 00";

        await docRef.set({
          'name': name,
          'phone': phone,
          'pinCode': randomPin,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KotaLogoWidget(size: 90),
                  SizedBox(height: 24),
                  Text(
                    'KOTA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Color(0xFF2E9C4A),
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const PasswordlessAuthScreen();
        }

        _garantirProfilExistant(user);

        return const MainNavigationContainer();
      },
    );
  }
}

/// Widget Logo Officiel Dibi Family (Style Émeraude avec double D exact de l'image)
/// Widget Logo Officiel KOTA
class KotaLogoWidget extends StatelessWidget {
  final double size;
  const KotaLogoWidget({super.key, this.size = 90.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          'assets/images/kota_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _KotaKLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 1. Grande lettre K en Serif élégante, fine et moderne
    final stem = Path();
    stem.moveTo(w * 0.22, h * 0.20);
    stem.lineTo(w * 0.32, h * 0.20);
    stem.lineTo(w * 0.32, h * 0.82);
    stem.lineTo(w * 0.22, h * 0.82);
    stem.close();
    canvas.drawPath(stem, whitePaint);

    canvas.drawRect(Rect.fromLTWH(w * 0.16, h * 0.18, w * 0.20, h * 0.04), whitePaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.16, h * 0.80, w * 0.20, h * 0.04), whitePaint);

    final topBranch = Path();
    topBranch.moveTo(w * 0.30, h * 0.52);
    topBranch.lineTo(w * 0.58, h * 0.22);
    topBranch.lineTo(w * 0.70, h * 0.22);
    topBranch.lineTo(w * 0.40, h * 0.58);
    topBranch.close();
    canvas.drawPath(topBranch, whitePaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.62, h * 0.20, w * 0.14, h * 0.04), whitePaint);

    final bottomBranch = Path();
    bottomBranch.moveTo(w * 0.35, h * 0.48);
    bottomBranch.lineTo(w * 0.76, h * 0.82);
    bottomBranch.lineTo(w * 0.62, h * 0.82);
    bottomBranch.lineTo(w * 0.28, h * 0.54);
    bottomBranch.close();
    canvas.drawPath(bottomBranch, whitePaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.64, h * 0.80, w * 0.16, h * 0.04), whitePaint);

    // 2. Trois petites piles de pièces d'or qui montent en escalier
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    final goldShadow = Paint()
      ..color = const Color(0xFFC59B00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final p1 = Offset(w * 0.54, h * 0.34);
    canvas.drawCircle(p1, w * 0.065, goldPaint);
    canvas.drawCircle(p1, w * 0.065, goldShadow);

    final p2 = Offset(w * 0.65, h * 0.25);
    canvas.drawCircle(p2, w * 0.065, goldPaint);
    canvas.drawCircle(p2, w * 0.065, goldShadow);

    final p3 = Offset(w * 0.76, h * 0.16);
    canvas.drawCircle(p3, w * 0.065, goldPaint);
    canvas.drawCircle(p3, w * 0.065, goldShadow);

    // 3. Fine flèche dorée qui monte vers la droite (↗)
    final arrowPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final arrowPath = Path();
    arrowPath.moveTo(w * 0.48, h * 0.30);
    arrowPath.lineTo(w * 0.84, h * 0.06);

    arrowPath.moveTo(w * 0.84, h * 0.06);
    arrowPath.lineTo(w * 0.72, h * 0.06);
    arrowPath.moveTo(w * 0.84, h * 0.06);
    arrowPath.lineTo(w * 0.84, h * 0.18);

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ModernGoogleLogoWidget extends StatelessWidget {
  final double size;
  const ModernGoogleLogoWidget({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/images/google_logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const GoogleButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/google_g.svg',
              width: 22,
              height: 22,
            ),
            const SizedBox(width: 12),
            const Text(
              'Continuer avec Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JekoLogoWidget extends StatelessWidget {
  final double size;
  const JekoLogoWidget({super.key, this.size = 36.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF3B12A3),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.7,
          height: size * 0.7,
          child: CustomPaint(
            painter: _JekoLogoPainter(),
          ),
        ),
      ),
    );
  }
}

class _JekoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPaint = Paint()
      ..color = const Color(0xFF9E77ED)
      ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.35, h * 0.15, w * 0.55, h * 0.75),
      Radius.circular(w * 0.15),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    final cyanPaint = Paint()
      ..color = const Color(0xFF29B6F6)
      ..style = PaintingStyle.fill;

    final cyanPath = Path();
    cyanPath.moveTo(w * 0.6, h * 0.45);
    cyanPath.lineTo(w * 0.15, h * 0.45);
    cyanPath.arcToPoint(
      Offset(w * 0.15, h * 0.85),
      radius: Radius.circular(w * 0.3),
      clockwise: true,
    );
    cyanPath.lineTo(w * 0.6, h * 0.85);
    cyanPath.close();
    canvas.drawPath(cyanPath, cyanPaint);

    final whiteDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.65, h * 0.58), w * 0.12, whiteDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final blue = Paint()..color = const Color(0xFF4285F4);
    final green = Paint()..color = const Color(0xFF34A853);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final red = Paint()..color = const Color(0xFFEA4335);

    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, -0.8, 1.8, true, red);
    canvas.drawArc(rect, 1.0, 1.0, true, yellow);
    canvas.drawArc(rect, 2.0, 1.2, true, green);
    canvas.drawArc(rect, 3.2, 1.2, true, blue);

    final innerCutout = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, innerCutout);

    final barRect = Rect.fromLTRB(w * 0.45, h * 0.38, w, h * 0.62);
    canvas.drawRect(barRect, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Écran d'inscription & Connexion par Nom/Numéro ou Google
class PasswordlessAuthScreen extends StatefulWidget {
  const PasswordlessAuthScreen({super.key});

  @override
  State<PasswordlessAuthScreen> createState() => _PasswordlessAuthScreenState();
}

class _PasswordlessAuthScreenState extends State<PasswordlessAuthScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  /// Inscription & Connexion directe par Nom & Numéro
  Future<void> _seConnecterParTelephone() async {
    final phoneText = _phoneController.text.trim();
    final cleanPhone = phoneText.replaceAll(RegExp(r'\D'), '');
    final isValidPrefix = cleanPhone.startsWith('07') ||
        cleanPhone.startsWith('05') ||
        cleanPhone.startsWith('01');

    if (cleanPhone.length != 10 || !isValidPrefix) {
      setState(() {
        _error = 'Veuillez entrer un numéro de téléphone valide à 10 chiffres (07, 05, 01)';
      });
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Veuillez entrer votre nom complet';
      });
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    final fullPhoneNumber = "+225$cleanPhone";

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      await CagnoteRepository().enregistrerProfil(
        name: name,
        phone: fullPhoneNumber,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion : $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Connexion directe via Google Sign-In avec extraction du téléphone
  Future<void> _seConnecterAvecGoogle() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      if (googleAuth == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        final name = (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : (_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "Membre Google");

        String phone = user.phoneNumber ?? '';
        if (phone.isEmpty) {
          final typedPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
          if (typedPhone.length == 10) {
            phone = "+225$typedPhone";
          } else {
            phone = "+225 07 -- -- -- --";
          }
        }

        await CagnoteRepository().enregistrerProfil(
          name: name,
          phone: phone,
          photoUrl: user.photoURL,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erreur de connexion Google : $e";
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const KotaLogoWidget(size: 90),
                  const SizedBox(height: 24),
                  const Text(
                    'Bienvenue sur KOTA',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Connectez-vous avec votre nom et votre numéro ou via Google',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13.5, height: 1.3),
                  ),
                  const SizedBox(height: 36),

                  // Champ Nom
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nom complet',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Ex: Kouassi Jean',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Champ Numéro
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Numéro de téléphone',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFEFEF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text(
                                '+225',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: InputDecoration(
                                hintText: '0712345678',
                                counterText: '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF5F5F5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
                  ],

                  const SizedBox(height: 32),

                  _isLoading
                      ? const CircularProgressIndicator(color: Color(0xFF2E9C4A))
                      : Column(
                          children: [
                            ElevatedButton(
                              onPressed: _seConnecterParTelephone,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E9C4A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Se connecter',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey[300])),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text("OU", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                Expanded(child: Divider(color: Colors.grey[300])),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GoogleButton(
                              onTap: _isLoading ? () {} : _seConnecterAvecGoogle,
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

/// Conteneur de Navigation Principal
class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  String? _selectedCotisationId;

  @override
  Widget build(BuildContext context) {
    if (_selectedCotisationId != null) {
      return ActiveCagnoteDashboard(
        cotisationId: _selectedCotisationId!,
        onBack: () {
          setState(() {
            _selectedCotisationId = null;
          });
        },
      );
    }

    return MesCotisationsScreen(
      onSelectCotisation: (id) {
        setState(() {
          _selectedCotisationId = id;
        });
      },
    );
  }
}

/// Écran d'accueil : Mes Cotisations
class MesCotisationsScreen extends StatelessWidget {
  final Function(String) onSelectCotisation;

  const MesCotisationsScreen({super.key, required this.onSelectCotisation});

  @override
  Widget build(BuildContext context) {
    final repo = CagnoteRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Cotisations', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Déconnexion',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.ecouterMesCotisations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2E9C4A)));
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 60, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Accès Firebase Refusé (Permission Denied)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Les règles de sécurité de votre projet Firebase Firestore bloquent la requête.\n\nDans la console Firebase (Firestore Database > Rules), autorisez la lecture/écriture :',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'allow read, write: if request.auth != null;',
                        style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateCotisationScreen()),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Créer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E9C4A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const JoinCotisationScreen()),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Rejoindre'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E9C4A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return EmptyCotisationsScreen(
              onCreateClick: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateCotisationScreen()),
                );
              },
              onJoinClick: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinCotisationScreen()),
                );
              },
            );
          }

          return Column(
            children: [
              // En-tête avec actions rapides
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateCotisationScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text('Créer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E9C4A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const JoinCotisationScreen()),
                          );
                        },
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        label: const Text('Rejoindre'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E9C4A),
                          side: const BorderSide(color: Color(0xFF2E9C4A), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Liste des cotisations
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final id = doc.id;
                    final name = data['name'] ?? 'Cotisation';
                    final target = (data['montantTotal'] ?? 0.0).toDouble();
                    final monthly = (data['sommeParMembre'] ?? 0.0).toDouble();
                    final members = (data['members'] as List?)?.length ?? 1;
                    final paidList = (data['paid'] as List?) ?? [];
                    final isOwner = data['ownerId'] == repo.currentUser?.uid;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1.5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSelectCotisation(id),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOwner ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isOwner ? 'Trésorier' : 'Membre',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isOwner ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.people_alt_outlined, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text('$members membre(s)', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                  const Spacer(),
                                  Text(
                                    '${monthly.toInt()} FCFA / mois',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E9C4A)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: target > 0 ? (paidList.length * monthly / target).clamp(0.0, 1.0) : 0,
                                  backgroundColor: Colors.grey[200],
                                  color: const Color(0xFF2E9C4A),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Écran Zéro Cotisation
class EmptyCotisationsScreen extends StatelessWidget {
  final VoidCallback onCreateClick;
  final VoidCallback onJoinClick;

  const EmptyCotisationsScreen({
    super.key,
    required this.onCreateClick,
    required this.onJoinClick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet, size: 64, color: Color(0xFF2E9C4A)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucune cotisation active',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Créez une cagnote pour votre famille ou rejoignez une cotisation existante',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: onCreateClick,
              icon: const Icon(Icons.add),
              label: const Text('Créer une cotisation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E9C4A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onJoinClick,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner ou Rejoindre'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E9C4A),
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: Color(0xFF2E9C4A), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Écran Créer une cotisation
class CreateCotisationScreen extends StatefulWidget {
  const CreateCotisationScreen({super.key});

  @override
  State<CreateCotisationScreen> createState() => _CreateCotisationScreenState();
}

class _CreateCotisationScreenState extends State<CreateCotisationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _monthlyController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final target = double.parse(_targetController.text.trim());
      final monthly = double.parse(_monthlyController.text.trim());

      final id = await CagnoteRepository().creerCotisation(
        name: name,
        targetAmount: target,
        monthlyAmount: monthly,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création : $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une cotisation', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la cotisation',
                  hintText: 'Ex: Maison Familiale Dabou',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nom obligatoire' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Objectif financier total (FCFA)',
                  hintText: 'Ex: 500000',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => double.tryParse(val ?? '') == null ? 'Montant invalide' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _monthlyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant mensuel par membre (FCFA)',
                  hintText: 'Ex: 20000',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => double.tryParse(val ?? '') == null ? 'Montant invalide' : null,
              ),
              const SizedBox(height: 36),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E9C4A)))
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E9C4A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Créer la cotisation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }
}

/// Formateur personnalisé pour la saisie automatique du code DIBI-XXX-YYY en majuscules
class CotisationCodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.toUpperCase();
    String clean = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (clean.length > 10) {
      clean = clean.substring(0, 10);
    }

    if (clean.isNotEmpty && RegExp(r'^[0-9]').hasMatch(clean)) {
      clean = 'DIBI$clean';
      if (clean.length > 10) clean = clean.substring(0, 10);
    }

    String formatted = '';
    for (int i = 0; i < clean.length; i++) {
      if (i == 4 || i == 7) {
        formatted += '-';
      }
      formatted += clean[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Écran Rejoindre une cotisation
class JoinCotisationScreen extends StatefulWidget {
  const JoinCotisationScreen({super.key});

  @override
  State<JoinCotisationScreen> createState() => _JoinCotisationScreenState();
}

class _JoinCotisationScreenState extends State<JoinCotisationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _rejoindreManuellement() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final id = await CagnoteRepository().rejoindreParCode(code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SuccessJoinScreen(cotisationId: id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejoindre une cotisation', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.qr_code_scanner, color: Color(0xFF2E9C4A)),
                ),
                title: const Text('Scanner un QR code', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Scannez le code QR partagé par le trésorier'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final scannedCode = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanQrScreen()),
                  );
                  if (scannedCode != null && mounted) {
                    try {
                      final id = await CagnoteRepository().rejoindreParCode(scannedCode);
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => SuccessJoinScreen(cotisationId: id)),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OU', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [CotisationCodeInputFormatter()],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 18,
                color: Color(0xFF2E9C4A),
              ),
              decoration: InputDecoration(
                labelText: 'Code de cotisation',
                hintText: 'Ex: DIBI-123-456',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E9C4A)))
                : ElevatedButton(
                    onPressed: _rejoindreManuellement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E9C4A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Rejoindre par code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}

/// Écran Scan QR Code
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner le QR Code", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.amber);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        "Autorisation Caméra Requise",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Veuillez autoriser l'accès à la caméra dans les paramètres de votre téléphone pour scanner les QR codes.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => controller.start(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E9C4A)),
                        child: const Text("Réessayer"),
                      ),
                    ],
                  ),
                ),
              );
            },
            onDetect: (capture) {
              if (_isScanned) return;
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _isScanned = true;
                  Navigator.pop(context, code.trim().toUpperCase());
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2E9C4A), width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Text(
              "Placez le QR Code à l'intérieur du cadre",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// Écran Succès Jonction
class SuccessJoinScreen extends StatelessWidget {
  final String cotisationId;

  const SuccessJoinScreen({super.key, required this.cotisationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: CagnoteRepository().ecouterCotisation(cotisationId),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final name = data?['name'] ?? 'la cotisation';
          final monthly = (data?['sommeParMembre'] ?? 0.0).toDouble();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, size: 80, color: Color(0xFF2E9C4A)),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Bienvenue dans\n$name !',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Vous avez rejoint cette cotisation avec succès.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    if (monthly > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Cotisation : ${monthly.toInt()} FCFA / mois',
                          style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E9C4A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Accéder à la cotisation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dashboard Cotisation Active (avec 4 Onglets)
class ActiveCagnoteDashboard extends StatefulWidget {
  final String cotisationId;
  final VoidCallback onBack;

  const ActiveCagnoteDashboard({
    super.key,
    required this.cotisationId,
    required this.onBack,
  });

  @override
  State<ActiveCagnoteDashboard> createState() => _ActiveCagnoteDashboardState();
}

class _ActiveCagnoteDashboardState extends State<ActiveCagnoteDashboard> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final repo = CagnoteRepository();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.ecouterCotisation(widget.cotisationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2E9C4A))));
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Erreur')),
            body: const Center(child: Text("Cotisation introuvable")),
          );
        }

        final cagnoteName = data['name'] ?? 'Cotisation';
        final ownerId = data['ownerId'] ?? '';
        final isTreasurer = ownerId == repo.currentUser?.uid;
        final inviteCode = data['inviteCode'] ?? '';
        final target = (data['montantTotal'] ?? 0.0).toDouble();
        final monthly = (data['sommeParMembre'] ?? 0.0).toDouble();
        final membersRaw = data['members'] as List? ?? [];
        final paidRaw = data['paid'] as List? ?? [];

        // Rétro-migration automatique en arrière-plan pour réparer les anciens noms "Membre"
        repo.migrerNomsMembres(widget.cotisationId, membersRaw);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
            ),
            title: Text(cagnoteName, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_2, color: Color(0xFF2E9C4A)),
                tooltip: 'Partager',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => ShareCotisationBottomSheet(
                      inviteCode: inviteCode,
                      cagnoteName: cagnoteName,
                    ),
                  );
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedTab,
            children: [
              // Onglet 0: Membres & Cotisations
              OverviewTab(
                cotisationId: widget.cotisationId,
                cagnoteName: cagnoteName,
                targetAmount: target,
                monthlyAmount: monthly,
                isTreasurer: isTreasurer,
                ownerId: ownerId,
                members: membersRaw,
                paidList: paidRaw,
                inviteCode: inviteCode,
              ),

              // Onglet 1: Dépenses
              ExpensesTab(
                cotisationId: widget.cotisationId,
                isTreasurer: isTreasurer,
              ),

              // Onglet 2: Transactions
              TransactionsTab(
                cotisationId: widget.cotisationId,
              ),

              // Onglet 3: Discussion / Chat
              ChatTab(
                cotisationId: widget.cotisationId,
              ),

              // Onglet 4: Profil
              const ProfilTab(),
            ],
          ),
          bottomNavigationBar: ModernBottomNavigationBar(
            selectedTab: _selectedTab,
            onTabSelected: (index) {
              setState(() => _selectedTab = index);
            },
          ),
        );
      },
    );
  }
}

/// Onglet Aperçu & Membres
class OverviewTab extends StatelessWidget {
  final String cotisationId;
  final String cagnoteName;
  final double targetAmount;
  final double monthlyAmount;
  final bool isTreasurer;
  final String ownerId;
  final List<dynamic> members;
  final List<dynamic> paidList;
  final String inviteCode;

  const OverviewTab({
    super.key,
    required this.cotisationId,
    required this.cagnoteName,
    required this.targetAmount,
    required this.monthlyAmount,
    required this.isTreasurer,
    required this.ownerId,
    required this.members,
    required this.paidList,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    final repo = CagnoteRepository();
    final totalCollected = paidList.length * monthlyAmount;
    final isTargetReached = totalCollected >= targetAmount && targetAmount > 0;
    final progress = targetAmount > 0 ? (totalCollected / targetAmount).clamp(0.0, 1.0) : 0.0;
    final currentUserPaid = paidList.contains(repo.currentUser?.uid);

    if (isTargetReached) {
      repo.cloturerCotisation(cotisationId);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'Animation & Félicitations quand l'objectif est atteint
        if (isTargetReached) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E9C4A), Color(0xFF1B5E20)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.amber, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎉 FÉLICITATIONS ! 🎉',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'L\'objectif de ${targetAmount.toInt()} FCFA a été atteint ! La cotisation est désormais clôturée.',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Carte de Solde
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 2,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Solde actuellement collecté', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                      child: Text(isTargetReached ? 'Clôturée' : 'Actif', style: TextStyle(color: isTargetReached ? Colors.orange[800] : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${totalCollected.toInt()} FCFA',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    color: const Color(0xFF2E9C4A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Objectif : ${targetAmount.toInt()} FCFA • Mensuel : ${monthlyAmount.toInt()} FCFA / membre',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Boutons d'action
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: currentUserPaid
                    ? null
                    : () {
                        _afficherPaiementModal(context);
                      },
                icon: const Icon(Icons.payment),
                label: Text(currentUserPaid ? 'Cotisation réglée' : 'Payer ma cotisation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E9C4A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                final link = 'dibifamily://join?code=$inviteCode';
                Share.share(
                  '🔔 *Rappel Cotisation Dibi Family* 🔔\n\n'
                  'Bonjour ! Pensez à régler votre versement pour la cagnotte "*$cagnoteName*".\n\n'
                  '📌 Code de la cagnotte : *$inviteCode*\n\n'
                  '📲 Cliquez sur le lien ci-dessous pour ouvrir l\'application Dibi Family :\n'
                  '$link'
                );
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Relancer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E9C4A),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _genererEtPartagerRapportPdf(
            cagnoteName: cagnoteName,
            targetAmount: targetAmount,
            totalCollected: totalCollected,
            members: members,
            paidList: paidList,
          ),
          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
          label: const Text('Télécharger le rapport financier (PDF)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B5C3F),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 24),

        const Text('Membres de la cotisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Liste des membres avec double vérification (données embarquées + profil live)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final memberId = members[index].toString();
            final isMe = memberId == repo.currentUser?.uid;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: repo.ecouterCotisation(cotisationId),
              builder: (context, cotSnapshot) {
                final cotData = cotSnapshot.data?.data();
                final membersInfo = cotData?['membersInfo'] as Map<String, dynamic>?;
                final memberEmbedded = membersInfo?[memberId] as Map<String, dynamic>?;

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: repo.ecouterProfil(memberId),
                  builder: (context, snapshot) {
                    final memberData = snapshot.data?.data();
                    final name = (memberData?['name'] as String?) ??
                        (memberEmbedded?['name'] as String?) ??
                        (isMe ? "Moi" : "Membre ${index + 1}");
                    final phone = (memberData?['phone'] as String?) ??
                        (memberEmbedded?['phone'] as String?) ??
                        "+225 -- -- -- --";
                    final photoUrl = (memberData?['photoUrl'] as String?) ??
                        (memberEmbedded?['photoUrl'] as String?);
                    final isPaid = paidList.contains(memberId);
                    final isMemberTreasurer = memberId == ownerId;

                    final hasValidImage = photoUrl != null && photoUrl.isNotEmpty && File(photoUrl).existsSync();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE8F5E9),
                          backgroundImage: hasValidImage ? FileImage(File(photoUrl)) : null,
                          child: !hasValidImage
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                  style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 16),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMemberTreasurer) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFB300), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 12, color: Color(0xFFFF8F00)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Trésorier',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            phone,
                            style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isPaid ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isPaid ? 'Payé' : 'En retard',
                            style: TextStyle(
                              color: isPaid ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _afficherPaiementModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PaymentModalSheet(
        cotisationId: cotisationId,
        cagnoteName: cagnoteName,
        monthlyAmount: monthlyAmount,
        targetAmount: targetAmount,
        ownerId: ownerId,
      ),
    );
  }
}

/// Onglet Dépenses
class ExpensesTab extends StatelessWidget {
  final String cotisationId;
  final bool isTreasurer;

  const ExpensesTab({
    super.key,
    required this.cotisationId,
    required this.isTreasurer,
  });

  @override
  Widget build(BuildContext context) {
    final repo = CagnoteRepository();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: repo.ecouterDepenses(cotisationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2E9C4A)));
        }

        final docs = snapshot.data?.docs ?? [];

        return Scaffold(
          body: docs.isEmpty
              ? const Center(
                  child: Text('Aucune dépense enregistrée', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final title = data['title'] ?? 'Dépense';
                    final amount = (data['amount'] ?? 0.0).toDouble();
                    final category = data['category'] ?? 'Général';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFEBEE),
                          child: Icon(Icons.money_off, color: Colors.red),
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(category),
                        trailing: Text(
                          '-${amount.toInt()} FCFA',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: isTreasurer
              ? FloatingActionButton.extended(
                  onPressed: () => _ajouterDepenseModal(context),
                  backgroundColor: const Color(0xFF2E9C4A),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle Dépense'),
                )
              : null,
        );
      },
    );
  }

  void _ajouterDepenseModal(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ajouter une dépense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre (Ex: Achat Briques)')),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant FCFA')),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Catégorie (Ex: Travaux)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                final cat = categoryCtrl.text.trim();

                if (title.isNotEmpty && amount > 0) {
                  await CagnoteRepository().ajouterDepense(
                    cotisationId: cotisationId,
                    title: title,
                    amount: amount,
                    category: cat.isEmpty ? "Général" : cat,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E9C4A)),
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }
}

/// Onglet Transactions / Historique avec validation du Trésorier
class TransactionsTab extends StatelessWidget {
  final String cotisationId;

  const TransactionsTab({super.key, required this.cotisationId});

  @override
  Widget build(BuildContext context) {
    final repo = CagnoteRepository();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.ecouterCotisation(cotisationId),
      builder: (context, cotSnap) {
        final cotData = cotSnap.data?.data();
        final ownerId = cotData?['ownerId'] ?? '';
        final isTreasurer = ownerId == repo.currentUser?.uid;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repo.ecouterTransactions(cotisationId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF2E9C4A)));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text('Aucune transaction enregistrée', style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final txnId = doc.id;
                final memberId = data['memberId'] as String? ?? '';
                final memberName = data['memberName'] as String? ?? 'Membre';
                final amount = (data['amount'] ?? 0.0).toDouble();
                final method = data['paymentMethod'] as String? ?? 'Mobile Money';
                final period = data['period'] as String? ?? '';
                final status = data['status'] as String? ?? 'verified';
                final timestamp = data['createdAt'] as Timestamp?;
                final dateStr = timestamp != null
                    ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
                    : 'Récemment';

                Color statusColor = const Color(0xFF2E7D32);
                String statusLabel = 'Confirmé';
                if (status == 'pending') {
                  statusColor = Colors.orange[800]!;
                  statusLabel = 'En attente trésorier';
                } else if (status == 'rejected') {
                  statusColor = Colors.red;
                  statusLabel = 'Rejeté';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('$method ${period.isNotEmpty ? "• $period" : ""} • $dateStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '+${amount.toInt()} FCFA',
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            if (isTreasurer && status == 'pending') ...[
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () async {
                                      await repo.rejeterVersementTresorier(
                                        cotisationId: cotisationId,
                                        transactionId: txnId,
                                        memberName: memberName,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Rejeter'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await repo.validerVersementTresorier(
                                        cotisationId: cotisationId,
                                        transactionId: txnId,
                                        memberId: memberId,
                                        memberName: memberName,
                                        amount: amount,
                                        paymentMethod: method,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E9C4A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Valider'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Widget d'animation des 3 points de suspension en mouvement quand un membre écrit
class MovingDotsTypingIndicator extends StatefulWidget {
  const MovingDotsTypingIndicator({super.key});

  @override
  State<MovingDotsTypingIndicator> createState() => _MovingDotsTypingIndicatorState();
}

class _MovingDotsTypingIndicatorState extends State<MovingDotsTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.25;
            final double animVal = (val - delay) % 1.0;
            final opacity = (sin(animVal * 2 * pi) + 1) / 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: const Color(0xFF2E9C4A).withOpacity(0.3 + (opacity * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Onglet Discussion / Chat complet : Reply, Edit, Delete, Mentions (@), Clôture
class ChatTab extends StatefulWidget {
  final String cotisationId;

  const ChatTab({super.key, required this.cotisationId});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  Timer? _typingTimer;
  String _currentUserName = "Moi";

  // Réponse à un message (Reply)
  String? _replyToSender;
  String? _replyToText;

  // Modification d'un message (Edit)
  String? _editingMessageId;

  // Autocomplete Mentions (@)
  bool _showMentionsOverlay = false;
  String _mentionQuery = '';

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final repo = CagnoteRepository();
    final user = repo.currentUser;
    if (user != null) {
      repo.ecouterProfil(user.uid).first.then((snap) {
        final name = snap.data()?['name'] as String?;
        if (name != null && name.isNotEmpty && mounted) {
          setState(() {
            _currentUserName = name;
          });
        }
      });
    }

    _msgController.addListener(() {
      final text = _msgController.text;
      final isNotEmpty = text.trim().isNotEmpty;

      // Détection de la mention @
      final selection = _msgController.selection;
      if (selection.baseOffset > 0) {
        final textBeforeCursor = text.substring(0, selection.baseOffset);
        final lastAtIndex = textBeforeCursor.lastIndexOf('@');
        if (lastAtIndex != -1 && (lastAtIndex == 0 || textBeforeCursor[lastAtIndex - 1] == ' ')) {
          final query = textBeforeCursor.substring(lastAtIndex + 1);
          if (!query.contains(' ')) {
            setState(() {
              _showMentionsOverlay = true;
              _mentionQuery = query.toLowerCase();
            });
          } else {
            if (_showMentionsOverlay) setState(() => _showMentionsOverlay = false);
          }
        } else {
          if (_showMentionsOverlay) setState(() => _showMentionsOverlay = false);
        }
      } else {
        if (_showMentionsOverlay) setState(() => _showMentionsOverlay = false);
      }

      if (isNotEmpty != _isTyping) {
        _isTyping = isNotEmpty;
        repo.mettreAJourSaisieChat(
          cotisationId: widget.cotisationId,
          userName: _currentUserName,
          isTyping: isNotEmpty,
        );
        _scrollToBottom();
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isTyping) {
          _isTyping = false;
          repo.mettreAJourSaisieChat(
            cotisationId: widget.cotisationId,
            userName: _currentUserName,
            isTyping: false,
          );
        }
      });
    });
  }

  void _envoyer() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final repo = CagnoteRepository();

    if (_editingMessageId != null) {
      repo.modifierMessage(
        cotisationId: widget.cotisationId,
        messageId: _editingMessageId!,
        newMessage: text,
      );
      setState(() {
        _editingMessageId = null;
        _msgController.clear();
      });
    } else {
      repo.envoyerMessage(
        cotisationId: widget.cotisationId,
        senderName: _currentUserName,
        message: text,
        replyToSender: _replyToSender,
        replyToText: _replyToText,
      );

      _msgController.clear();
      setState(() {
        _isTyping = false;
        _replyToSender = null;
        _replyToText = null;
        _showMentionsOverlay = false;
      });

      repo.mettreAJourSaisieChat(
        cotisationId: widget.cotisationId,
        userName: _currentUserName,
        isTyping: false,
      );
    }
    _scrollToBottom();
  }

  void _afficherOptionsMessage({
    required String messageId,
    required String senderName,
    required String messageText,
    required bool isMe,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF2E9C4A)),
              title: const Text('Répondre'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _replyToSender = senderName;
                  _replyToText = messageText;
                });
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Modifier le message'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editingMessageId = messageId;
                    _msgController.text = messageText;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer le message', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await CagnoteRepository().supprimerMessage(
                    cotisationId: widget.cotisationId,
                    messageId: messageId,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _insererMention(String name) {
    final text = _msgController.text;
    final selection = _msgController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex != -1) {
      final newText = text.substring(0, lastAtIndex) + "@$name " + text.substring(selection.baseOffset);
      _msgController.text = newText;
      _msgController.selection = TextSelection.collapsed(offset: lastAtIndex + name.length + 2);
    }
    setState(() => _showMentionsOverlay = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = CagnoteRepository();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.ecouterCotisation(widget.cotisationId),
      builder: (context, cotSnap) {
        final cotData = cotSnap.data?.data();
        final isClosed = cotData?['statut'] == 'terminee';
        final membersListRaw = cotData?['members'] as List? ?? [];

        return Column(
          children: [
            // Bandeau si la cotisation est clôturée
            if (isClosed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: const Color(0xFFFFF3E0),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_clock, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Cette cotisation est terminée. Le chat est clos.',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: repo.ecouterMessages(widget.cotisationId),
                builder: (context, msgSnapshot) {
                  if (msgSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF2E9C4A)));
                  }

                  final msgDocs = msgSnapshot.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: repo.ecouterMembresEnTrainDecrire(widget.cotisationId),
                    builder: (context, typingSnapshot) {
                      final typingDocs = typingSnapshot.data?.docs ?? [];
                      final myUid = repo.currentUser?.uid;

                      // Seuls LES AUTRES membres qui écrivent (exclut soi-même)
                      final otherTypingUsers = typingDocs.where((doc) {
                        final isMe = doc.id == myUid;
                        final isTyping = doc.data()['isTyping'] as bool? ?? false;
                        return !isMe && isTyping;
                      }).toList();

                      _scrollToBottom();

                      final totalItemCount = msgDocs.length + otherTypingUsers.length;

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: totalItemCount,
                        itemBuilder: (context, index) {
                          // Membres en train d'écrire (affichés uniquement aux autres)
                          if (index >= msgDocs.length) {
                            final typingUserDoc = otherTypingUsers[index - msgDocs.length].data();
                            final typingUserName = typingUserDoc['userName'] as String? ?? 'Un membre';

                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFA5D6A7)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      typingUserName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const MovingDotsTypingIndicator(),
                                  ],
                                ),
                              ),
                            );
                          }

                          final doc = msgDocs[index];
                          final data = doc.data();
                          final msgId = doc.id;
                          final sender = data['senderName'] as String? ?? 'Membre';
                          final msg = data['message'] as String? ?? '';
                          final replySender = data['replyToSender'] as String?;
                          final replyText = data['replyToText'] as String?;
                          final isEdited = data['isEdited'] as bool? ?? false;
                          final isBot = sender == 'Bot IA';
                          final isMe = data['senderId'] == repo.currentUser?.uid;

                          if (isBot) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '🤖 $msg',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w500),
                              ),
                            );
                          }

                          // Message de chat interactif (Tap pour options)
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () => _afficherOptionsMessage(
                                messageId: msgId,
                                senderName: sender,
                                messageText: msg,
                                isMe: isMe,
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFF2E9C4A) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sender,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isMe ? Colors.white70 : const Color(0xFF2E7D32),
                                      ),
                                    ),
                                    if (replySender != null && replyText != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.black.withOpacity(0.12) : const Color(0xFFF1F8E9),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border(left: BorderSide(color: isMe ? Colors.white : const Color(0xFF2E9C4A), width: 3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              replySender,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                                color: isMe ? Colors.white : const Color(0xFF2E7D32),
                                              ),
                                            ),
                                            Text(
                                              replyText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isMe ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      msg,
                                      style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14, height: 1.3),
                                    ),
                                    if (isEdited) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '(modifié)',
                                        style: TextStyle(color: isMe ? Colors.white60 : Colors.grey, fontSize: 9, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // Autocomplete Overlay Mentions (@)
            if (_showMentionsOverlay && !isClosed)
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                color: Colors.white,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: membersListRaw.length,
                  itemBuilder: (context, idx) {
                    final memberUid = membersListRaw[idx].toString();
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: repo.ecouterProfil(memberUid),
                      builder: (context, snap) {
                        final mData = snap.data?.data();
                        final mName = mData?['name'] as String? ?? 'Membre';
                        final mPhone = mData?['phone'] as String? ?? '';

                        if (_mentionQuery.isNotEmpty && !mName.toLowerCase().contains(_mentionQuery)) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.alternate_email, size: 18, color: Color(0xFF2E9C4A)),
                          title: Text(mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(mPhone, style: const TextStyle(fontSize: 11)),
                          onTap: () => _insererMention(mName),
                        );
                      },
                    );
                  },
                ),
              ),

            // Barre de Réponse si active
            if (_replyToSender != null && !isClosed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFE8F5E9),
                child: Row(
                  children: [
                    const Icon(Icons.reply, color: Color(0xFF2E9C4A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Réponse à ${_replyToSender!}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2E7D32))),
                          Text(_replyToText ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _replyToSender = null;
                        _replyToText = null;
                      }),
                    ),
                  ],
                ),
              ),

            // Barre de Saisie du Message
            if (!isClosed)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        decoration: InputDecoration(
                          hintText: _editingMessageId != null ? 'Modifier le message...' : 'Écrire un message (@ pour mentionner)...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_editingMessageId != null ? Icons.check : Icons.send, color: const Color(0xFF2E9C4A)),
                      onPressed: _envoyer,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }
}

/// Feuille de Partage QR Code
class ShareCotisationBottomSheet extends StatelessWidget {
  final String inviteCode;
  final String cagnoteName;

  const ShareCotisationBottomSheet({
    super.key,
    required this.inviteCode,
    required this.cagnoteName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cagnoteName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Faites scanner ce QR Code pour ajouter un membre', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          QrImageView(
            data: inviteCode,
            version: QrVersions.auto,
            size: 200.0,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF2E9C4A),
            ),
          ),
          const SizedBox(height: 16),
          Text(inviteCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Share.share('Rejoins ma cotisation "$cagnoteName" sur Dibi Family avec le code : $inviteCode');
            },
            icon: const Icon(Icons.share),
            label: const Text('Partager le code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E9C4A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglet Profil complet & interactif
class ProfilTab extends StatefulWidget {
  const ProfilTab({super.key});

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  final _picker = ImagePicker();

  Future<void> _changerPhoto(String currentName, String currentPhone) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (image != null) {
        await CagnoteRepository().enregistrerProfil(
          name: currentName,
          phone: currentPhone,
          photoUrl: image.path,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo de profil mise à jour avec succès !')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du choix de l\'image : $e')),
        );
      }
    }
  }

  void _modifierProfilDialog(BuildContext context, String currentName, String currentPhone, String? currentPhotoUrl) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone.replaceAll('+225', '').trim());
    String? localPhotoUrl = currentPhotoUrl;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasImg = localPhotoUrl != null && localPhotoUrl!.isNotEmpty && File(localPhotoUrl!).existsSync();
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Modifier mon profil', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final XFile? image = await _picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 75,
                            );
                            if (image != null) {
                              setDialogState(() {
                                localPhotoUrl = image.path;
                              });
                            }
                          },
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: const Color(0xFFE8F5E9),
                            backgroundImage: hasImg ? FileImage(File(localPhotoUrl!)) : null,
                            child: !hasImg
                                ? Text(
                                    nameController.text.isNotEmpty ? nameController.text[0].toUpperCase() : 'M',
                                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E9C4A),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nom et Prénom',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      hintText: '0712345678',
                      prefixText: '+225 ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final cleanPhone = phoneController.text.trim().replaceAll(RegExp(r'\D'), '');

                  if (newName.isEmpty) {
                    setDialogState(() => error = 'Veuillez entrer un nom valide.');
                    return;
                  }
                  if (cleanPhone.length != 10) {
                    setDialogState(() => error = 'Numéro invalide à 10 chiffres (ex: 0712345678).');
                    return;
                  }

                  await CagnoteRepository().enregistrerProfil(
                    name: newName,
                    phone: "+225$cleanPhone",
                    photoUrl: localPhotoUrl,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF2E9C4A),
                        content: Text('Profil mis à jour avec succès !'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E9C4A), foregroundColor: Colors.white),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmerDeconnexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Souhaitez-vous vous déconnecter de votre compte ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseAuth.instance.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = CagnoteRepository();
    final user = repo.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.ecouterProfil(user?.uid ?? ''),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['name'] ?? 'Membre Dibi';
        final phone = data?['phone'] ?? '+225 -- -- -- --';
        final photoUrl = data?['photoUrl'] as String?;
        final pinCode = data?['pinCode'] ?? '1234';
        final paymentMethodsRaw = data?['paymentMethods'] as List? ?? ['Wave', 'Orange Money', 'MTN', 'Moov'];
        final paymentMethods = paymentMethodsRaw.map((e) => e.toString()).toList();

        final hasValidImage = photoUrl != null && photoUrl.isNotEmpty && File(photoUrl).existsSync();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Carte En-tête Profil
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 2,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _changerPhoto(name, phone),
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: const Color(0xFFE8F5E9),
                            backgroundImage: hasValidImage ? FileImage(File(photoUrl)) : null,
                            child: !hasValidImage
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _changerPhoto(name, phone),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E9C4A),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _modifierProfilDialog(context, name, phone, photoUrl),
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2E9C4A)),
                      label: const Text('Modifier mon profil', style: TextStyle(color: Color(0xFF2E9C4A), fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2E9C4A), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 16, color: Color(0xFF2E9C4A)),
                          SizedBox(width: 4),
                          Text(
                            'Compte Vérifié',
                            style: TextStyle(
                              color: Color(0xFF2E9C4A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Section Réglages
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              color: Colors.white,
              elevation: 1,
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.shield_outlined, color: Color(0xFF2E9C4A)),
                    ),
                    title: const Text('Code PIN & Sécurité', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Code PIN : $pinCode'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => PinSecurityDialog(currentPin: pinCode),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.payment, color: Color(0xFF2E9C4A)),
                    ),
                    title: const Text('Moyens de paiement', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(paymentMethods.join(', ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => PaymentMethodsDialog(currentMethods: paymentMethods),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.help_outline, color: Color(0xFF2E9C4A)),
                    ),
                    title: const Text('Aide & Support', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Comment créer ou rejoindre une cagnotte'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (_) => const HelpSupportBottomSheet(),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bouton Se Déconnecter Élégant
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              elevation: 1,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.power_settings_new, color: Color(0xFFD32F2F), size: 20),
                ),
                title: const Text(
                  'Déconnexion',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32F2F),
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  'Fermer la session actuelle',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () => _confirmerDeconnexion(context),
              ),
            ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

/// Dialog Code PIN & Sécurité
class PinSecurityDialog extends StatefulWidget {
  final String currentPin;

  const PinSecurityDialog({super.key, required this.currentPin});

  @override
  State<PinSecurityDialog> createState() => _PinSecurityDialogState();
}

class _PinSecurityDialogState extends State<PinSecurityDialog> {
  late TextEditingController _pinController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController(text: widget.currentPin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF2E9C4A)),
          SizedBox(width: 8),
          Text('Code PIN & Sécurité'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Entrez un code PIN à 4 chiffres pour sécuriser vos versement et retraits.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '1234',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final pin = _pinController.text.trim();
            if (pin.length != 4 || int.tryParse(pin) == null) {
              setState(() => _error = 'Le code PIN doit comporter 4 chiffres');
              return;
            }
            await CagnoteRepository().enregistrerPin(pin);
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code PIN mis à jour avec succès !')),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E9C4A)),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}

/// Dialog Moyens de Paiement
class PaymentMethodsDialog extends StatefulWidget {
  final List<String> currentMethods;

  const PaymentMethodsDialog({super.key, required this.currentMethods});

  @override
  State<PaymentMethodsDialog> createState() => _PaymentMethodsDialogState();
}

class _PaymentMethodsDialogState extends State<PaymentMethodsDialog> {
  final List<String> _available = ['Wave', 'Orange Money', 'MTN Moov Money', 'Carte Bancaire'];
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.currentMethods);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.payment, color: Color(0xFF2E9C4A)),
          SizedBox(width: 8),
          Text('Moyens de paiement'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sélectionnez vos moyens de paiement préférés pour effectuer vos cotisations :',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ..._available.map((method) {
            final isChecked = _selected.contains(method);
            return CheckboxListTile(
              value: isChecked,
              title: Text(method, style: const TextStyle(fontWeight: FontWeight.w600)),
              activeColor: const Color(0xFF2E9C4A),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selected.add(method);
                  } else {
                    _selected.remove(method);
                  }
                });
              },
            );
          }),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            await CagnoteRepository().enregistrerMoyensPaiement(_selected.toList());
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Moyens de paiement enregistrés !')),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E9C4A)),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Modal Aide & Support
class HelpSupportBottomSheet extends StatelessWidget {
  const HelpSupportBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.help_outline, color: Color(0xFF2E9C4A)),
                  SizedBox(width: 8),
                  Text('Aide & Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                const HelpSectionTile(
                  icon: Icons.add_circle_outline,
                  title: 'Comment créer une cagnotte ?',
                  description:
                      '1. Cliquez sur le bouton "+ Créer" sur l\'écran d\'accueil.\n2. Indiquez le nom de la cotisation, l\'objectif global FCFA et la cotisation mensuelle par membre.\n3. Validez : un QR Code et un code d\'invitation unique (ex: DIBI-366-570) seront générés.',
                ),
                const SizedBox(height: 16),
                const HelpSectionTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Comment rejoindre une cagnotte ?',
                  description:
                      '1. Cliquez sur "Rejoindre" sur l\'écran d\'accueil.\n2. Scannez le QR Code de la cagnote à l\'aide de votre caméra OU saisissez manuellement le code d\'invitation (ex: DIBI-366-570).\n3. Vous serez instantanément ajouté au groupe de cotisation.',
                ),
                const SizedBox(height: 16),
                const HelpSectionTile(
                  icon: Icons.payment,
                  title: 'Comment effectuer un versement ?',
                  description:
                      '1. Ouvrez votre cagnotte active.\n2. Cliquez sur le bouton "Payer ma cotisation".\n3. Choisissez votre moyen Mobile Money (Wave, Orange Money, MTN, Moov) via la passerelle CinetPay.\n4. La validation met à jour instantanément votre statut "Payé".',
                ),
                const SizedBox(height: 16),
                const HelpSectionTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat & Bot IA',
                  description:
                      'Chaque groupe de cotisation dispose d\'un espace de discussion sécurisé. Le Bot IA envoie automatiquement des notifications lors des dépôts et des arrivées de membres.',
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                // À propos du développeur inséré dans Aide & Support
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'À PROPOS DU DÉVELOPPEUR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E9C4A),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Développé par un jeune dev mobile, VibeCoder qui conçoit des solutions numériques innovantes pour répondre aux besoins du marché. En progression dans les dev mobile avec Flutter, Dart, Kotlin et Jetpack Compose, je développe des projets tels que CI Services et une plateforme de référencement et de gestion hôtelière.',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dibi Christian Manuel',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Dibi Family v1.0.0',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HelpSectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const HelpSectionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF2E9C4A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }
}


/// Barre de navigation flottante moderne et dynamique (Style Kotlin App)
class ModernBottomNavigationBar extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabSelected;

  const ModernBottomNavigationBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.verified_user_outlined, Icons.verified_user, 'Cotisations', 0),
      (Icons.bar_chart_outlined, Icons.bar_chart, 'Dépenses', 1),
      (Icons.history_outlined, Icons.history, 'Historique', 2),
      (Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat', 3),
      (Icons.person_outline, Icons.person, 'Profil', 4),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final isSelected = selectedTab == item.$4;
            return GestureDetector(
              onTap: () => onTabSelected(item.$4),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 12 : 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2E9C4A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.$2 : item.$1,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Service de Paiement Direct Jeko Africa (pay.jeko.africa)
class JekoPayService {
  static const String directPaymentLink = "https://pay.jeko.africa/pl/853fabb2-176f-4364-825d-b5bc7b3c79c6";

  static String getPaymentUrl() {
    return directPaymentLink;
  }
}

/// Feuille Modal de Paiement unique via Jeko Africa (pay.jeko.africa)
class PaymentModalSheet extends StatefulWidget {
  final String cotisationId;
  final String cagnoteName;
  final double monthlyAmount;
  final double targetAmount;
  final String ownerId;

  const PaymentModalSheet({
    super.key,
    required this.cotisationId,
    required this.cagnoteName,
    required this.monthlyAmount,
    required this.targetAmount,
    required this.ownerId,
  });

  @override
  State<PaymentModalSheet> createState() => _PaymentModalSheetState();
}

class _PaymentModalSheetState extends State<PaymentModalSheet> {
  bool _isLoading = false;
  String? _error;
  String _period = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    try {
      _period = DateFormat('MMMM yyyy', 'fr_FR').format(now);
    } catch (_) {
      _period = DateFormat('MMMM yyyy').format(now);
    }
    if (_period.isNotEmpty) {
      _period = _period[0].toUpperCase() + _period.substring(1);
    }
  }

  Future<void> _payerViaJeko() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final repo = CagnoteRepository();
      final user = repo.currentUser;
      final snap = user != null ? await repo.ecouterProfil(user.uid).first : null;
      final userName = snap?.data()?['name'] as String? ?? "Membre Dibi";
      final txnId = "JKO-${DateTime.now().millisecondsSinceEpoch}";

      final paymentUrl = JekoPayService.getPaymentUrl();
      final uri = Uri.parse(paymentUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      await repo.soumettreDeclarationVersement(
        cotisationId: widget.cotisationId,
        memberName: userName,
        amount: widget.monthlyAmount,
        paymentMethod: "Jeko Africa (pay.jeko.africa)",
        period: _period,
        transactionRef: txnId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E9C4A),
          content: Text('Guichet Jeko Africa ouvert ! Déclaration de ${widget.monthlyAmount.toInt()} FCFA enregistrée.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du paiement Jeko : $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Effectuer votre versement',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.cagnoteName} • Période : $_period',
              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: Row(
                children: [
                  const JekoLogoWidget(size: 44),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jeko Africa (pay.jeko.africa)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4A148C)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Payer par Wave, Orange Money, MTN, Moov et Carte Bancaire',
                          style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 28),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E9C4A)))
                : ElevatedButton.icon(
                    onPressed: _payerViaJeko,
                    icon: const Icon(Icons.payment),
                    label: Text(
                      'Payer ${widget.monthlyAmount.toInt()} FCFA sur Jeko Africa',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E9C4A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Fonction utilitaire pour générer et partager le rapport financier au format PDF
Future<void> _genererEtPartagerRapportPdf({
  required String cagnoteName,
  required double targetAmount,
  required double totalCollected,
  required List<dynamic> members,
  required List<dynamic> paidList,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: pw.PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('KOTA - Rapport Financier', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: pw.PdfColors.green800)),
                  pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Cagnotte : $cagnoteName', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Objectif financier : ${targetAmount.toInt()} FCFA'),
            pw.Text('Total collecté : ${totalCollected.toInt()} FCFA'),
            pw.Text('Membres totaux : ${members.length}'),
            pw.Text('Membres à jour (Payés) : ${paidList.length}'),
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('Liste des participants', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Membre ID', 'Statut de Paiement'],
              data: members.map((m) {
                final isPaid = paidList.contains(m.toString());
                return [m.toString(), isPaid ? 'PAYÉ' : 'EN RETARD'];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pw.PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: pw.PdfColor.fromInt(0xFF0B5C3F)),
              cellHeight: 25,
              cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center},
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Center(
              child: pw.Text('Généré par KOTA • Gestion de Tontines & Cagnottes', style: const pw.TextStyle(fontSize: 10, color: pw.PdfColors.grey700)),
            ),
          ],
        );
      },
    ),
  );

  await Printing.sharePdf(bytes: await pdf.save(), filename: 'Rapport_${cagnoteName.replaceAll(' ', '_')}.pdf');
}



