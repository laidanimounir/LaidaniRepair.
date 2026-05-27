class TechnicianPermissions {
  final bool canSeePrices;
  final bool canEditTicket;
  final bool canAddParts;
  final bool canSeeOtherTickets;

  const TechnicianPermissions({
    this.canSeePrices = false,
    this.canEditTicket = false,
    this.canAddParts = false,
    this.canSeeOtherTickets = false,
  });

  factory TechnicianPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TechnicianPermissions();
    return TechnicianPermissions(
      canSeePrices: json['can_see_prices'] as bool? ?? false,
      canEditTicket: json['can_edit_ticket'] as bool? ?? false,
      canAddParts: json['can_add_parts'] as bool? ?? false,
      canSeeOtherTickets: json['can_see_other_tickets'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'can_see_prices': canSeePrices,
    'can_edit_ticket': canEditTicket,
    'can_add_parts': canAddParts,
    'can_see_other_tickets': canSeeOtherTickets,
  };

  static const TechnicianPermissions all = TechnicianPermissions(
    canSeePrices: true,
    canEditTicket: true,
    canAddParts: true,
    canSeeOtherTickets: true,
  );
}
