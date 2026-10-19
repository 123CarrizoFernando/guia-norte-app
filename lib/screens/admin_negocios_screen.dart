import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

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
  String _filtroActual = 'todos'; // 'todos', 'pendientes', 'pagos'

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

  Future<void> cambiarPlan(
    int perfilId,
    int nuevoPlanId, {
    String estadoPago = 'aprobado',
  }) async {
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
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan y estado actualizados con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        cargarNegocios();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cambiar plan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarOpcionesDePlan(Map<String, dynamic> negocio) {
    final int perfilId = negocio['id'];
    final String nombreComercial = negocio['nombre_comercial'] ?? 'Local';
    final int? planSolicitado = negocio['plan_solicitado_id'];
    final String? estadoPago = negocio['estado_pago'];
    final String? metodoPago = negocio['metodo_pago'];
    final String? comprobante = negocio['comprobante_info'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ Solicitud Pendiente: Plan ${planSolicitado == 2 ? "Medio (\$5.000)" : "Premium (\$20.000)"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      if (metodoPago != null)
                        Text('Método elegido: $metodoPago'),
                      if (comprobante != null && comprobante.isNotEmpty)
                        Text('Ref / Comprobante: $comprobante'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Confirmar Depósito y Dar de Alta'),
                          onPressed: () {
                            Navigator.pop(context);
                            cambiarPlan(
                              perfilId,
                              planSolicitado ?? 2,
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
                  Navigator.pop(context);
                  cambiarPlan(perfilId, 1, estadoPago: 'aprobado');
                },
              ),
              ListTile(
                leading: const Icon(Icons.looks_two, color: Colors.blue),
                title: const Text('Dar de Alta: Plan Medio (\$5.000 / mes)'),
                onTap: () {
                  Navigator.pop(context);
                  cambiarPlan(perfilId, 2, estadoPago: 'aprobado');
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Dar de Alta: Plan Premium (\$20.000 / mes)'),
                onTap: () {
                  Navigator.pop(context);
                  cambiarPlan(perfilId, 3, estadoPago: 'aprobado');
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
          // BUSCADOR SUPERIOR POR NOMBRE O LOCAL
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
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // FILTROS RÁPIDOS (Todos / Pendientes de Pago / Planes Activos)
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

          // LISTA DE NEGOCIOS
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
                              if (esPendiente)
                                Text(
                                  '⚠️ Pide alta en Plan ${n['plan_solicitado_id'] == 2 ? "Medio (\$5.000)" : "Premium (\$20.000)"} (${n['metodo_pago'] ?? "Verificar depósito"})',
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
