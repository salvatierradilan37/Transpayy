import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecargaScreen extends StatelessWidget {
  final TextEditingController _montoController = TextEditingController();

  RecargaScreen({super.key});

  Future<void> recargar(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser!;
    final monto = double.tryParse(_montoController.text) ?? 0;

    // 1. Obtener saldo actual y sumar
    final res = await Supabase.instance.client
        .from('billetera')
        .select('saldo')
        .eq('id_usuario', user.id)
        .single();
    double nuevoSaldo = (res['saldo'] as num).toDouble() + monto;

    // 2. Actualizar billetera
    await Supabase.instance.client
        .from('billetera')
        .update({'saldo': nuevoSaldo}).eq('id_usuario', user.id);

    // 3. Registrar en historial como recarga
    await Supabase.instance.client.from('transacciones').insert({
      'pasajero_id': user.id,
      'monto': monto,
      'tipo': 'recarga',
      'fecha': DateTime.now().toIso8601String(),
    });

    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Recarga exitosa")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recargar Saldo")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _montoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: "Monto a recargar"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () => recargar(context),
                  child: const Text("Confirmar Recarga")),
            ],
          ),
        ),
      ),
    );
  }
}
