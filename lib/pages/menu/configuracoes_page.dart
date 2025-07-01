// lib/pages/menu/configuracoes_page.dart (SUBSTITUA O ARQUIVO INTEIRO)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/services/licensing_service.dart'; // 1. IMPORTAR O SERVIÇO DE LICENÇA

const Map<String, int> zonasUtmSirgas2000 = {
  'SIRGAS 2000 / UTM Zona 18S': 31978, 'SIRGAS 2000 / UTM Zona 19S': 31979,
  'SIRGAS 2000 / UTM Zona 20S': 31980, 'SIRGAS 2000 / UTM Zona 21S': 31981,
  'SIRGAS 2000 / UTM Zona 22S': 31982, 'SIRGAS 2000 / UTM Zona 23S': 31983,
  'SIRGAS 2000 / UTM Zona 24S': 31984, 'SIRGAS 2000 / UTM Zona 25S': 31985,
};

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  String? _zonaSelecionada;
  final dbHelper = DatabaseHelper();
  
  // 2. ADICIONAR AS VARIÁVEIS PARA GERENCIAMENTO DE LICENÇA
  final LicensingService _licensingService = LicensingService();
  Map<String, int>? _deviceUsage;
  bool _isLoadingLicense = true; // Loading específico para a licença

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
    _fetchDeviceUsage(); // 3. CHAMAR A FUNÇÃO PARA BUSCAR OS DADOS DA LICENÇA
  }

  // --- Funções Originais ---
  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _zonaSelecionada = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
      });
    }
  }

  Future<void> _salvarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zona_utm_selecionada', _zonaSelecionada!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas!'), backgroundColor: Colors.green),
      );
    }
  }
  
  // 4. ADICIONAR A LÓGICA PARA BUSCAR DADOS DA LICENÇA
  Future<void> _fetchDeviceUsage() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail != null) {
      final usage = await _licensingService.getDeviceUsage(userEmail);
      if (mounted) {
        setState(() {
          _deviceUsage = usage;
          _isLoadingLicense = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingLicense = false;
        });
      }
    }
  }

  Future<void> _mostrarDialogoLimpeza({
    required String titulo,
    required String conteudo,
    required VoidCallback onConfirmar,
  }) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(conteudo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      onConfirmar();
    }
  }
  // --- Fim das Funções Originais ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações e Gerenciamento')),
      body: _zonaSelecionada == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 5. NOVA SEÇÃO DE GERENCIAMENTO DE LICENÇA
                  const Text('Gerenciamento de Licença', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _isLoadingLicense
                          ? const Center(child: CircularProgressIndicator())
                          : _deviceUsage == null
                              ? const Text('Não foi possível carregar os dados da licença.')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Usuário: ${FirebaseAuth.instance.currentUser?.email ?? 'Desconhecido'}'),
                                    const SizedBox(height: 12),
                                    const Text('Dispositivos Registrados:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(' • Smartphones: ${_deviceUsage!['smartphone']}'),
                                    Text(' • Desktops: ${_deviceUsage!['desktop']}'),
                                  ],
                                ),
                    ),
                  ),

                  const Divider(thickness: 1, height: 48),

                  // --- SEÇÃO DE CONFIGURAÇÃO DE ZONA UTM ---
                  const Text('Zona UTM de Exportação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Define o sistema de coordenadas para os arquivos CSV.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _zonaSelecionada,
                    isExpanded: true,
                    items: zonasUtmSirgas2000.keys.map((String zona) => DropdownMenuItem<String>(value: zona, child: Text(zona, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (String? novoValor) => setState(() => _zonaSelecionada = novoValor),
                    decoration: const InputDecoration(labelText: 'Sistema de Coordenadas', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salvar Configuração da Zona'),
                      onPressed: _salvarConfiguracoes,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  
                  const Divider(thickness: 1, height: 48),

                  // --- SEÇÃO DE GERENCIAMENTO DE DADOS ---
                  const Text('Gerenciamento de Dados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: const Text('Arquivar Coletas Exportadas'),
                    subtitle: const Text('Apaga do dispositivo apenas as coletas (parcelas e cubagens) que já foram exportadas.'),
                    onTap: () => _mostrarDialogoLimpeza(
                      titulo: 'Arquivar Coletas',
                      conteudo: 'Isso removerá do dispositivo todas as coletas (parcelas e cubagens) já marcadas como exportadas. Deseja continuar?',
                      onConfirmar: () async {
                        final parcelasCount = await dbHelper.limparParcelasExportadas();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$parcelasCount parcelas arquivadas.')));
                      },
                    ),
                  ),

                  const Divider(thickness: 1, height: 24),

                  // --- SEÇÃO DE AÇÕES PERIGOSAS ---
                  const Text('Ações Perigosas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                    title: const Text('Limpar TODAS as Coletas de Parcela'),
                    subtitle: const Text('Apaga TODAS as parcelas e árvores salvas.'),
                    onTap: () => _mostrarDialogoLimpeza(
                      titulo: 'Limpar Todas as Parcelas',
                      conteudo: 'Tem certeza? TODOS os dados de parcelas e árvores serão apagados permanentemente.',
                      onConfirmar: () async {
                        await dbHelper.limparTodasAsParcelas();
                        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todas as parcelas foram apagadas!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                      },
                    ),
                  ),
                   ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                    title: const Text('Limpar TODOS os Dados de Cubagem'),
                    subtitle: const Text('Apaga TODOS os dados de cubagem salvos.'),
                    onTap: () => _mostrarDialogoLimpeza(
                      titulo: 'Limpar Todas as Cubagens',
                      conteudo: 'Tem certeza? TODOS os dados de cubagem serão apagados permanentemente.',
                      onConfirmar: () async {
                        await dbHelper.limparTodasAsCubagens();
                        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todos os dados de cubagem foram apagados!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}