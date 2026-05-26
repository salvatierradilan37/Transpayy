import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'login_screen.dart';

class ChoferDashboardScreen extends StatefulWidget {
  const ChoferDashboardScreen({super.key});

  @override
  State<ChoferDashboardScreen> createState() => _ChoferDashboardScreenState();
}

class _ChoferDashboardScreenState extends State<ChoferDashboardScreen> {
  final user = Supabase.instance.client.auth.currentUser!;
  final supabase = Supabase.instance.client;
  final FlutterTts _flutterTts = FlutterTts();

  bool _isLoading = true;
  String _estadoChofer = 'pendiente';
  bool _deTurno = false;
  
  Map<String, dynamic>? _perfilChofer;
  List<dynamic> _rutasDisponibles = []; // Se eliminó _rutaAsignada para quitar el error

  @override
  void initState() {
    super.initState();
    _configurarTTS();
    _verificarEstadoYDatos();
    _escucharPagosEnTiempoReal();
  }

  void _configurarTTS() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  void _escucharPagosEnTiempoReal() {
    supabase
        .from('transacciones')
        .stream(primaryKey: ['id'])
        .eq('id_chofer', user.id)
        .listen((List<Map<String, dynamic>> data) async {
          if (data.isNotEmpty) {
            final ultimoPago = data.last;
            String monto = ultimoPago['monto'].toString();
            await _flutterTts.speak("Pago recibido de $monto Bolivianos");
          }
        });
  }

  Future<void> _verificarEstadoYDatos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final choferData = await supabase
          .from('choferes')
          .select('estado, placa_bus, foto_licencia_url')
          .eq('id', user.id)
          .maybeSingle();

      if (choferData != null) {
        _estadoChofer = choferData['estado'] ?? 'pendiente';
        _perfilChofer = choferData;
      }

      if (_estadoChofer == 'aprobado') {
        final rutasRes = await supabase.from('rutas').select();
        _rutasDisponibles = rutasRes as List;
      }
    } catch (e) {
      debugPrint("Error cargando datos: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cambiarTurno(bool activar) async {
    setState(() => _deTurno = activar);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(activar ? "Turno Iniciado" : "Jornada Finalizada"))
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_estadoChofer == 'pendiente') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock, size: 80, color: Colors.orange),
                const Text("Cuenta en Revisión", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Espera a que el administrador apruebe tu registro.", textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _verificarEstadoYDatos, child: const Text("Verificar ahora")),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel del Chofer"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _verificarEstadoYDatos),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await supabase.auth.signOut();
              navigator.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade900,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.directions_bus, size: 40, color: Colors.blue),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Chofer Profesional", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Placa: ${_perfilChofer?['placa_bus'] ?? 'S/P'}", style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(_deTurno ? "EN TURNO" : "OFFLINE"),
                    backgroundColor: _deTurno ? Colors.green : Colors.grey,
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Image.network("https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${user.id}", height: 90, width: 90),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Mi Código QR de Pago", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("Mantén este QR visible para recibir cobros.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: _deTurno 
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(double.infinity, 50)),
                    onPressed: () => _cambiarTurno(false),
                    icon: const Icon(Icons.power_settings_new, color: Colors.white),
                    label: const Text("Terminar Turno / Finalizar Jornada", style: TextStyle(color: Colors.white, fontSize: 16)),
                  )
                : Column(
                    children: [
                      const Text("Selecciona tu ruta para iniciar jornada:"),
                      const SizedBox(height: 10),
                      ..._rutasDisponibles.map((r) => Card(
                            child: ListTile(
                              title: Text(r['nombre_ruta'] ?? 'Ruta'),
                              subtitle: Text("${r['origen']} - ${r['destino']}"),
                              trailing: ElevatedButton(
                                onPressed: () => _cambiarTurno(true),
                                child: const Text("Iniciar Turno"),
                              ),
                            ),
                          )),
                    ],
                  ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Historial de Pagos Recibidos (Hoy)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            Container(
              height: 200,
              margin: const EdgeInsets.all(12),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('transacciones').stream(primaryKey: ['id']).eq('id_chofer', user.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("Sin transacciones hoy."));
                  }
                  final pagos = snapshot.data!.reversed.toList();
                  return ListView.builder(
                    itemCount: pagos.length,
                    itemBuilder: (context, index) {
                      final p = pagos[index];
                      return ListTile(
                        leading: const Icon(Icons.monetization_on, color: Colors.green),
                        title: Text("Monto: ${p['monto']} Bs"),
                        subtitle: Text("Fecha: ${p['fecha'] ?? ''}"),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}