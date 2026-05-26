import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart'; 
import 'chofer_dashboard_screen.dart';
import 'admin_dashboard_screen.dart'; 
import 'register_pasajero_screen.dart'; 
import 'registro_chofer_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _iniciarSesion() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingresa tus credenciales")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      String correoFinal = _emailController.text.trim();
      if (correoFinal == "admin") {
        correoFinal = "admin@transpayy.com";
      } else if (!correoFinal.contains('@')) {
        correoFinal = "$correoFinal@transpayy.com";
      }

      final authRes = await supabase.auth.signInWithPassword(
        email: correoFinal,
        password: _passwordController.text.trim(),
      );

      if (authRes.user == null) throw Exception("No se pudo obtener el usuario.");
      final userId = authRes.user!.id;
      
      final List<dynamic> esAdmin = await supabase.from('administradores').select('id').eq('id', userId);
      final List<dynamic> esChofer = await supabase.from('choferes').select('id').eq('id', userId);
      final List<dynamic> esPasajero = await supabase.from('pasajeros').select('id').eq('id', userId);

      if (!mounted) return;

      if (esAdmin.isNotEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
      } else if (esChofer.isNotEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ChoferDashboardScreen()));
      } else if (esPasajero.isNotEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuario autenticado, pero no tiene rol en las tablas.")),
        );
      }
      
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Credenciales incorrectas: ${e.message}")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error del sistema: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Iniciar Sesión")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Carnet / Usuario")),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Contraseña"), obscureText: true),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _iniciarSesion, child: const Text("Ingresar")),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroPasajeroScreen())),
              child: const Text("¿No tienes cuenta? Regístrate como Pasajero"),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroChoferScreen())),
              child: const Text("¿Eres chofer? Regístrate aquí", style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      ),
    );
  }
}