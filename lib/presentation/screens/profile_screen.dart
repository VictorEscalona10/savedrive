import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  // Controladores y variables de estado para los datos
  final TextEditingController _medicalNotesController = TextEditingController();
  String? _bloodType;
  double _sensitivityLevel = 5.0;
  bool _autoTrigger = true;

  final List<String> _tiposDeSangre = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _medicalNotesController.dispose();
    super.dispose();
  }

  // --- 1. LEER DATOS DESDE SUPABASE ---
  Future<void> _cargarDatos() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Hacemos las llamadas por separado para evitar errores de tipos en arreglos
      final perfilBD = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      final ajustesBD = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          // Llenamos los datos personales
          _bloodType = perfilBD['blood_type'] as String?;
          _medicalNotesController.text =
              (perfilBD['medical_notes'] ?? '') as String;

          // Llenamos los ajustes (si existen)
          if (ajustesBD != null) {
            _sensitivityLevel = (ajustesBD['sensitivity_level'] ?? 5)
                .toDouble();
            _autoTrigger = ajustesBD['auto_trigger_enabled'] ?? true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar el perfil')),
        );
      }
    }
  }

  // --- 2. GUARDAR DATOS EN SUPABASE ---
  Future<void> _guardarDatos() async {
    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Actualizamos tabla users
      await supabase
          .from('users')
          .update({
            'blood_type': _bloodType,
            'medical_notes': _medicalNotesController.text.trim(),
          })
          .eq('id', userId);

      // Usamos upsert por si el trigger no creó la fila de settings inicialmente
      await supabase.from('user_settings').upsert({
        'user_id': userId,
        'sensitivity_level': _sensitivityLevel.toInt(),
        'auto_trigger_enabled': _autoTrigger,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados correctamente'),
            backgroundColor: Color(0xFF0CBA70),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar datos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _cerrarSesion() async {
    await supabase.auth.signOut();
    if (mounted) {
      // Regresa a la pantalla de Login y borra el historial de navegación
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Perfil y Ajustes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFF4F6F8),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECCIÓN: DATOS MÉDICOS ---
                  const Text(
                    'Datos Médicos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _bloodType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Sangre',
                            prefixIcon: Icon(
                              Icons.bloodtype,
                              color: Colors.red,
                            ),
                            border: InputBorder.none,
                          ),
                          items: _tiposDeSangre.map((tipo) {
                            return DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _bloodType = val),
                        ),
                        const Divider(),
                        TextFormField(
                          controller: _medicalNotesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText:
                                'Notas Médicas (Alergias, condiciones...)',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(
                              Icons.medical_information,
                              color: Colors.blue,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- SECCIÓN: AJUSTES DE ALARMA ---
                  const Text(
                    'Ajustes de SafeDrive',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          title: const Text('Disparo Automático'),
                          subtitle: const Text(
                            'Activa la alarma automáticamente al detectar un choque.',
                          ),
                          value: _autoTrigger,
                          activeColor: const Color(0xFF0CBA70),
                          onChanged: (val) =>
                              setState(() => _autoTrigger = val),
                        ),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            'Sensibilidad del Sensor',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Slider(
                          value: _sensitivityLevel,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          activeColor: Colors.blueGrey,
                          label: _sensitivityLevel.toInt().toString(),
                          onChanged: (val) =>
                              setState(() => _sensitivityLevel = val),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Baja (Menos sensible)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Alta (Muy sensible)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- BOTÓN DE GUARDAR ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _guardarDatos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF212528),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Guardar Cambios',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(
                    height: 80,
                  ), // Espacio para el BottomNavigationBar
                ],
              ),
            ),
    );
  }
}
