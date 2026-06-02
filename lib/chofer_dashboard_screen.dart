import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'login_screen.dart';
import 'chofer_extensions.dart';

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
  double _saldoChofer = 0.0;

  Map<String, dynamic>? _perfilChofer;
  List<dynamic> _rutasDisponibles = [];
  // Estadísticas
  int _totalViajes = 0;
  double _ingresosHoy = 0.0;
  double _ingresosTotal = 0.0;
  double _calificacionPromedio = 0.0;
  List<Map<String, dynamic>> _pagosRecibidos = [];
  final Map<String, String> _nombresPasajeros = {};

  // Edición de perfil
  late TextEditingController _nombreController;
  late TextEditingController _telefonoController;
  late TextEditingController _licenciaController;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _telefonoController = TextEditingController();
    _licenciaController = TextEditingController();
    _configurarTTS();
    _verificarEstadoYDatos();
    _escucharPagosEnTiempoReal();
    _cargarHistorialPagos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _licenciaController.dispose();
    super.dispose();
  }

  void _configurarTTS() async {
    await _flutterTts.setLanguage('es-ES');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  void _escucharPagosEnTiempoReal() {
    supabase
        .from('transacciones')
        .stream(primaryKey: ['id'])
        .eq('id_chofer', user.id)
        .listen((List<Map<String, dynamic>> data) async {
          if (mounted) {
            setState(() {
              _pagosRecibidos = data.reversed.toList();
            });
            final ids = data
                .map((pago) => pago['pasajero_id']?.toString())
                .whereType<String>()
                .toSet()
                .toList();
            await _cargarNombresPasajeros(ids);
          }

          if (data.isNotEmpty) {
            final ultimoPago = data.last;
            String monto = ultimoPago['monto'].toString();
            await _flutterTts.speak('Pago recibido de $monto Bolivianos');
            await _cargarSaldoChofer();
          }
        });
  }

  Future<void> _cargarHistorialPagos() async {
    try {
      final pagos = await supabase
          .from('transacciones')
          .select()
          .eq('id_chofer', user.id)
          .order('fecha', ascending: false);
      final pagosList = pagos as List<dynamic>;
      final pagosMap = pagosList.cast<Map<String, dynamic>>();
      final ids = pagosMap
          .map((pago) => pago['pasajero_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      if (!mounted) return;
      setState(() {
        _pagosRecibidos = pagosMap.reversed.toList();
      });
      await _cargarNombresPasajeros(ids);
    } catch (e) {
      debugPrint('Error cargando historial de pagos: $e');
    }
  }

  Future<void> _cargarNombresPasajeros(List<String> ids) async {
    final nuevosIds =
        ids.where((id) => !_nombresPasajeros.containsKey(id)).toList();
    if (nuevosIds.isEmpty) return;

    try {
      final filterValues =
          nuevosIds.map((id) => "'${id.replaceAll("'", "''")}'").join(',');
      final pasajeros = await supabase
          .from('pasajeros')
          .select('id, nombre_completo')
          .filter('id', 'in', '($filterValues)');
      final pasajerosList = pasajeros as List<dynamic>;
      if (!mounted) return;
      setState(() {
        for (final pasajero in pasajerosList) {
          final id = pasajero['id']?.toString();
          final nombre = pasajero['nombre_completo']?.toString();
          if (id != null && nombre != null) {
            _nombresPasajeros[id] = nombre;
          }
        }
      });
    } catch (e) {
      debugPrint('Error cargando nombres de pasajeros: $e');
    }
  }

  Future<void> _cargarSaldoChofer() async {
    try {
      double saldo = 0.0;
      bool saldoObtenido = false;

      try {
        final billeteraData = await supabase
            .from('billetera')
            .select('saldo')
            .eq('id_usuario', user.id)
            .maybeSingle();
        if (billeteraData != null) {
          saldo = double.tryParse(billeteraData['saldo'].toString()) ?? 0.0;
          saldoObtenido = true;
        }
      } catch (e) {
        debugPrint('No se pudo leer billetera del chofer: $e');
      }

      if (!saldoObtenido) {
        final transaccionesRes = await supabase
            .from('transacciones')
            .select('monto')
            .eq('id_chofer', user.id)
            .eq('estado', 'completado') as List<dynamic>?;

        for (final item in transaccionesRes ?? []) {
          if (item is Map && item['monto'] != null) {
            saldo += double.tryParse(item['monto'].toString()) ?? 0.0;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _saldoChofer = saldo;
      });
    } catch (e) {
      debugPrint('Error cargando saldo chofer: $e');
    }
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
        await _cargarSaldoChofer();
        await _cargarEstadisticas();
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cambiarTurno(bool activar) async {
    setState(() => _deTurno = activar);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(activar ? 'Turno Iniciado' : 'Jornada Finalizada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_estadoChofer == 'pendiente') {
      return Scaffold(
        backgroundColor: const Color(0xFF081628),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock, size: 80, color: Colors.orange),
                const SizedBox(height: 20),
                const Text('Cuenta en Revisión',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                const Text('Espera a que el administrador apruebe tu registro.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF40E0FF),
                      foregroundColor: Colors.black),
                  onPressed: _verificarEstadoYDatos,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 22.0, vertical: 14.0),
                    child: Text('Verificar ahora'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF061228),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Panel del Chofer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _verificarEstadoYDatos),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: _mostrarDialogoPerfil,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await supabase.auth.signOut();
              navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _verificarEstadoYDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF0257A2), Color(0xFF001F44)]),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(22, 90, 22, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          child: const Icon(Icons.directions_bus,
                              size: 36, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chofer Profesional',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 6),
                              Text(
                                  'Placa: ${_perfilChofer?['placa_bus'] ?? 'S/P'}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('Estado: ${_estadoChofer.toUpperCase()}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 6),
                              Text(
                                  'Saldo: ${_saldoChofer.toStringAsFixed(2)} Bs',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _deTurno ? Colors.green : Colors.white24,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _deTurno ? 'EN TURNO' : 'OFFLINE',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Estadísticas
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        StatCard(
                          title: 'Total Viajes',
                          value: _totalViajes.toString(),
                          color: Colors.blueAccent,
                        ),
                        StatCard(
                          title: 'Hoy Gané',
                          value: '${_ingresosHoy.toStringAsFixed(2)} Bs',
                          color: Colors.greenAccent,
                        ),
                        StatCard(
                          title: 'Total Ganancias',
                          value: '${_ingresosTotal.toStringAsFixed(2)} Bs',
                          color: Colors.amberAccent,
                        ),
                        StatCard(
                          title: 'Calificación',
                          value: _calificacionPromedio.toStringAsFixed(1),
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Código QR de Pagos',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 14),
                          Center(
                            child: Image.network(
                              'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${user.id}',
                              height: 160,
                              width: 160,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                              'Mantén este QR visible para recibir cobros.',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _deTurno
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Finalizar Jornada',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () => _cambiarTurno(false),
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF40E0FF),
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar Turno',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () => _cambiarTurno(true),
                      ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rutas Disponibles',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_rutasDisponibles.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                            'No hay rutas disponibles por el momento.',
                            style: TextStyle(color: Colors.white70)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rutasDisponibles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final ruta = _rutasDisponibles[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              leading: const Icon(Icons.alt_route,
                                  color: Color(0xFF40E0FF), size: 32),
                              title: Text(
                                  ruta['nombre_ruta'] ?? 'Ruta sin nombre',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${ruta['origen'] ?? 'N/A'} → ${ruta['destino'] ?? 'N/A'}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF40E0FF),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed:
                                    _deTurno ? null : () => _cambiarTurno(true),
                                child: const Text('Seleccionar'),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    const Text('Historial de pagos recibidos',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      child: _pagosRecibidos.isEmpty
                          ? const Center(
                              child: Text('Sin transacciones recientes.',
                                  style: TextStyle(color: Colors.white70)))
                          : ListView.separated(
                              itemCount: _pagosRecibidos.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(color: Colors.white12),
                              itemBuilder: (context, index) {
                                final pago = _pagosRecibidos[index];
                                final pasajeroId =
                                    pago['pasajero_id']?.toString();
                                final nombrePasajero = pasajeroId != null
                                    ? _nombresPasajeros[pasajeroId] ??
                                        pasajeroId.substring(0, 8)
                                    : 'Pasajero desconocido';
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 0, vertical: 8),
                                  leading: const Icon(Icons.monetization_on,
                                      color: Colors.greenAccent),
                                  title: Text('Monto: ${pago['monto']} Bs',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    'Pasajero: $nombrePasajero\nFecha: ${pago['fecha'] ?? '-'}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final viajes = await supabase
          .from('transacciones')
          .select()
          .eq('id_chofer', user.id);
      final totalViajes = (viajes as List).length;

      double ingresosTotal = 0.0;
      double ingresosHoy = 0.0;
      final hoy = DateTime.now();

      for (final viaje in viajes) {
        final monto = double.tryParse(viaje['monto'].toString()) ?? 0.0;
        ingresosTotal += monto;

        final fechaTexto =
            viaje['fecha']?.toString() ?? viaje['created_at']?.toString() ?? '';
        final fecha = DateTime.tryParse(fechaTexto);
        if (fecha != null &&
            fecha.year == hoy.year &&
            fecha.month == hoy.month &&
            fecha.day == hoy.day) {
          ingresosHoy += monto;
        }
      }

      final resenas =
          await supabase.from('resenas').select().eq('id_chofer', user.id);
      double calificacion = 0.0;
      if ((resenas as List).isNotEmpty) {
        double suma = 0.0;
        for (final resena in resenas) {
          suma += double.tryParse(resena['calificacion'].toString()) ?? 0.0;
        }
        calificacion = suma / resenas.length;
      }

      setState(() {
        _totalViajes = totalViajes;
        _ingresosTotal = ingresosTotal;
        _ingresosHoy = ingresosHoy;
        _calificacionPromedio = calificacion;
      });
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
    }
  }

  Future<void> _actualizarPerfil() async {
    try {
      await supabase.from('choferes').update({
        'nombre_completo': _nombreController.text,
        'numero_carnet': _licenciaController.text,
      }).eq('id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado con éxito')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _mostrarDialogoPerfil() {
    if (_perfilChofer != null) {
      _nombreController.text = _perfilChofer?['nombre_completo'] ?? '';
      _licenciaController.text = _perfilChofer?['numero_carnet'] ?? '';
    }
    showDialog(
      context: context,
      builder: (context) => ChoferProfileDialog(
        nombreController: _nombreController,
        telefonoController: _telefonoController,
        licenciaController: _licenciaController,
        email: user.email ?? '',
        onSave: _actualizarPerfil,
      ),
    );
  }
}
