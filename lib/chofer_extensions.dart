// Extensiones para el Panel del Chofer - Perfil y Estadísticas

import 'package:flutter/material.dart';

extension ChoferDashboardExtensions on Widget {
  // Nota: Este archivo contiene los métodos que se agregarán al chofer_dashboard_screen.dart
}

class ChoferProfileDialog extends StatefulWidget {
  final TextEditingController nombreController;
  final TextEditingController telefonoController;
  final TextEditingController licenciaController;
  final String email;
  final VoidCallback onSave;

  const ChoferProfileDialog({
    required this.nombreController,
    required this.telefonoController,
    required this.licenciaController,
    required this.email,
    required this.onSave,
    super.key,
  });

  @override
  State<ChoferProfileDialog> createState() => _ChoferProfileDialogState();
}

class _ChoferProfileDialogState extends State<ChoferProfileDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF061228),
      title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.nombreController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.telefonoController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Teléfono',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.licenciaController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Número de Licencia',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Email: ${widget.email}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF40E0FF),
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            widget.onSave();
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const StatCard({
    required this.title,
    required this.value,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
