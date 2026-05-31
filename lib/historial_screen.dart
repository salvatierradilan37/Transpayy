import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Asegúrate de importar el archivo donde creaste DetalleTransaccionScreen
import 'detalle_transaccion_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _pagosKey = GlobalKey();
  final GlobalKey _recargasKey = GlobalKey();

  DateTime? _parseFecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    if (valor is String) {
      try {
        return DateTime.parse(valor);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _esHoyOAyer(dynamic item) {
    final fecha = _parseFecha(item['fecha']);
    if (fecha == null) return false;
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final ayer = hoy.subtract(const Duration(days: 1));
    final entrada = DateTime(fecha.year, fecha.month, fecha.day);
    return entrada == hoy || entrada == ayer;
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;

    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.0,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Historial de Pagos")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('transacciones')
            .stream(primaryKey: ['id'])
            .eq('pasajero_id', user!.id)
            .order('fecha', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("No se encontraron movimientos.",
                  textAlign: TextAlign.center),
            );
          }

          final transacciones = snapshot.data!;
          final recientes =
              transacciones.where(_esHoyOAyer).toList(growable: false);
          final pagos = recientes.where((t) {
            final tipo = t['tipo']?.toString().toLowerCase();
            return tipo == 'pago' || tipo == 'debito';
          }).toList(growable: false);
          final recargas = recientes.where((t) {
            final tipo = t['tipo']?.toString().toLowerCase();
            return tipo == 'recarga' || tipo == 'credito';
          }).toList(growable: false);

          if (pagos.isEmpty && recargas.isEmpty) {
            return const Center(
              child: Text(
                "No se encontraron movimientos.",
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Seleccione una sección',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: pagos.isNotEmpty
                                  ? () => _scrollToSection(_pagosKey)
                                  : null,
                              child: const Text('Ir a Pagos'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: recargas.isNotEmpty
                                  ? () => _scrollToSection(_recargasKey)
                                  : null,
                              child: const Text('Ir a Recargas'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (pagos.isNotEmpty) ...[
                Container(
                  key: _pagosKey,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Text('Pagos de pasaje',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                for (final t in pagos)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetalleTransaccionScreen(transaccion: t),
                          ),
                        );
                      },
                      leading: const Icon(Icons.directions_bus,
                          color: Colors.red, size: 30),
                      title: const Text('Pago de Pasaje'),
                      subtitle: Text(
                        'Fecha: ${t['fecha']?.toString().substring(0, 16) ?? '-'}',
                      ),
                      trailing: Text(
                        '-${t['monto']} Bs',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
              ],
              if (recargas.isNotEmpty) ...[
                Container(
                  key: _recargasKey,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Text('Recargas de saldo',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                for (final t in recargas)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetalleTransaccionScreen(transaccion: t),
                          ),
                        );
                      },
                      leading: const Icon(Icons.add_circle,
                          color: Colors.green, size: 30),
                      title: const Text('Recarga de Saldo'),
                      subtitle: Text(
                        'Fecha: ${t['fecha']?.toString().substring(0, 16) ?? '-'}',
                      ),
                      trailing: Text(
                        '+${t['monto']} Bs',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
