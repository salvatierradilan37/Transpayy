import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistroChoferScreen extends StatefulWidget {
  const RegistroChoferScreen({super.key});

  @override
  State<RegistroChoferScreen> createState() => _RegistroChoferScreenState();
}

class _RegistroChoferScreenState extends State<RegistroChoferScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nombreController = TextEditingController();
  final _carnetController = TextEditingController();
  final _placaController = TextEditingController();

  File? _fotoRostro, _fotoLicencia, _fotoCarnet, _fotoBus;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String tipo) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        if (tipo == 'rostro') _fotoRostro = File(picked.path);
        if (tipo == 'licencia') _fotoLicencia = File(picked.path);
        if (tipo == 'carnet') _fotoCarnet = File(picked.path);
        if (tipo == 'bus') _fotoBus = File(picked.path);
      });
    }
  }

  Future<String?> _subirFoto(File file, String folder) async {
    final supabase = Supabase.instance.client;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$folder/$fileName';
    await supabase.storage.from('fotos_choferes').upload(path, file);
    return supabase.storage.from('fotos_choferes').getPublicUrl(path);
  }

  Future<void> _registrarChofer() async {
    if (_fotoRostro == null ||
        _fotoLicencia == null ||
        _fotoCarnet == null ||
        _fotoBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, sube todas las fotos requeridas')));
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

      if (auth.user == null) throw Exception('Error al crear cuenta');

      final urlRostro = await _subirFoto(_fotoRostro!, 'rostros');
      final urlLicencia = await _subirFoto(_fotoLicencia!, 'licencias');
      final urlCarnet = await _subirFoto(_fotoCarnet!, 'carnets');
      final urlBus = await _subirFoto(_fotoBus!, 'buses');

      await supabase.from('choferes').insert({
        'id': auth.user!.id,
        'nombre_completo': _nombreController.text.trim(),
        'numero_carnet': _carnetController.text.trim(),
        'placa_bus': _placaController.text.trim(),
        'foto_rostro_url': urlRostro,
        'foto_licencia_url': urlLicencia,
        'foto_carnet_url': urlCarnet,
        'foto_bus_url': urlBus,
        'estado': 'pendiente',
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061228),
      appBar: AppBar(
        title: const Text('Registro Chofer'),
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
                  Text('Registro Chofer',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                      'Carga tus datos y documentos para comenzar a recibir pagos.',
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
                  const SizedBox(height: 14),
                  TextField(
                    controller: _placaController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Placa del bus',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildUploadTile('Foto de rostro', _fotoRostro != null,
                      () => _pickImage('rostro')),
                  const SizedBox(height: 10),
                  _buildUploadTile('Foto de licencia', _fotoLicencia != null,
                      () => _pickImage('licencia')),
                  const SizedBox(height: 10),
                  _buildUploadTile('Foto de carnet', _fotoCarnet != null,
                      () => _pickImage('carnet')),
                  const SizedBox(height: 10),
                  _buildUploadTile('Foto del bus', _fotoBus != null,
                      () => _pickImage('bus')),
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
                      onPressed: _isLoading ? null : _registrarChofer,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text('Finalizar Registro',
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
