import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import 'package:laidani_repair/features/auth/data/models/profile_model.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:laidani_repair/core/constants/app_constants.dart';

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
  _NavItem(
    label: 'Inventaire',
    icon: Icons.inventory_outlined,
    activeIcon: Icons.inventory,
    route: AppConstants.routeInventory,
    ownerOnly: true,
  ),
  _NavItem(
    label: 'Achats & Fournisseurs',
    icon: Icons.shopping_cart_outlined,
    activeIcon: Icons.shopping_cart,
    route: AppConstants.routePurchases,
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

// ─── Theme Constants for Cyber Glass ──────────────────────────────────────
const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);

// ألوان الرتب الديناميكية
const Color _ownerNeon = Color(0xFF00E5FF); // أزرق جليدي (Cyan) للمالك
const Color _workerNeon = Color(0xFF10B981); // أخضر زمردي للعامل
const Color _successGreen = Color(0xFF00E676); // أخضر فاقع لرسالة النجاح

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

    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return isDesktop
        ? _DesktopShell(
            items: visibleItems,
            currentIndex: currentIndex,
            child: child,
            profileAsync: profileAsync,
            isOwner: isOwner,
          )
        : _MobileShell(
            items: visibleItems,
            currentIndex: currentIndex,
            child: child,
            isOwner: isOwner,
          );
  }
}

// ─── Desktop Shell (Hover Dynamic Sidebar) ────────────────────────────────

class _DesktopShell extends ConsumerStatefulWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final Widget child;
  final AsyncValue<ProfileModel?> profileAsync;
  final bool isOwner;

  const _DesktopShell({
    required this.items,
    required this.currentIndex,
    required this.child,
    required this.profileAsync,
    required this.isOwner,
  });

  @override
  ConsumerState<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<_DesktopShell> {
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _maximizeWindow();
  }

  Future<void> _maximizeWindow() async {
    bool isMaximized = await windowManager.isMaximized();
    if (!isMaximized) {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeNeon = widget.isOwner ? _ownerNeon : _workerNeon;
    final currentTitle = widget.items[widget.currentIndex].label;

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Row(
        children: [
          // 1. الشريط الجانبي الديناميكي (Hover Sidebar)
          MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuart,
              width: _isHovering ? 260 : 85, // يتمدد ويتقلص
              decoration: const BoxDecoration(
                color: _panelDark,
                border: Border(
                  right: BorderSide(color: _glassBorder, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رأس الشريط (اللوغو)
                  _buildSidebarHeader(activeNeon),
                  
                  const Divider(color: _glassBorder, height: 1),
                  const SizedBox(height: 16),
                  
                  // عناصر القائمة
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final isSelected = index == widget.currentIndex;
                        return _buildNavItem(item, isSelected, activeNeon);
                      },
                    ),
                  ),

                  // البروفايل في الأسفل
                  const Divider(color: _glassBorder, height: 1),
                  _buildProfileSection(activeNeon),
                  
                  // زر تسجيل الخروج
                  _buildLogoutButton(activeNeon),
                ],
              ),
            ),
          ),

          // 2. المحتوى الرئيسي (Header + Body)
          Expanded(
            child: Column(
              children: [
                // الشريط العلوي (Smart Header)
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: _panelDark.withOpacity(0.5),
                    border: const Border(
                      bottom: BorderSide(color: _glassBorder, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // عنوان الشاشة
                      Text(
                        currentTitle.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      // الساعة الحية
                      const _LiveClock(),
                    ],
                  ),
                ),
                
                // الشاشة الحالية
                Expanded(
                  child: ClipRect(
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(Color neonColor) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.memory, color: neonColor, size: 36),
          if (_isHovering) ...[
            const SizedBox(width: 16),
            const Text(
              'LaidaniRepair',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, bool isSelected, Color activeNeon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route),
        hoverColor: activeNeon.withOpacity(0.05),
        child: Container(
          height: 52,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeNeon.withOpacity(0.1) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? activeNeon : Colors.transparent,
                width: 4,
              ),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeNeon.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(-5, 0),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 26),
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected ? activeNeon : _textMuted,
                size: 24,
              ),
              if (_isHovering) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textMuted,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(Color activeNeon) {
    return widget.profileAsync.when(
      loading: () => const SizedBox(height: 70),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final roleName = profile.isOwner ? 'Propriétaire' : 'Employé';

        return Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: activeNeon.withOpacity(0.15),
                child: Text(
                  profile.fullName.isNotEmpty ? profile.fullName.substring(0, 1).toUpperCase() : 'U',
                  style: TextStyle(color: activeNeon, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isHovering) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleName,
                        style: TextStyle(color: activeNeon, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton(Color activeNeon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleLogoutFlow(context, ref),
        hoverColor: Colors.redAccent.withOpacity(0.1),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 24),
              if (_isHovering) ...[
                const SizedBox(width: 16),
                const Text(
                  'Déconnexion',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // ─── مسار تسجيل الخروج الاحترافي (Logout Flow) ───
  Future<void> _handleLogoutFlow(BuildContext context, WidgetRef ref) async {
    // 1. عرض نافذة التأكيد (Glassmorphism)
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _glassBorder, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_person_outlined, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text('Fermeture de session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter du système ?\nVotre caisse restera en attente.',
            style: TextStyle(color: _textMuted, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.all(24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: _textMuted),
              child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !context.mounted) return;

    // 2. عرض رسالة النجاح (الدائرة الخضراء)
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (ctx) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _successGreen.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(color: _successGreen.withOpacity(0.3), blurRadius: 40, spreadRadius: 10),
                ],
              ),
              child: const Icon(Icons.check_circle_outline, color: _successGreen, size: 80),
            ),
            const SizedBox(height: 24),
            const DefaultTextStyle(
              style: TextStyle(color: _successGreen, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
              child: Text('DÉCONNEXION RÉUSSIE'),
            ),
          ],
        ),
      ),
    );

    // 3. الانتظار قليلاً ليرى المستخدم النجاح
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!context.mounted) return;

    // إغلاق نافذة النجاح أولاً
    Navigator.of(context).pop(); 
    
    // الحل السحري: ننتظر قليلاً لكي ينتهي فلاتر من إغلاق النافذة تماماً قبل مسح البيانات
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (context.mounted) {
      // الآن نقوم بتسجيل الخروج بأمان تام
      ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

// ─── Live Clock Widget (ساعة رقمية حية) ──────────────────
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;
  String _timeString = '';
  String _dateString = '';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // تهيئة القاموس الفرنسي قبل تشغيل الساعة
    initializeDateFormatting('fr', null).then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _updateTime();
        });
        // تشغيل المؤقت بعد نجاح التهيئة فقط
        _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
      }
    });
  }

  void _updateTime() {
    if (!_isInitialized) return;
    final now = DateTime.now();
    setState(() {
      _timeString = DateFormat('HH:mm:ss').format(now);
      _dateString = DateFormat('dd MMM yyyy', 'fr').format(now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // إخفاء الساعة لجزء من الثانية ريثما تجهز التهيئة لتجنب الخطأ الأحمر
    if (!_isInitialized) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _timeString,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
        Text(
          _dateString,
          style: const TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ─── Mobile Shell (Bottom Nav Bar) - تركتها للهواتف فقط ──────────────────
class _MobileShell extends ConsumerWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final Widget child;
  final bool isOwner;

  const _MobileShell({
    required this.items,
    required this.currentIndex,
    required this.child,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomItems = items.take(5).toList();
    final currentBottomIndex = currentIndex.clamp(0, bottomItems.length - 1);
    final activeNeon = isOwner ? _ownerNeon : _workerNeon;

    return Scaffold(
      backgroundColor: _bgCarbon,
      appBar: AppBar(
        backgroundColor: _panelDark,
        elevation: 0,
        title: Text(
          bottomItems[currentBottomIndex].label,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _glassBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: _panelDark,
          selectedItemColor: activeNeon,
          unselectedItemColor: _textMuted,
          type: BottomNavigationBarType.fixed,
          currentIndex: currentBottomIndex,
          onTap: (i) => context.go(bottomItems[i].route),
          items: bottomItems
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    activeIcon: Icon(item.activeIcon),
                    label: _shortLabel(item.label),
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _shortLabel(String label) {
    if (label == 'Point de Vente') return 'POS';
    if (label == 'Clients & Dettes') return 'Clients';
    if (label == 'Stock & Achats') return 'Stock';
    if (label == "Journal d'audit") return 'Audit';
    return label;
  }
}