import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:laidani_repair/features/auth/data/models/profile_model.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:laidani_repair/core/constants/app_constants.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';

// ─── Nav Item Definition ─────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final bool ownerOnly;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.ownerOnly = false,
  });
}

const _navItems = <_NavItem>[
  _NavItem(
    label: 'Point de Vente',
    icon: Icons.point_of_sale_outlined,
    activeIcon: Icons.point_of_sale,
    route: AppConstants.routePos,
  ),
  _NavItem(
    label: 'Réparations',
    icon: Icons.build_circle_outlined,
    activeIcon: Icons.build_circle,
    route: AppConstants.routeRepairs,
  ),
  _NavItem(
    label: 'Clients & Dettes',
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    route: AppConstants.routeClients,
  ),
  // ── Owner only ──
  _NavItem(
    label: 'Stock & Achats',
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    route: AppConstants.routeStock,
    ownerOnly: true,
  ),
  _NavItem(
    label: 'Dépenses',
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet,
    route: AppConstants.routeExpenses,
    ownerOnly: true,
  ),
  _NavItem(
    label: "Journal d'audit",
    icon: Icons.history_edu_outlined,
    activeIcon: Icons.history_edu,
    route: AppConstants.routeAudit,
    ownerOnly: true,
  ),
];

// ─── App Shell ────────────────────────────────────────────────────────────

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isOwnerProvider);
    final profileAsync = ref.watch(profileProvider);

    final visibleItems = _navItems
        .where((item) => !item.ownerOnly || isOwner)
        .toList();

    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex =
        visibleItems.indexWhere((item) => location.startsWith(item.route));
    if (currentIndex < 0) currentIndex = 0;

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return isDesktop
        ? _DesktopShell(
            items: visibleItems,
            currentIndex: currentIndex,
            child: child,
            profileAsync: profileAsync,
          )
        : _MobileShell(
            items: visibleItems,
            currentIndex: currentIndex,
            child: child,
          );
  }
}

// ─── Desktop Shell (Navigation Rail) ─────────────────────────────────────

class _DesktopShell extends ConsumerWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final Widget child;
  final AsyncValue<ProfileModel?> profileAsync;

  const _DesktopShell({
    required this.items,
    required this.currentIndex,
    required this.child,
    required this.profileAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Navigation Rail
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainer,
              border: Border(
                right: BorderSide(color: Color(0xFF2A2A50), width: 1),
              ),
            ),
            child: NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(items[i].route),
              labelType: NavigationRailLabelType.all,
              groupAlignment: -1.0,
              leading: _RailHeader(profileAsync: profileAsync),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _LogoutButton(),
                ),
              ),
              destinations: items
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  )
                  .toList(),
            ),
          ),
          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Mobile Shell (Bottom Nav Bar) ───────────────────────────────────────

class _MobileShell extends ConsumerWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final Widget child;

  const _MobileShell({
    required this.items,
    required this.currentIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mobile: limit bottom nav to 5 items max (material design limit)
    // If owner, show a drawer for extra items if needed
    final bottomItems = items.take(5).toList();
    final currentBottomIndex = currentIndex.clamp(0, bottomItems.length - 1);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: _mobileTitle(context, items, currentIndex),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 20),
            tooltip: 'Déconnexion',
            onPressed: () => _confirmLogout(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentBottomIndex,
        onTap: (i) => context.go(bottomItems[i].route),
        items: bottomItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: _shortLabel(item.label),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _mobileTitle(
      BuildContext context, List<_NavItem> items, int currentIndex) {
    final item = (currentIndex >= 0 && currentIndex < items.length)
        ? items[currentIndex]
        : null;
    return Text(item?.label ?? 'LaidaniRepair');
  }

  String _shortLabel(String label) {
    // Shorten long labels for mobile bottom bar
    if (label == 'Point de Vente') return 'POS';
    if (label == 'Clients & Dettes') return 'Clients';
    if (label == 'Stock & Achats') return 'Stock';
    if (label == "Journal d'audit") return 'Audit';
    return label;
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

// ─── Rail Header (user info + logo) ──────────────────────────────────────

class _RailHeader extends ConsumerWidget {
  final AsyncValue<ProfileModel?> profileAsync;

  const _RailHeader({required this.profileAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          // App Logo
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.phone_android,
                color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          const Text(
            'LaidaniRepair',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          // User name + role badge
          profileAsync.when(
            loading: () => const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (profile) {
              if (profile == null) return const SizedBox.shrink();
              return Column(
                children: [
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: profile.isOwner
                          ? AppTheme.primary.withOpacity(0.2)
                          : AppTheme.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: profile.isOwner
                            ? AppTheme.primary.withOpacity(0.4)
                            : AppTheme.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      profile.isOwner ? 'Propriétaire' : 'Employé',
                      style: TextStyle(
                        color: profile.isOwner
                            ? AppTheme.primaryLight
                            : AppTheme.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ─── Logout Button ────────────────────────────────────────────────────────

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Déconnexion'),
              content: const Text('Voulez-vous vraiment vous déconnecter ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Déconnexion'),
                ),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            ref.read(authNotifierProvider.notifier).signOut();
          }
        },
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_outlined, color: AppTheme.error, size: 18),
              SizedBox(width: 8),
              Text(
                'Déconnexion',
                style: TextStyle(
                  color: AppTheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
