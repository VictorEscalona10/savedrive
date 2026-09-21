import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:safedrive/presentation/screens/home_screen.dart';
import 'package:safedrive/presentation/screens/profile_screen.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const _PlaceholderScreen(
      title: 'Historial de Viajes',
      subtitle: 'Registros de telemetría y rutas de conducción segura.',
      icon: Icons.route_rounded,
    ),
    const _PlaceholderScreen(
      title: 'Métricas de Fatiga',
      subtitle: 'Análisis de parpadeo, EAR y microsueños prevenidos.',
      icon: Icons.query_stats_rounded,
    ),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(isDark),
          body: IndexedStack(index: _selectedIndex, children: _screens),
          extendBody: true,
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.navBar(isDark),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark ? const Color(0x33334155) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? const Color(0x60000000) : const Color(0x14000000),
                      blurRadius: 24,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                  child: GNav(
                    gap: 8,
                    backgroundColor: Colors.transparent,
                    color: AppColors.t3(isDark),
                    activeColor: isDark ? const Color(0xFF0B0F19) : Colors.white,
                    tabBackgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    duration: const Duration(milliseconds: 250),
                    selectedIndex: _selectedIndex,
                    onTabChange: (index) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    tabs: const [
                      GButton(icon: Icons.speed_rounded, text: 'Cockpit'),
                      GButton(icon: Icons.route_rounded, text: 'Viajes'),
                      GButton(icon: Icons.query_stats_rounded, text: 'Métricas'),
                      GButton(icon: Icons.person_rounded, text: 'Perfil'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PlaceholderScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(isDark),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: isDark ? 0.1 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: isDark ? 0.2 : 0.3),
                      ),
                    ),
                    child: Icon(icon, color: AppColors.brand, size: 30),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.t1(isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.t2(isDark),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
