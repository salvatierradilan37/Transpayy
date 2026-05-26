import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chofer_dashboard_screen.dart';

class RegistroChoferScreen extends StatefulWidget {
  const RegistroChoferScreen({super.key});

  @override
  State<RegistroChoferScreen> createState() => _RegistroChoferScreenState();
}

class _RegistroChoferScreenState extends State<RegistroChoferScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _placaController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registrarChofer() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Llena Carnet y Contraseña")));
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Registro en Authentication
      final authRes = await supabase.auth.signUp(
        email: "${_emailController.text.trim()}@transpayy.com",
        password: _passwordController.text.trim(),
      );

      if (authRes.user == null) throw Exception("Error al crear credenciales.");

      // 2. Inserción Directa en choferes (Ya no requiere la tabla perfiles)
      await supabase.from('choferes').insert({
        'id': authRes.user!.id,
        'licencia_conducir': _licenciaController.text.trim(),
        'placa_bus': _placaController.text.trim(),
        'estado': 'pendiente',
      });

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ChoferDashboardScreen()));

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro Chofer")),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Carnet")),
          TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Contraseña"), obscureText: true),
          TextField(controller: _licenciaController, decoration: const InputDecoration(labelText: "Número de Licencia")),
          TextField(controller: _placaController, decoration: const InputDecoration(labelText: "Placa del Autobús")),
          const SizedBox(height: 25),
          _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _registrarChofer, child: const Text("Registrarse")),
        ],
      ),
    );
  }
}