import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> verificarYAceptarTerminos(
  BuildContext context, {
  bool forzarMostrar = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final bool yaAcepto = prefs.getBool('terminos_aceptados_v2') ?? false;

  if (yaAcepto && !forzarMostrar) return true;
  if (!context.mounted) return false;

  final bool? resultado = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Obliga a leer y aceptar
    builder: (ctx) {
      bool checkAcepto = false;
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(Icons.gavel, color: Color(0xFF00B4D8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Términos y Normas de Uso',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bienvenido a Guía del Norte. Para mantener una comunidad segura y familiar en Tartagal, todo usuario o anunciante debe cumplir estas normas:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Prohibición de Contenido Adulto o Inapropiado:\n'
                    'Está estrictamente prohibido subir fotos, videos, textos o enlaces con desnudez, contenido sexual/erótico ("hot"), prostitución o violencia.\n\n'
                    '2. Prohibición de Actividades Ilegales:\n'
                    'No se permite la venta de artículos ilegales, sustancias prohibidas, juego clandestino ni perfiles falsos con fines de estafa.\n\n'
                    '3. Revisión y Sanciones (Baneo Permanente):\n'
                    'Todo perfil comercial pasa por revisión antes de ser visible. Si un usuario infringe estas normas o recibe denuncias comprobadas, su perfil será eliminado y su cuenta será bloqueada de forma permanente sin derecho a reembolso.\n\n'
                    '4. Responsabilidad del Servicio:\n'
                    'Guía del Norte actúa como directorio publicitario local. Los acuerdos comerciales son responsabilidad exclusiva entre el profesional y el cliente.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF00B4D8),
                    value: checkAcepto,
                    onChanged: (val) =>
                        setDialogState(() => checkAcepto = val ?? false),
                    title: const Text(
                      'He leído y acepto los Términos y Condiciones y me comprometo a no publicar contenido inapropiado.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (forzarMostrar)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                ),
                onPressed: checkAcepto
                    ? () async {
                        await prefs.setBool('terminos_aceptados_v2', true);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      }
                    : null,
                child: const Text('Aceptar y Continuar'),
              ),
            ],
          );
        },
      );
    },
  );

  return resultado ?? false;
}
