import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  final _nombreRutaController = TextEditingController();
  final _origenController = TextEditingController();
  final _destinoController = TextEditingController();

  List<dynamic> _solicitudesChoferes = [];
  List<dynamic> _solicitudesPasajeros = [];
  List<dynamic> _rutasDisponibles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatosAdmin();
  }

  Future<void> _cargarDatosAdmin() async {
    setState(() => _isLoading = true);
    try {
      final choferesRes = await supabase.from('choferes').select();
      final pasajerosRes = await supabase.from('pasajeros').select();
      final rutasRes = await supabase.from('rutas').select();

      if (!mounted) return;

      setState(() {
        _solicitudesChoferes = choferesRes as List;
        _solicitudesPasajeros = pasajerosRes as List;
        _rutasDisponibles = rutasRes as List;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cargar datos: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cambiarEstadoUsuario(String tabla, String id, String nuevoEstado) async {
    try {
      await supabase.from(tabla).update({'estado': nuevoEstado}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Usuario $nuevoEstado con éxito")));
      _cargarDatosAdmin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cambiar estado: $e")));
    }
  }

  Future<void> _crearNuevaRuta() async {
    if (_nombreRutaController.text.trim().isEmpty) return;
    try {
      await supabase.from('rutas').insert({
        'nombre_ruta': _nombreRutaController.text.trim(),
        'origen': _origenController.text.trim(),
        'destino': _destinoController.text.trim(),
      });
      
      _nombreRutaController.clear();
      _origenController.clear();
      _destinoController.clear();
      
      if (!mounted) return;
      Navigator.pop(context);
      _cargarDatosAdmin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al crear ruta: $e")));
    }
  }

  void _mostrarDialogoCrearRuta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Nueva Ruta"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nombreRutaController, decoration: const InputDecoration(labelText: "Nombre de la Ruta")),
            TextField(controller: _origenController, decoration: const InputDecoration(labelText: "Origen")),
            TextField(controller: _destinoController, decoration: const InputDecoration(labelText: "Destino")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(onPressed: _crearNuevaRuta, child: const Text("Guardar")),
        ],
      ),
    );
  }

  void _verDetallesDialog(dynamic usuario, bool esChofer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Detalles del ${esChofer ? 'Chofer' : 'Pasajero'}"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("ID: ${usuario['id'].toString().substring(0, 8)}..."),
              Text("Estado Actual: ${usuario['estado'] ?? 'pendiente'}"),
              if (esChofer) ...[
                Text("Licencia: ${usuario['licencia_conducir'] ?? 'S/L'}"),
                Text("Placa Bus: ${usuario['placa_bus'] ?? 'S/P'}"),
                const SizedBox(height: 10),
                Image.network(
                  usuario['foto_licencia_url'] ?? 'https://via.placeholder.com/150', 
                  height: 120, 
                  errorBuilder: (_,__,___) => const Icon(Icons.credit_card, size: 50)
                ),
              ] else ...[
                Text("Categoría: ${usuario['categoria'] ?? 'Regular'}"),
                const SizedBox(height: 10),
                Image.network(
                  usuario['foto_rostro_url'] ?? 'https://via.placeholder.com/150', 
                  height: 120, 
                  errorBuilder: (_,__,___) => const Icon(Icons.person, size: 50)
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _cambiarEstadoUsuario(esChofer ? 'choferes' : 'pasajeros', usuario['id'], 'aprobado');
            },
            child: const Text("Aprobar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _cambiarEstadoUsuario(esChofer ? 'choferes' : 'pasajeros', usuario['id'], 'rechazado');
            },
            child: const Text("Rechazar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TransPayy - Admin"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_ind), text: "Solicitudes"),
            Tab(icon: Icon(Icons.map), text: "Rutas"),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatosAdmin),
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
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    const Text("🚚 Choferes Registrados", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ..._solicitudesChoferes.map((chofer) => Card(
                      child: ListTile(
                        title: Text("Placa: ${chofer['placa_bus'] ?? 'Sin Placa'}"),
                        subtitle: Text("Estado: ${chofer['estado'] ?? 'pendiente'}"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _verDetallesDialog(chofer, true),
                      ),
                    )),
                    const SizedBox(height: 20),
                    const Text("👤 Pasajeros Registrados", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ..._solicitudesPasajeros.map((pasajero) => Card(
                      child: ListTile(
                        title: Text("Pasajero: ${pasajero['id'].toString().substring(0,8)}"),
                        subtitle: Text("Estado: ${pasajero['estado'] ?? 'pendiente'}"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _verDetallesDialog(pasajero, false),
                      ),
                    )),
                  ],
                ),
                Scaffold(
                  floatingActionButton: FloatingActionButton(
                    onPressed: _mostrarDialogoCrearRuta,
                    child: const Icon(Icons.add_location),
                  ),
                  body: ListView.builder(
                    itemCount: _rutasDisponibles.length,
                    itemBuilder: (context, index) {
                      final ruta = _rutasDisponibles[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: const Icon(Icons.alt_route, color: Colors.blue, size: 36),
                          title: Text(ruta['nombre_ruta'] ?? 'Ruta sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("De: ${ruta['origen']} a ${ruta['destino']}"),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
    );
  }
}