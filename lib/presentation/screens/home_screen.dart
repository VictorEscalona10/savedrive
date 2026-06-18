import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safedrive'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(
            16.0,
          ), // Márgenes para que no toque los bordes
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Home Screen',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                height: 20,
              ), // Espacio entre el título y la tarjeta
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: Text('15%'),
                  title: const Text('Despliegame'),
                  /* subtitle: const Text('Toca para ver más opciones'), */
                  shape:
                      const Border(), // Elimina las líneas divisorias que trae por defecto
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.grey.shade50,
                      padding: const EdgeInsets.all(16.0),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aquí puedes colocar la información detallada.',
                            style: TextStyle(fontSize: 16.0),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '💡 Puedes meter más textos, imágenes o incluso botones aquí dentro.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // --- FIN DE LA TARJETA DESPLEGABLE ---
            ],
          ),
        ),
      ),
    );
  }
}
