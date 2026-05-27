import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final helpDialogRequestProvider = StateProvider<int>((ref) => 0);

final globalSearchFocusProvider = StateProvider<int>((ref) => 0);

final exportCsvRequestProvider = StateProvider<int>((ref) => 0);

final newTicketRequestProvider = StateProvider<int>((ref) => 0);

final printRequestProvider = StateProvider<int>((ref) => 0);

final navigateToIndexProvider = StateProvider<int?>((ref) => null);

void showKeyboardHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard, color: Colors.white),
          SizedBox(width: 12),
          Text('Raccourcis Clavier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
      backgroundColor: const Color(0xFF16162A),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShortcutRow(keys: 'F1', description: 'Afficher cette aide'),
            _ShortcutRow(keys: 'Ctrl+1..8', description: 'Naviguer dans le menu latéral'),
            _ShortcutRow(keys: 'Ctrl+F', description: 'Recherche globale'),
            _ShortcutRow(keys: 'Ctrl+N', description: 'Nouveau ticket de réparation'),
            _ShortcutRow(keys: 'Ctrl+P', description: 'Imprimer ticket/facture'),
            _ShortcutRow(keys: 'Ctrl+E', description: 'Exporter CSV (rapports)'),
            _ShortcutRow(keys: 'Ctrl+K', description: 'Mode Kiosque (affichage client)'),
            SizedBox(height: 16),
            Text('Raccourcis POS', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 8),
            _ShortcutRow(keys: 'F1', description: 'Rechercher un produit / scanner code-barres'),
            _ShortcutRow(keys: 'F2', description: 'Sélectionner un client'),
            _ShortcutRow(keys: 'F9', description: 'Valider la vente'),
            _ShortcutRow(keys: 'Echap', description: 'Vider le panier'),
            _ShortcutRow(keys: 'F12', description: 'Aide POS'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer', style: TextStyle(color: Color(0xFF6C63FF))),
        ),
      ],
    ),
  );
}

class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String description;
  const _ShortcutRow({required this.keys, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2B6E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5)),
            ),
            child: Text(keys, style: const TextStyle(color: Color(0xFF6C63FF), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Text(description, style: const TextStyle(color: Color(0xFFCCCCEE), fontSize: 13)),
        ],
      ),
    );
  }
}
