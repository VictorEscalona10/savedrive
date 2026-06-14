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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Color de fondo general
      body: IndexedStack(index: _selectedIndex, children: _screens),

      bottomNavigationBar: Container(
        color: Colors.white, // Fondo de la barra inferior
        child: Padding(
          // Padding para que la barra no quede pegada a los bordes de la pantalla
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 18.0),
          child: GNav(
            gap: 8, // Espacio entre el ícono y el texto
            backgroundColor: Colors.white, // Color de fondo del GNav
            color: Colors.grey.shade600, // Color de los íconos INACTIVOS
            activeColor: Colors.blueAccent, // Color del ícono y texto ACTIVO
            tabBackgroundColor: Colors.blueAccent.withOpacity(
              0.1,
            ), // Color de la burbuja (con transparencia)
            padding: const EdgeInsets.all(15), // Espacio interno de cada botón
            // Sincronización con nuestro estado
            selectedIndex: _selectedIndex,
            onTabChange: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },

            // Pestañas (GButton en lugar de BottomNavigationBarItem)
            tabs: const [
              GButton(icon: Icons.home, text: 'Inicio'),
              GButton(icon: Icons.folder, text: 'Archivos'),
              GButton(icon: Icons.person, text: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}
