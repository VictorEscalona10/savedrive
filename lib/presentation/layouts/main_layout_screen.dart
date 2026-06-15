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
      backgroundColor: Colors.white, // Color de fondo general
      body: IndexedStack(index: _selectedIndex, children: _screens),

      bottomNavigationBar: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
          child: GNav(
            gap: 8,
            backgroundColor: Colors.black,
            color: Colors.white,
            tabBackgroundColor: Colors.grey.shade800,
            activeColor: Colors.white,
            padding: const EdgeInsets.all(16),
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
    );
  }
}
