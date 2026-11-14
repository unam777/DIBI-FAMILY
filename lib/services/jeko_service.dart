/// Service de Paiement Direct Jeko Africa (pay.jeko.africa)
class JekoPayService {
  static const String directPaymentLink = "https://pay.jeko.africa/pl/853fabb2-176f-4364-825d-b5bc7b3c79c6";

  /// Renvoie le lien de paiement direct officiel Jeko Africa
  static String getPaymentUrl() {
    return directPaymentLink;
  }
}
