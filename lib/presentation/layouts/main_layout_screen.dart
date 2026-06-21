import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart'; // Importación del nuevo paquete
import 'package:safedrive/presentation/screens/home_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  // Índice de la pestaña actual
  int _selectedIndex = 0;

  // Lista de las pantallas
  final List<Widget> _screens = [
    const HomeScreen(),
    const Scaffold(body: Center(child: Text('Pantalla de Archivos'))),
    const Scaffold(body: Center(child: Text('Pantalla de Perfil'))),
    const Scaffold(body: Center(child: Text('Pantalla de tontos'))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2), // Color de fondo general
      body: IndexedStack(index: _selectedIndex, children: _screens),
      extendBody: true,

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFF212528),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GNav(
                gap: 8, // Espacio entre el icono y el texto
                backgroundColor: Colors.transparent,
                color: Colors.white, // Color de los iconos INACTIVOS
                activeColor: Color(
                  0xFF212528,
                ), // Color del texto e icono ACTIVO
                tabBackgroundColor:
                    Colors.white, // Color de fondo de la pestaña ACTIVA
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                duration: const Duration(milliseconds: 300),
                selectedIndex: _selectedIndex,
                onTabChange: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                tabs: const [
                  GButton(icon: Icons.home, text: 'Inicio'),
                  GButton(icon: Icons.favorite, text: 'Favoritos'),
                  GButton(icon: Icons.search, text: 'Buscar'),
                  GButton(icon: Icons.settings, text: 'Perfil'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
