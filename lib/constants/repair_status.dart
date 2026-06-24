class RepairStatus {
  RepairStatus._();

  // --- Ticket statuses ---
  static const String enAttente = 'En attente';
  static const String enCours = 'En cours';
  static const String termine = 'Terminé';
  static const String livre = 'Livré';
  static const String annule = 'Annulé';

  static const List<String> all = [enAttente, enCours, termine, livre, annule];
  static const List<String> active = [enAttente, enCours, termine, livre];

  // --- Payment statuses ---
  static const String nonPaye = 'Non payé';
  static const String avance = 'Avance';
  static const String paye = 'Payé';

  // --- Device types ---
  static const List<String> deviceTypes = [
    'Smartphone',
    'Tablette',
    'PC Portable',
    'PC Bureau',
    'Console',
    'Montre connectée',
    'Autre',
  ];

  // --- Part statuses ---
  static const String partNeuf = 'Neuf';
  static const String partOccasion = 'Occasion';
  static const String partDefectueux = 'Défectueux';
  static const String partRetourne = 'Retourné';
  static const String partUtilise = 'Utilisé';

  // --- Quote statuses ---
  static const String quoteGenere = 'Généré';
  static const String quoteEnvoye = 'Envoyé';
  static const String quoteAccepte = 'Accepté';
  static const String quoteRefuse = 'Refusé';

  // --- Colors (Flutter) ---
  static int statusColor(String? status) {
    switch (status) {
      case enAttente: return 0xFFFFAB40;   // orange
      case enCours:   return 0xFF448AFF;   // blue
      case termine:   return 0xFF10B981;   // green
      case livre:     return 0xFFAB47BC;   // purple
      case annule:    return 0xFFEF5350;   // red
      default:        return 0xFF00E5FF;   // cyan
    }
  }

  static int partStatusColor(String? status) {
    switch (status) {
      case partNeuf:       return 0xFF10B981;
      case partOccasion:   return 0xFFFFAB40;
      case partDefectueux: return 0xFFEF5350;
      case partRetourne:   return 0xFF8A9BB4;
      default:             return 0xFF00E5FF;
    }
  }
}
