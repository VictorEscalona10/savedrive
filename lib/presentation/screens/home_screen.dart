import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              children: [
                Text(
                  "Hola, Victor",
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
                ),
                Text(
                  "A donde iremos hoy?",
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
            const Spacer(),
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(
                'https://avatars.githubusercontent.com/u/105328583?v=4',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF4F6F8),
      ),
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Bienvenido a SafeDrive',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 150),
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: Text(
                    '15%+',
                    style: TextStyle(color: Color(0xFF0CBA70), fontSize: 14),
                  ),
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
                            'Informacion rapida acerca del usuario',
                            style: TextStyle(fontSize: 16.0),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Datosss, aqui van datoss',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 100,
                    vertical: 20,
                  ),
                ),
                child: const Text('Iniciar viaje'),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
