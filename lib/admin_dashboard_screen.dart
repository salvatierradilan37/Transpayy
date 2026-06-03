import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  final _nombreRutaController = TextEditingController();
  final _origenController = TextEditingController();
  final _destinoController = TextEditingController();
  String? _choferIdSeleccionado;
  String? _placaBusSeleccionada;

  List<dynamic> _solicitudesChoferes = [];
  List<dynamic> _solicitudesPasajeros = [];
  List<dynamic> _rutasDisponibles = [];

  int _totalViajes = 0;
  double _ingresosTotales = 0.0;
  int _usuariosActivos = 0;
  String _rutaMasUtilizada = 'N/A';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatosAdmin();
  }

  static const String _kPlaceholderMapBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

  Future<void> _cargarDatosAdmin() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('Iniciando carga de datos admin...');

      // Ejecutar todas en paralelo
      final results = await Future.wait([
        supabase.from('choferes').select().limit(50),
        supabase.from('pasajeros').select().limit(50),
        supabase.from('rutas').select().limit(50),
      ]);

      if (!mounted) return;

      setState(() {
        _solicitudesChoferes = results[0] as List;
        _solicitudesPasajeros = results[1] as List;
        _rutasDisponibles = results[2] as List;
      });

      debugPrint('Datos básicos cargados - Admin listo');
      // NO cargar estadísticas por ahora
    } catch (e) {
      debugPrint('ERROR CRÍTICO al cargar datos: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cambiarEstadoUsuario(
      String tabla, String id, String nuevoEstado) async {
    try {
      final response = await supabase
          .from(tabla)
          .update({'estado': nuevoEstado})
          .eq('id', id)
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception(
            'No se pudo actualizar: fila no encontrada o permiso denegado.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario $nuevoEstado con éxito')));
      await _cargarDatosAdmin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cambiar estado: $e')));
    }
  }

  Future<void> _crearNuevaRuta() async {
    if (_nombreRutaController.text.trim().isEmpty ||
        _choferIdSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Por favor completa todos los campos y selecciona un chofer')),
      );
      return;
    }
    try {
      await supabase.from('rutas').insert({
        'nombre_ruta': _nombreRutaController.text.trim(),
        'origen': _origenController.text.trim(),
        'destino': _destinoController.text.trim(),
        'chofer_id': _choferIdSeleccionado,
        'bus_placa': _placaBusSeleccionada,
      });

      _nombreRutaController.clear();
      _origenController.clear();
      _destinoController.clear();
      _choferIdSeleccionado = null;
      _placaBusSeleccionada = null;

      if (!mounted) return;
      Navigator.pop(context);
      _cargarDatosAdmin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al crear ruta: $e')));
    }
  }

  Future<void> _editarRuta(
      String rutaId, Map<String, dynamic> rutaActual) async {
    _nombreRutaController.text = rutaActual['nombre_ruta'] ?? '';
    _origenController.text = rutaActual['origen'] ?? '';
    _destinoController.text = rutaActual['destino'] ?? '';
    _choferIdSeleccionado = rutaActual['chofer_id'];
    _placaBusSeleccionada = rutaActual['bus_placa'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Ruta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreRutaController,
                decoration:
                    const InputDecoration(labelText: 'Nombre de la Ruta'),
              ),
              TextField(
                controller: _origenController,
                decoration: const InputDecoration(labelText: 'Origen'),
              ),
              TextField(
                controller: _destinoController,
                decoration: const InputDecoration(labelText: 'Destino'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _choferIdSeleccionado,
                decoration:
                    const InputDecoration(labelText: 'Seleccionar Chofer'),
                items: _solicitudesChoferes
                    .where((c) => c['estado'] == 'aprobado')
                    .map<DropdownMenuItem<String>>((chofer) => DropdownMenuItem(
                          value: chofer['id'].toString(),
                          child: Text(
                              '${chofer['id'].toString().substring(0, 8)}... - ${chofer['placa_bus'] ?? 'Sin placa'}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  _choferIdSeleccionado = value;
                  if (value != null) {
                    final chofer = _solicitudesChoferes
                        .firstWhere((c) => c['id'].toString() == value);
                    _placaBusSeleccionada = chofer['placa_bus'];
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _nombreRutaController.clear();
              _origenController.clear();
              _destinoController.clear();
              _choferIdSeleccionado = null;
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await supabase.from('rutas').update({
                  'nombre_ruta': _nombreRutaController.text.trim(),
                  'origen': _origenController.text.trim(),
                  'destino': _destinoController.text.trim(),
                  'chofer_id': _choferIdSeleccionado,
                  'bus_placa': _placaBusSeleccionada,
                }).eq('id', rutaId);

                _nombreRutaController.clear();
                _origenController.clear();
                _destinoController.clear();
                _choferIdSeleccionado = null;

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ruta actualizada con éxito')),
                );
                _cargarDatosAdmin();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al actualizar: $e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarRuta(String rutaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Ruta'),
        content: const Text('¿Estás seguro de que deseas eliminar esta ruta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await supabase.from('rutas').delete().eq('id', rutaId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ruta eliminada con éxito')),
        );
        _cargarDatosAdmin();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  void _mostrarDialogoCrearRuta() {
    _choferIdSeleccionado = null;
    _placaBusSeleccionada = null;
    _nombreRutaController.clear();
    _origenController.clear();
    _destinoController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Nueva Ruta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreRutaController,
                decoration:
                    const InputDecoration(labelText: 'Nombre de la Ruta'),
              ),
              TextField(
                controller: _origenController,
                decoration: const InputDecoration(labelText: 'Origen'),
              ),
              TextField(
                controller: _destinoController,
                decoration: const InputDecoration(labelText: 'Destino'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _choferIdSeleccionado,
                decoration:
                    const InputDecoration(labelText: 'Seleccionar Chofer'),
                hint: const Text('Elige un chofer'),
                items: _solicitudesChoferes
                    .where((c) => c['estado'] == 'aprobado')
                    .map<DropdownMenuItem<String>>((chofer) => DropdownMenuItem(
                          value: chofer['id']?.toString(),
                          child: Text(
                              '${chofer['id'].toString().substring(0, 8)}... - ${chofer['placa_bus'] ?? 'Sin placa'}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  _choferIdSeleccionado = value;
                  if (value != null) {
                    final chofer = _solicitudesChoferes
                        .firstWhere((c) => c['id'].toString() == value);
                    _placaBusSeleccionada = chofer['placa_bus'];
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _crearNuevaRuta,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCheckbox(
      String label, bool value, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(color: Colors.white)),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: Colors.greenAccent,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _verDetallesDialog(dynamic usuario, bool esChofer) {
    bool faceVerified = false;
    bool licenseVerified = false;
    bool carnetVerified = false;
    bool busVerified = false;
    bool estudianteVerified = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Detalles del ${esChofer ? 'Chofer' : 'Pasajero'}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ID: ${usuario['id'].toString().substring(0, 8)}...'),
                const SizedBox(height: 8),
                Text('Estado Actual: ${usuario['estado'] ?? 'pendiente'}'),
                const SizedBox(height: 16),
                Text('Documentos enviados',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 10),
                if (esChofer) ...[
                  Text(
                      'Foto de rostro: ${usuario['foto_rostro_url'] ?? 'No disponible'}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                      'Foto de licencia: ${usuario['foto_licencia_url'] ?? 'No disponible'}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                      'Foto de carnet: ${usuario['foto_carnet_url'] ?? 'No disponible'}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                      'Foto del bus: ${usuario['foto_bus_url'] ?? 'No disponible'}',
                      style: const TextStyle(color: Colors.white70)),
                ] else ...[
                  Text(
                      'Foto de rostro: ${usuario['foto_rostro_url'] ?? 'No disponible'}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                      'Foto de carnet: ${usuario['foto_carnet_url'] ?? 'No disponible'}',
                      style: const TextStyle(color: Colors.white70)),
                  if (usuario['categoria'] == 'estudiante') ...[
                    const SizedBox(height: 8),
                    Text(
                        'Foto de carnet estudiantil: ${usuario['foto_universitario_url'] ?? 'No disponible'}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ],
                const SizedBox(height: 18),
                Text('Verificación visual',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                _buildVerificationCheckbox('Face match', faceVerified, (value) {
                  setDialogState(() {
                    faceVerified = value ?? false;
                  });
                }),
                if (esChofer) ...[
                  _buildVerificationCheckbox('Licencia válida', licenseVerified,
                      (value) {
                    setDialogState(() {
                      licenseVerified = value ?? false;
                    });
                  }),
                  _buildVerificationCheckbox('Carnet válido', carnetVerified,
                      (value) {
                    setDialogState(() {
                      carnetVerified = value ?? false;
                    });
                  }),
                  _buildVerificationCheckbox('Bus visible', busVerified,
                      (value) {
                    setDialogState(() {
                      busVerified = value ?? false;
                    });
                  }),
                ] else ...[
                  _buildVerificationCheckbox('Carnet válido', carnetVerified,
                      (value) {
                    setDialogState(() {
                      carnetVerified = value ?? false;
                    });
                  }),
                  if (usuario['categoria'] == 'estudiante')
                    _buildVerificationCheckbox(
                        'Carnet universitario válido', estudianteVerified,
                        (value) {
                      setDialogState(() {
                        estudianteVerified = value ?? false;
                      });
                    }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _cambiarEstadoUsuario(esChofer ? 'choferes' : 'pasajeros',
                    usuario['id'], 'rechazado');
              },
              child: const Text('Rechazar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: faceVerified &&
                      carnetVerified &&
                      (esChofer ? licenseVerified && busVerified : true) &&
                      (esChofer ||
                          usuario['categoria'] != 'estudiante' ||
                          estudianteVerified)
                  ? () {
                      Navigator.pop(context);
                      _cambiarEstadoUsuario(esChofer ? 'choferes' : 'pasajeros',
                          usuario['id'], 'aprobado');
                    }
                  : null,
              child: const Text('Aprobar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsuarioCard(dynamic usuario, bool esChofer) {
    final estado = usuario['estado'] ?? 'pendiente';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade700,
          child: Icon(esChofer ? Icons.drive_eta : Icons.person,
              color: Colors.white),
        ),
        title: Text(
            esChofer
                ? 'Placa: ${usuario['placa_bus'] ?? 'Sin placa'}'
                : 'Pasajero: ${usuario['id'].toString().substring(0, 8)}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('Estado: ${estado.toUpperCase()}',
            style: const TextStyle(color: Colors.white70)),
        trailing:
            Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
        onTap: () => _verDetallesDialog(usuario, esChofer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07132A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('TransPayy Admin',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _cargarDatosAdmin),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await supabase.auth.signOut();
              navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF40E0FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_ind), text: 'Solicitudes'),
            Tab(icon: Icon(Icons.map), text: 'Rutas'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Dashboard'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choferes registrados',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ..._solicitudesChoferes
                          .map((chofer) => _buildUsuarioCard(chofer, true)),
                      const SizedBox(height: 20),
                      Text('Pasajeros registrados',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ..._solicitudesPasajeros.map(
                          (pasajero) => _buildUsuarioCard(pasajero, false)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  floatingActionButton: FloatingActionButton(
                    onPressed: _mostrarDialogoCrearRuta,
                    backgroundColor: const Color(0xFF40E0FF),
                    child: const Icon(Icons.add_location),
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rutas activas',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (_rutasDisponibles.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('No hay rutas registradas aun.',
                                style: TextStyle(color: Colors.white70)),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _rutasDisponibles.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final ruta = _rutasDisponibles[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  ruta['nombre_ruta'] ??
                                                      'Ruta sin nombre',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'Origen: ${ruta['origen'] ?? '-'}',
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12)),
                                              Text(
                                                  'Destino: ${ruta['destino'] ?? '-'}',
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12)),
                                              if (ruta['bus_placa'] != null)
                                                Text(
                                                    'Bus: ${ruta['bus_placa']}',
                                                    style: const TextStyle(
                                                        color:
                                                            Colors.cyanAccent,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueAccent,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                          icon:
                                              const Icon(Icons.edit, size: 16),
                                          label: const Text('Editar'),
                                          onPressed: () =>
                                              _editarRuta(ruta['id'], ruta),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.delete,
                                              size: 16),
                                          label: const Text('Eliminar'),
                                          onPressed: () =>
                                              _eliminarRuta(ruta['id']),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estadísticas del Sistema',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _buildStatCard('Total Viajes', '$_totalViajes',
                              Colors.blueAccent),
                          _buildStatCard(
                              'Ingresos',
                              '${_ingresosTotales.toStringAsFixed(2)} Bs',
                              Colors.greenAccent),
                          _buildStatCard('Usuarios Activos',
                              '$_usuariosActivos', Colors.orangeAccent),
                          _buildStatCard('Ruta Más Usada', _rutaMasUtilizada,
                              Colors.purpleAccent),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen Rápido',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.people,
                                    color: Colors.cyanAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Choferes: ${_solicitudesChoferes.length}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.person,
                                    color: Colors.cyanAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Pasajeros: ${_solicitudesPasajeros.length}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.map,
                                    color: Colors.cyanAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Rutas: ${_rutasDisponibles.length}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
                // Tab 4: Transacciones
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
