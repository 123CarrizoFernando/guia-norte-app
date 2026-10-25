import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import 'perfil_detalle_screen.dart';

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

        if (_filtroActual == 'revision') {
          return n['estado_cuenta'] == 'en_revision';
        } else if (_filtroActual == 'reportados') {
          return (n['total_reportes'] ?? 0) > 0;
        } else if (_filtroActual == 'suspendidos') {
          return n['estado_cuenta'] == 'suspendido';
        } else if (_filtroActual == 'pendientes') {
          return n['estado_pago'] == 'pendiente';
        } else if (_filtroActual == 'baneados') {
          return n['estado_cuenta'] == 'baneado';
        }
        return true;
      }).toList();
    });
  }

  Future<void> _cambiarEstadoCuenta(int perfilId, String nuevoEstado) async {
    try {
      final res = await http.put(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/admin/perfiles/$perfilId/estado-cuenta',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'estado_cuenta': nuevoEstado}),
      );

      if (res.statusCode == 200 && mounted) {
        String textoMensaje =
            '✅ Perfil rehabilitado, reportes limpiados y visible al público.';
        Color colorSnack = Colors.green;

        if (nuevoEstado == 'suspendido') {
          textoMensaje =
              '⏸️ Perfil puesto en SUSPENSIÓN temporal (oculto al público).';
          colorSnack = Colors.deepOrange;
        } else if (nuevoEstado == 'en_revision') {
          textoMensaje = '🔍 Perfil puesto en revisión.';
          colorSnack = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(textoMensaje), backgroundColor: colorSnack),
        );
        await cargarNegocios();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error del servidor: ${res.body}'),
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

  Future<void> _enviarRecordatorioDePagoMasivo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔔 Recordar Pago Mensual (Día 1 al 10)'),
        content: const Text(
          '¿Quieres enviar una notificación Push a todos los comercios con Plan Medio y Premium recordándoles abonar la renovación del mes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar Recordatorio'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final res = await http.post(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/admin/recordar-pagos',
        ),
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Recordatorio enviado a ${data['enviados'] ?? 0} comercios activos!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error enviando recordatorios: $e');
    }
  }

  Future<void> _banearParaSiempre(Map<String, dynamic> negocio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🚫 ¿Banear cuenta para siempre?'),
        content: Text(
          'Estás por bloquear permanentemente a "${negocio['nombre_comercial']}" (${negocio['email'] ?? 'Sin email'}).\n\n'
          '• Su perfil desaparecerá de la guía.\n'
          '• Su cuenta de Google quedará bloqueada para que no pueda volver a ingresar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Banear Permanentemente'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final res = await http.post(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/admin/perfiles/${negocio['id']}/banear',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'motivo': 'Contenido inapropiado / Violación de normas',
        }),
      );
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚫 Usuario y perfil baneados para siempre.'),
            backgroundColor: Colors.red,
          ),
        );
        cargarNegocios();
      }
    } catch (e) {
      debugPrint('Error baneando: $e');
    }
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
        '¡Hola *$nombreComercial*! ✅ Verificamos tu perfil y depósito. Ya dimos de alta tu *$planNombre* en *Guía del Norte*. '
        '${vencimiento != null ? "Tu suscripción está cubierta hasta el $vencimiento." : ""} ¡Gracias por confiar en nosotros!';
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

        if (nuevoPlanId > 1) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('✅ Alta Confirmada'),
              content: Text(
                'Se activó el plan para "${negocio['nombre_comercial']}" (Vence: ${fechaVenc ?? "día 10"}).\n\n¿Quieres enviarle confirmación por WhatsApp?',
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
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _mostrarOpcionesDePlan(Map<String, dynamic> negocio) {
    final String nombreComercial = negocio['nombre_comercial'] ?? 'Local';
    final int planSolicitado = negocio['plan_solicitado_id'] ?? 2;
    final String? estadoPago = negocio['estado_pago'];
    final String estadoCuenta = negocio['estado_cuenta'] ?? 'activo';
    final int reportes = negocio['total_reportes'] ?? 0;
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
        return SingleChildScrollView(
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
              const SizedBox(height: 10),

              // 1. INSPECCIONAR PERFIL COMPLETO
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.visibility, color: Color(0xFF0077B6)),
                  label: const Text(
                    '👁️ Inspeccionar Perfil Completo (Ver Fotos y Datos)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PerfilDetalleScreen(
                          perfil: negocio,
                          currentUserId: 1,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // 2. REHABILITAR PERFIL Y LIMPIAR REPORTES (SI TIENE REPORTES O NO ESTÁ ACTIVO)
              if (estadoCuenta != 'activo' || reportes > 0) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.verified_user),
                    label: Text(
                      reportes > 0
                          ? '✅ Rehabilitar Perfil y Limpiar Reportes ($reportes)'
                          : '✅ Aprobar / Rehabilitar Perfil al Público',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _cambiarEstadoCuenta(negocio['id'], 'activo');
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 3. PONER EN SUSPENSIÓN TEMPORAL (SI ESTÁ ACTIVO)
              if (estadoCuenta != 'suspendido') ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange),
                    ),
                    icon: const Icon(Icons.pause_circle_filled),
                    label: const Text(
                      '⏸️ Poner Perfil en Suspensión Temporal (Ocultar)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _cambiarEstadoCuenta(negocio['id'], 'suspendido');
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (estadoPago == 'pendiente') ...[
                const SizedBox(height: 8),
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
                        '⚠️ Solicitud de Pago: Plan ${planSolicitado == 3 ? "Premium" : "Medio"}',
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
                        'Método: $metodoPago',
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
                        height: 44,
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

              const SizedBox(height: 14),
              const Text(
                'Cambiar Plan Manualmente (Renueva mes hasta el día 10):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.looks_one, color: Colors.grey),
                title: const Text('Bajar a Plan Básico (Gratis - 3 Fotos)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarPlan(negocio, 1, estadoPago: 'aprobado');
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.looks_two, color: Colors.blue),
                title: const Text(
                  'Activar Plan Medio (\$5.000 / mes - 10 Fotos)',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarPlan(negocio, 2, periodoPago: 'mensual');
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text(
                  'Activar Plan Premium (\$20.000 / mes - 20 Fotos + 2 Videos)',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarPlan(negocio, 3, periodoPago: 'mensual');
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.workspace_premium,
                  color: Colors.purple,
                ),
                title: const Text('Activar Plan ANUAL (Cubre 1 año completo)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  cambiarPlan(negocio, 3, periodoPago: 'anual');
                },
              ),
              const Divider(),

              // 4. BOTÓN DE BANEO PERMANENTE
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  icon: const Icon(Icons.block),
                  label: const Text(
                    '🚫 BANEAR CUENTA Y PERFIL PARA SIEMPRE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _banearParaSiempre(negocio);
                  },
                ),
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
        title: const Text('Moderación, Planes y Pagos'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Enviar recordatorio de pago del mes',
            onPressed: _enviarRecordatorioDePagoMasivo,
          ),
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
                hintText: 'Buscar por nombre, titular o teléfono...',
                prefixIcon: const Icon(Icons.search),
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
                  label: const Text('🔍 Por Aprobar Alta'),
                  selected: _filtroActual == 'revision',
                  selectedColor: Colors.teal.shade100,
                  onSelected: (_) {
                    setState(() => _filtroActual = 'revision');
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🚩 Reportados'),
                  selected: _filtroActual == 'reportados',
                  selectedColor: Colors.red.shade100,
                  onSelected: (_) {
                    setState(() => _filtroActual = 'reportados');
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('⏸️ Suspendidos'),
                  selected: _filtroActual == 'suspendidos',
                  selectedColor: Colors.orange.shade200,
                  onSelected: (_) {
                    setState(() => _filtroActual = 'suspendidos');
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('⏳ Pagos Pendientes'),
                  selected: _filtroActual == 'pendientes',
                  selectedColor: Colors.amber.shade200,
                  onSelected: (_) {
                    setState(() => _filtroActual = 'pendientes');
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🚫 Baneados'),
                  selected: _filtroActual == 'baneados',
                  onSelected: (_) {
                    setState(() => _filtroActual = 'baneados');
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
                ? const Center(child: Text('No hay perfiles en esta sección'))
                : ListView.builder(
                    itemCount: negociosFiltrados.length,
                    itemBuilder: (context, index) {
                      final n = negociosFiltrados[index];
                      final bool esPendiente = n['estado_pago'] == 'pendiente';
                      final String estadoCuenta =
                          n['estado_cuenta'] ?? 'activo';
                      final int reportes = n['total_reportes'] ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: reportes > 0
                              ? const BorderSide(color: Colors.red, width: 2)
                              : (estadoCuenta == 'suspendido'
                                    ? const BorderSide(
                                        color: Colors.deepOrange,
                                        width: 1.8,
                                      )
                                    : (estadoCuenta == 'en_revision'
                                          ? const BorderSide(
                                              color: Colors.teal,
                                              width: 1.5,
                                            )
                                          : BorderSide.none)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: n['logo_url'] != null
                                ? NetworkImage(n['logo_url'])
                                : null,
                            child: n['logo_url'] == null
                                ? const Icon(Icons.store)
                                : null,
                          ),
                          title: Text(
                            n['nombre_comercial'] ?? 'Sin nombre',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estado: ${estadoCuenta.toUpperCase()} • Plan: ${n['plan_nombre']}',
                              ),
                              if (n['fecha_vencimiento_plan'] != null &&
                                  (n['plan_id'] ?? 1) > 1)
                                Text(
                                  '📅 Vence: ${n['fecha_vencimiento_plan'].toString().split('T')[0]}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              if (reportes > 0)
                                Text(
                                  '🚩 Tiene $reportes reporte(s) de usuarios',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (esPendiente)
                                Text(
                                  '⚠️ Pago pendiente: Plan ${n['plan_solicitado_id'] == 3 ? "Premium" : "Medio"}',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _mostrarOpcionesDePlan(n),
                            child: const Text('Revisar'),
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
