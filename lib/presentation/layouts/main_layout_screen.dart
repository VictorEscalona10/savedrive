import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:safedrive/core/theme/theme_service.dart';
import 'package:safedrive/presentation/screens/dashboard/home_screen.dart';
import 'package:safedrive/presentation/screens/settings/settings_screen.dart';
import 'package:safedrive/presentation/screens/profile/profile_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SettingsScreen(),
    ProfileScreen(),
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
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: GNav(
                    gap: 8,
                    backgroundColor: Colors.transparent,
                    color: AppColors.t3(isDark),
                    activeColor: isDark ? const Color(0xFF0B0F19) : Colors.white,
                    tabBackgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                      GButton(icon: Icons.tune_rounded, text: 'Ajustes'),
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
