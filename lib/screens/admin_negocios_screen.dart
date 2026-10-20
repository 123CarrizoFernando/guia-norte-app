import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

class AdminNegociosScreen extends StatefulWidget {
  const AdminNegociosScreen({super.key});

  @override
  State<AdminNegociosScreen> createState() => _AdminNegociosScreenState();
}

class _AdminNegociosScreenState extends State<AdminNegociosScreen> {
  List<dynamic> negocios = [];
  List<dynamic> negociosFiltrados = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _filtroActual = 'todos';

  @override
  void initState() {
    super.initState();
    cargarNegocios();
  }

  Future<void> cargarNegocios() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://guia-norte-backend.onrender.com/api/admin/perfiles'),
      );
      if (response.statusCode == 200) {
        setState(() {
          negocios = json.decode(response.body);
          _aplicarFiltros();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  void _aplicarFiltros() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      negociosFiltrados = negocios.where((n) {
        final nombre = (n['nombre_comercial'] ?? '').toString().toLowerCase();
        final telefono = (n['telefono_contacto'] ?? '')
            .toString()
            .toLowerCase();
        final titular = (n['nombre_completo'] ?? '').toString().toLowerCase();
        final coincideTexto =
            nombre.contains(query) ||
            telefono.contains(query) ||
            titular.contains(query);

        if (!coincideTexto) return false;

        if (_filtroActual == 'pendientes') {
          return n['estado_pago'] == 'pendiente';
        } else if (_filtroActual == 'pagos') {
          return (n['plan_id'] == 2 || n['plan_id'] == 3);
        }
        return true;
      }).toList();
    });
  }

  Future<void> _notificarPorWhatsApp(
    String? telefono,
    String nombreComercial,
    int planId,
    String? vencimiento,
  ) async {
    if (telefono == null || telefono.trim().isEmpty) return;
    final telLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final planNombre = planId == 3 ? 'Plan Premium' : 'Plan Medio';
    final mensaje =
        '¡Hola *$nombreComercial*! ✅ Verificamos tu depósito y ya dimos de alta tu *$planNombre* en *Guía del Norte*. '
        '${vencimiento != null ? "Tu suscripción está cubierta y el próximo vencimiento es el $vencimiento." : ""} ¡Gracias por confiar en nosotros!';
    final url = Uri.parse(
      'https://wa.me/$telLimpio?text=${Uri.encodeComponent(mensaje)}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> cambiarPlan(
    Map<String, dynamic> negocio,
    int nuevoPlanId, {
    String estadoPago = 'aprobado',
    String? periodoPago,
  }) async {
    final int perfilId = negocio['id'];
    try {
      final response = await http.put(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/admin/perfiles/$perfilId/plan',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'plan_id': nuevoPlanId,
          'estado_pago': estadoPago,
          'plan_solicitado_id': nuevoPlanId,
          'periodo_pago': periodoPago ?? negocio['periodo_pago'] ?? 'mensual',
        }),
      );

      if (response.statusCode == 200) {
        final respData = json.decode(response.body);
        final String? fechaVenc = respData['fecha_vencimiento_plan'];
        if (!mounted) return;

        await cargarNegocios();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoPlanId == 3
                  ? '¡Plan Premium activado! Se envió notificación a todos los usuarios.'
                  : '¡Plan actualizado con éxito!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Si se aprobó un plan pago, ofrecer avisarle por WhatsApp al instante
        if (nuevoPlanId > 1) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('✅ Alta Confirmada'),
              content: Text(
                'Se activó el plan para "${negocio['nombre_comercial']}" y se envió la notificación Push.\n\n¿Quieres enviarle también el mensaje de confirmación por WhatsApp?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Avisar por WhatsApp'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _notificarPorWhatsApp(
                      negocio['telefono_contacto']?.toString(),
                      negocio['nombre_comercial'] ?? '',
                      nuevoPlanId,
                      fechaVenc,
                    );
                  },
                ),
              ],
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error del servidor: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarOpcionesDePlan(Map<String, dynamic> negocio) {
    final String nombreComercial = negocio['nombre_comercial'] ?? 'Local';
    final int planSolicitado = negocio['plan_solicitado_id'] ?? 2;
    final String? estadoPago = negocio['estado_pago'];
    final String metodoPago = negocio['metodo_pago'] ?? 'No especificado';
    final String comprobante = negocio['comprobante_info'] ?? 'Sin detalle';
    final String periodo = (negocio['periodo_pago'] ?? 'mensual') == 'anual'
        ? 'ANUAL (12 meses)'
        : 'MENSUAL (Vence día 10 mes sig.)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestionar: $nombreComercial',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (estadoPago == 'pendiente') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepOrange, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ Solicitud Pendiente: Plan ${planSolicitado == 3 ? "Premium" : "Medio"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Modalidad: $periodo',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Método elegido: $metodoPago',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      Text(
                        'Ref / Comprobante: $comprobante',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_circle),
                          label: const Text(
                            'Confirmar Depósito y Dar de Alta',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            cambiarPlan(
                              negocio,
                              planSolicitado > 1 ? planSolicitado : 2,
                              estadoPago: 'aprobado',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Cambiar Plan Manualmente (Alta / Baja):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.looks_one, color: Colors.grey),
                title: const Text('Dar de Baja a Plan Básico (Gratis)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarPlan(negocio, 1, estadoPago: 'aprobado');
                },
              ),
              ListTile(
                leading: const Icon(Icons.looks_two, color: Colors.blue),
                title: const Text('Dar de Alta: Plan Medio (\$5.000 / mes)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarPlan(
                    negocio,
                    2,
                    estadoPago: 'aprobado',
                    periodoPago: 'mensual',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Dar de Alta: Plan Premium (\$20.000 / mes)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarPlan(
                    negocio,
                    3,
                    estadoPago: 'aprobado',
                    periodoPago: 'mensual',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.workspace_premium,
                  color: Colors.purple,
                ),
                title: const Text('Dar de Alta: Plan ANUAL (12 Meses)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarPlan(
                    negocio,
                    3,
                    estadoPago: 'aprobado',
                    periodoPago: 'anual',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Planes y Pagos'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cargarNegocios,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _aplicarFiltros(),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre de local o teléfono...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _aplicarFiltros();
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Todos (${negocios.length})'),
                  selected: _filtroActual == 'todos',
                  onSelected: (_) {
                    setState(() => _filtroActual = 'todos');
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('⏳ Pendientes de Verificación'),
                  selected: _filtroActual == 'pendientes',
                  selectedColor: Colors.orange.shade200,
                  onSelected: (_) {
                    setState(() => _filtroActual = 'pendientes');
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('⭐ Con Plan Pago'),
                  selected: _filtroActual == 'pagos',
                  selectedColor: Colors.blue.shade100,
                  onSelected: (_) {
                    setState(() => _filtroActual = 'pagos');
                    _aplicarFiltros();
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : negociosFiltrados.isEmpty
                ? const Center(
                    child: Text('No se encontraron comercios con ese filtro'),
                  )
                : ListView.builder(
                    itemCount: negociosFiltrados.length,
                    itemBuilder: (context, index) {
                      final n = negociosFiltrados[index];
                      final bool esPendiente = n['estado_pago'] == 'pendiente';

                      Color colorPlan = Colors.grey;
                      if (n['plan_id'] == 2) colorPlan = Colors.blue;
                      if (n['plan_id'] == 3) colorPlan = Colors.amber.shade800;
                      if (esPendiente) colorPlan = Colors.deepOrange;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: esPendiente
                              ? const BorderSide(
                                  color: Colors.deepOrange,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          title: Text(
                            n['nombre_comercial'] ?? 'Sin nombre',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Plan activo: ${n['plan_nombre']}'),
                              if (n['fecha_vencimiento_plan'] != null &&
                                  n['plan_id'] > 1)
                                Text(
                                  '📅 Vence: ${n['fecha_vencimiento_plan'].toString().split('T')[0]}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (esPendiente)
                                Text(
                                  '⚠️ Pide alta en Plan ${n['plan_solicitado_id'] == 3 ? "Premium" : "Medio"} (${n['periodo_pago'] ?? "mensual"}) - ${n['metodo_pago'] ?? ""}',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorPlan,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _mostrarOpcionesDePlan(n),
                            child: Text(
                              esPendiente ? 'Verificar' : 'Gestionar',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
