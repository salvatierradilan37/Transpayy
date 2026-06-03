import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import 'notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = Supabase.instance.client.auth.currentUser!;
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isLoading = true;
  double _saldoBilletera = 0.0;
  String _estadoPasajero = 'pendiente';
  String _nombreCompleto = 'Cargando...';
  String _emailUsuario = '';
  String _fotoRostroUrl = '';
  String _categoriaPasajero = 'Regular';

  List<dynamic> _historialViajes = [];
  List<dynamic> _rutasYBusenTurno = [];

  @override
  void initState() {
    super.initState();
    _emailUsuario = user.email ?? 'usuario@transpayy.com';
    _cargarDatosCompletosPasajero();
  }

  static const String _kPlaceholderMapBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosCompletosPasajero() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final pasajeroData = await supabase
          .from('pasajeros')
          .select('estado, foto_rostro_url, categoria')
          .eq('id', user.id)
          .maybeSingle();

      if (pasajeroData != null) {
        _estadoPasajero = pasajeroData['estado'] ?? 'aprobado';
        _fotoRostroUrl = pasajeroData['foto_rostro_url'] ?? '';
        _categoriaPasajero = pasajeroData['categoria'] ?? 'Regular';
        _nombreCompleto = _emailUsuario.split('@').first.toUpperCase();
      }

      if (_estadoPasajero == 'aprobado') {
        final billeteraData = await supabase
            .from('billetera')
            .select('saldo')
            .eq('id_usuario', user.id)
            .maybeSingle();

        if (billeteraData != null) {
          _saldoBilletera =
              double.tryParse(billeteraData['saldo'].toString()) ?? 0.0;
        }

        final transaccionesRes = await supabase
            .from('transacciones')
            .select()
            .eq('pasajero_id', user.id)
            .order('fecha', ascending: false);
        _historialViajes = transaccionesRes as List;

        final rutasRes = await supabase
            .from('rutas')
            .select('nombre_ruta, bus_placa, origen, destino, chofer_id');
        _rutasYBusenTurno = rutasRes as List;
      }
    } catch (e) {
      debugPrint('Error general en el dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calcularCostoPasaje() {
    switch (_categoriaPasajero.toLowerCase()) {
      case 'estudiante':
        return 1.00;
      case 'tercera_edad':
      case 'adulto mayor':
        return 1.00;
      default:
        return 2.00;
    }
  }

  bool _esViaje(dynamic item) {
    final tipo = item['tipo']?.toString().toLowerCase();
    return tipo == 'debito' || tipo == 'pago';
  }

  bool _esRecarga(dynamic item) {
    final tipo = item['tipo']?.toString().toLowerCase();
    return tipo == 'credito' || tipo == 'recarga';
  }

  Future<void> _procesarPagoPasaje(String idChofer) async {
    final double costoPasaje = _calcularCostoPasaje();

    if (_saldoBilletera < costoPasaje) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('❌ Saldo insuficiente en tu billetera digital.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nuevoSaldo = _saldoBilletera - costoPasaje;
      await supabase
          .from('billetera')
          .update({'saldo': nuevoSaldo}).eq('id_usuario', user.id);

      await supabase.from('transacciones').insert({
        'pasajero_id': user.id,
        'id_chofer': idChofer,
        'monto': costoPasaje,
        'tipo': 'debito',
        'estado': 'completado',
        'fecha': DateTime.now().toIso8601String(),
      });

      bool choferWalletActualizada = true;
      try {
        final billeteraChofer = await supabase
            .from('billetera')
            .select('saldo')
            .eq('id_usuario', idChofer)
            .maybeSingle();
        if (billeteraChofer != null) {
          final saldoActualChofer =
              double.tryParse(billeteraChofer['saldo'].toString()) ?? 0.0;
          await supabase
              .from('billetera')
              .update({'saldo': saldoActualChofer + costoPasaje}).eq(
                  'id_usuario', idChofer);
        } else {
          await supabase.from('billetera').insert({
            'id_usuario': idChofer,
            'saldo': costoPasaje,
          });
        }
      } catch (e) {
        choferWalletActualizada = false;
        debugPrint('No se pudo actualizar billetera del chofer: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(choferWalletActualizada
              ? '✅ Pasaje pagado: ${costoPasaje.toStringAsFixed(2)} Bs'
              : '✅ Pasaje pagado: ${costoPasaje.toStringAsFixed(2)} Bs (saldo chofer no pudo actualizarse automáticamente)'),
        ),
      );
      await NotificationService.instance.showNotification(
        title: 'Pago exitoso',
        body:
            'Se descontaron ${costoPasaje.toStringAsFixed(2)} Bs de tu saldo.',
      );
      _cargarDatosCompletosPasajero();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cobrar pasaje: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _mostrarConfirmacionPago(String idChofer) async {
    final costo = _calcularCostoPasaje();
    if (!mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text(
          'Vas a pagar ${costo.toStringAsFixed(2)} Bs al chofer con ID:\n$idChofer\n\nCategoría de pasajero: ${_categoriaPasajero.toUpperCase()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _procesarPagoPasaje(idChofer);
    }
  }

  Future<void> _mostrarDetalleRuta(Map<String, dynamic> ruta) async {
    final choferId = ruta['chofer_id'];
    Map<String, dynamic>? chofer;

    if (choferId != null) {
      try {
        chofer = await supabase
            .from('choferes')
            .select()
            .eq('id', choferId)
            .maybeSingle();
      } catch (e) {
        debugPrint('Error al cargar datos del chofer: $e');
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ruta['nombre_ruta'] ?? 'Detalle de la ruta'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/maps/route_passenger.png',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.white12,
                    child: Center(
                      child: Image.memory(
                        base64Decode(_kPlaceholderMapBase64),
                        height: 100,
                        width: 100,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Ruta: ${ruta['nombre_ruta'] ?? 'Sin nombre'}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('De: ${ruta['origen'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.black87)),
              Text('A: ${ruta['destino'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 16),
              if (chofer != null) ...[
                Text(
                    'Chofer: ${chofer['nombre_completo'] ?? chofer['nombre'] ?? chofer['nombre_chofer'] ?? choferId}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Estado: ${chofer['estado'] ?? 'Desconocido'}',
                    style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 6),
                Text('Placa: ${chofer['placa_bus'] ?? 'No disponible'}',
                    style: const TextStyle(color: Colors.black87)),
              ] else ...[
                const Text('Chofer: No disponible',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('No hay información del chofer asignado.',
                    style: TextStyle(color: Colors.black87)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoRecargaQR() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recargar Billetera via QR',
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Escanea o guarda este código para transferir saldo instantáneo a tu cuenta de TransPayy.'),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=TransPayyRecarga-${user.id}',
                height: 160,
                width: 160,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Monto de simulación fija: +10.00 Bs',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await supabase
                    .from('billetera')
                    .update({'saldo': _saldoBilletera + 10.00}).eq(
                        'id_usuario', user.id);
                await supabase.from('transacciones').insert({
                  'pasajero_id': user.id,
                  'monto': 10.00,
                  'tipo': 'credito',
                  'estado': 'completado',
                  'fecha': DateTime.now().toIso8601String(),
                });
                await NotificationService.instance.showNotification(
                  title: 'Recarga exitosa',
                  body: 'Se agregaron 10.00 Bs a tu billetera.',
                );
                _cargarDatosCompletosPasajero();
              } catch (e) {
                debugPrint('Error al recargar: $e');
              }
            },
            child: const Text('Simular Depósito'),
          ),
        ],
      ),
    );
  }

  Future<void> _importarQRDesdeGaleria() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) return;

      final barcodeCapture =
          await _scannerController.analyzeImage(pickedFile.path);
      if (barcodeCapture == null || barcodeCapture.barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se encontró un QR válido en la imagen.')),
        );
        return;
      }

      final String? codigoEscaneado = barcodeCapture.barcodes.first.rawValue;
      if (codigoEscaneado == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El QR no contiene datos válidos.')),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);
      _mostrarConfirmacionPago(codigoEscaneado);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar QR: $e')),
      );
    }
  }

  void _abrirEscannerQR() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return SafeArea(
          child: Container(
            height: mediaQuery.size.height * 0.75,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: mediaQuery.viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Escanea el QR del Bus',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Importar QR desde galería'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _importarQRDesdeGaleria,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty &&
                            barcodes.first.rawValue != null) {
                          final String codigoEscaneado =
                              barcodes.first.rawValue!;
                          Navigator.pop(context);
                          _mostrarConfirmacionPago(codigoEscaneado);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_estadoPasajero == 'pendiente') {
      return Scaffold(
        backgroundColor: const Color(0xFF081628),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_maybe, size: 90, color: Colors.orange),
                const SizedBox(height: 15),
                const Text('Cuenta en Revisión',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 10),
                const Text('Espera a que el administrador apruebe tu registro.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 25),
                ElevatedButton(
                    onPressed: _cargarDatosCompletosPasajero,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF40E0FF)),
                    child: const Text('Verificar ahora',
                        style: TextStyle(color: Colors.black))),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF061128),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TransPayy Pasajero',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _cargarDatosCompletosPasajero),
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
        onRefresh: _cargarDatosCompletosPasajero,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF0257A2), Color(0xFF00214D)]),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(22, 90, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          backgroundImage: _fotoRostroUrl.isNotEmpty
                              ? NetworkImage(_fotoRostroUrl)
                              : null,
                          child: _fotoRostroUrl.isEmpty
                              ? const Icon(Icons.person,
                                  size: 36, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bienvenido,',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 14)),
                              const SizedBox(height: 6),
                              Text(_nombreCompleto,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(_emailUsuario,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(_categoriaPasajero.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saldo Disponible',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${_saldoBilletera.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              const Text('Bs',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent.shade400,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.qr_code),
                            label: const Text('Recargar',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _mostrarDialogoRecargaQR,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9F00),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 24),
                        label: const Text('ESCANEAR QR DE BUS / PAGAR',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        onPressed: _abrirEscannerQR,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rutas y Choferes Disponibles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_rutasYBusenTurno.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No hay rutas disponibles.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rutasYBusenTurno.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final ruta = _rutasYBusenTurno[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '🚌 ${ruta['bus_placa'] ?? 'Sin placa'}',
                                            style: const TextStyle(
                                              color: Colors.cyanAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              ruta['origen'] ?? 'Origen',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              ruta['destino'] ?? 'Destino',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF40E0FF),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    icon:
                                        const Icon(Icons.visibility, size: 18),
                                    label: const Text(
                                      'Ver Chofer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () => _mostrarDetalleRuta(ruta),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    const Text('Historial de viajes',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final viajes = _historialViajes
                          .where(_esViaje)
                          .toList(growable: false);
                      return viajes.isEmpty
                          ? const Text('No tienes viajes registrados aún.',
                              style: TextStyle(color: Colors.white70))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: viajes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = viajes[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Monto: ${item['monto'] ?? '0.00'} Bs',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text('Fecha: ${item['fecha'] ?? '-'}',
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                      const SizedBox(height: 6),
                                      Text('Estado: ${item['estado'] ?? '-'}',
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                    ],
                                  ),
                                );
                              },
                            );
                    }),
                    const SizedBox(height: 24),
                    const Text('Historial de recargas',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final recargas = _historialViajes
                          .where(_esRecarga)
                          .toList(growable: false);
                      return recargas.isEmpty
                          ? const Text('No tienes recargas registradas aún.',
                              style: TextStyle(color: Colors.white70))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: recargas.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = recargas[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Monto: +${item['monto'] ?? '0.00'} Bs',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text('Fecha: ${item['fecha'] ?? '-'}',
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                      const SizedBox(height: 6),
                                      Text('Estado: ${item['estado'] ?? '-'}',
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                    ],
                                  ),
                                );
                              },
                            );
                    }),
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
}
