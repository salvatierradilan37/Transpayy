import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistroPasajeroScreen extends StatefulWidget {
  const RegistroPasajeroScreen({super.key});

  @override
  State<RegistroPasajeroScreen> createState() => _RegistroPasajeroScreenState();
}

class _RegistroPasajeroScreenState extends State<RegistroPasajeroScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nombreController = TextEditingController();
  final _carnetController = TextEditingController();

  String _categoria = 'estudiante';
  dynamic _fotoRostro, _fotoCarnet, _fotoEstudiante;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String tipo) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        if (tipo == 'rostro') _fotoRostro = picked;
        if (tipo == 'carnet') _fotoCarnet = picked;
        if (tipo == 'estudiante') _fotoEstudiante = picked;
      });
    }
  }

  Future<String> _subirFoto(dynamic file, String folder) async {
    final supabase = Supabase.instance.client;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$folder/$fileName';

    if (kIsWeb) {
      final bytes = await (file as XFile).readAsBytes();
      await supabase.storage.from('fotos_pasajeros').uploadBinary(path, bytes);
    } else {
      await supabase.storage
          .from('fotos_pasajeros')
          .upload(path, File((file as XFile).path));
    }

    return supabase.storage.from('fotos_pasajeros').getPublicUrl(path);
  }

  Future<void> _registrar() async {
    if (_fotoRostro == null || _fotoCarnet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faltan fotos obligatorias')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Procesando solicitud...'),
      duration: Duration(seconds: 10),
    ));
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final auth = await supabase.auth.signUp(
        email: '${_emailController.text.trim()}@transpayy.com',
        password: _passController.text.trim(),
      );

      if (auth.user == null) throw Exception('Error al crear usuario');

      final urlRostro = await _subirFoto(_fotoRostro, 'rostros');
      final urlCarnet = await _subirFoto(_fotoCarnet, 'carnets');
      String? urlEstudiante;

      if (_categoria == 'estudiante' && _fotoEstudiante != null) {
        urlEstudiante = await _subirFoto(_fotoEstudiante, 'estudiantes');
      }

      await supabase.from('pasajeros').insert({
        'id': auth.user!.id,
        'nombre_completo': _nombreController.text.trim(),
        'numero_carnet': _carnetController.text.trim(),
        'categoria': _categoria,
        'foto_rostro_url': urlRostro,
        'foto_carnet_url': urlCarnet,
        'foto_universitario_url': urlEstudiante,
        'estado': 'pendiente',
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061228),
      appBar: AppBar(
        title: const Text('Registro Pasajero'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0257A2), Color(0xFF001F44)]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Bienvenido a TransPayy',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                      'Crea tu cuenta como pasajero y comienza a viajar sin efectivo.',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(28)),
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      hintText: 'ejemplo',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nombreController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nombre completo',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _carnetController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Número de carnet',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _categoria,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none),
                    ),
                    dropdownColor: const Color(0xFF0B2448),
                    items: ['estudiante', 'normal', 'tercera_edad']
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.toUpperCase(),
                                style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _categoria = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildUploadTile('Tomar foto de rostro', _fotoRostro != null,
                      () => _pickImage('rostro')),
                  const SizedBox(height: 10),
                  _buildUploadTile('Tomar foto de carnet', _fotoCarnet != null,
                      () => _pickImage('carnet')),
                  if (_categoria == 'estudiante') ...[
                    const SizedBox(height: 10),
                    _buildUploadTile(
                        'Foto carnet estudiante',
                        _fotoEstudiante != null,
                        () => _pickImage('estudiante')),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF40E0FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _isLoading ? null : _registrar,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text('Registrarse',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Text('Procesando solicitud...',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTile(String label, bool active, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      tileColor: active ? Colors.green.withOpacity(0.16) : Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: const Icon(Icons.camera_alt, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Icon(active ? Icons.check_circle : Icons.add_circle_outline,
          color: active ? Colors.greenAccent : Colors.white70),
    );
  }
}
