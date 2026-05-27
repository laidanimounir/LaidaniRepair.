import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/promotions/presentation/providers/promotions_provider.dart';

class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsAsync = ref.watch(promotionsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: const Text('Promotions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showPromoDialog(context, ref, null),
          ),
        ],
      ),
      body: promotionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(
          child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error)),
        ),
        data: (promotions) {
          if (promotions.isEmpty) {
            return const Center(
              child: Text('Aucune promotion', style: TextStyle(color: AppTheme.onSurfaceMuted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: promotions.length,
            itemBuilder: (_, i) => _PromoCard(promotion: promotions[i]),
          );
        },
      ),
    );
  }

  void _showPromoDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    final codeController = TextEditingController(text: existing?['code']?.toString() ?? '');
    final descController = TextEditingController(text: existing?['description']?.toString() ?? '');
    final valueController = TextEditingController(text: existing?['discount_value']?.toString() ?? '');
    final minPurchaseController = TextEditingController(text: existing?['min_purchase']?.toString() ?? '0');
    final maxUsesController = TextEditingController(text: existing?['max_uses']?.toString() ?? '');

    String discountType = existing?['discount_type'] ?? 'percentage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Modifier la promotion' : 'Nouvelle promotion'),
          backgroundColor: AppTheme.surfaceContainerHigh,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Code', prefixIcon: Icon(Icons.local_offer)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: discountType,
                  dropdownColor: AppTheme.surfaceContainerHigh,
                  decoration: const InputDecoration(
                    labelText: 'Type de réduction',
                    prefixIcon: Icon(Icons.percent),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Pourcentage (%)', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'fixed', child: Text('Montant fixe (DA)', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setDialogState(() => discountType = v!),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: discountType == 'percentage' ? 'Valeur (%)' : 'Valeur (DA)',
                    prefixIcon: const Icon(Icons.monetization_on),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minPurchaseController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Achat minimum (DA)', prefixIcon: Icon(Icons.shopping_cart)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxUsesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Utilisations max (vide = illimité)', prefixIcon: Icon(Icons.repeat)),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.isEmpty || valueController.text.isEmpty) return;
                final client = ref.read(supabaseClientProvider);
                final data = {
                  'code': codeController.text.trim(),
                  'description': descController.text.trim(),
                  'discount_type': discountType,
                  'discount_value': double.tryParse(valueController.text) ?? 0,
                  'min_purchase': double.tryParse(minPurchaseController.text) ?? 0,
                  'max_uses': int.tryParse(maxUsesController.text),
                };
                if (existing != null) {
                  await client.from('promotions').update(data).eq('id', existing['id']);
                } else {
                  await client.from('promotions').insert(data);
                }
                ref.invalidate(promotionsStreamProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing != null ? 'Modifier' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends ConsumerWidget {
  final Map<String, dynamic> promotion;
  const _PromoCard({required this.promotion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = promotion['is_active'] as bool? ?? true;
    final discountType = promotion['discount_type'] as String;
    final discountValue = (promotion['discount_value'] as num).toDouble();
    final usedCount = (promotion['used_count'] as num?)?.toInt() ?? 0;
    final maxUses = promotion['max_uses'] as int?;
    final expiresAt = promotion['expires_at'] != null
        ? DateTime.tryParse(promotion['expires_at'].toString())
        : null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      color: isActive ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainer.withOpacity(0.5),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          isActive ? Icons.local_offer : Icons.block,
          color: isActive ? AppTheme.primary : AppTheme.onSurfaceMuted,
        ),
        title: Text(
          promotion['code'] as String,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.onSurfaceMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (promotion['description'] != null)
              Text(promotion['description'] as String, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            Text(
              discountType == 'percentage'
                  ? '-${discountValue.toStringAsFixed(0)}%'
                  : '-${discountValue.toStringAsFixed(0)} DA',
              style: TextStyle(
                color: isActive ? Colors.greenAccent : AppTheme.onSurfaceMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Utilisé: $usedCount${maxUses != null ? ' / $maxUses' : ''}',
              style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11),
            ),
            if (expiresAt != null)
              Text('Expire: ${dateFormat.format(expiresAt)}', style: const TextStyle(color: AppTheme.warning, fontSize: 11)),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
            color: isActive ? Colors.greenAccent : AppTheme.onSurfaceMuted,
          ),
          onPressed: () async {
            final client = ref.read(supabaseClientProvider);
            await client.from('promotions').update({'is_active': !isActive}).eq('id', promotion['id']);
          },
        ),
        onLongPress: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirmer'),
              backgroundColor: AppTheme.surfaceContainerHigh,
              content: const Text('Supprimer cette promotion ?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () async {
                    final client = ref.read(supabaseClientProvider);
                    await client.from('promotions').delete().eq('id', promotion['id']);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
