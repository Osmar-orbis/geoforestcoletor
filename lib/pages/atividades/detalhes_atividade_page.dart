// lib/pages/atividades/detalhes_atividade_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/fazenda/form_fazenda_page.dart';
import 'package:geoforestcoletor/pages/fazenda/detalhes_fazenda_page.dart';
import 'package:geoforestcoletor/pages/menu/home_page.dart';
import 'package:geoforestcoletor/pages/dashboard/relatorio_comparativo_page.dart';

class DetalhesAtividadePage extends StatefulWidget {
  final Atividade atividade;
  const DetalhesAtividadePage({super.key, required this.atividade});

  @override
  State<DetalhesAtividadePage> createState() => _DetalhesAtividadePageState();
}

class _DetalhesAtividadePageState extends State<DetalhesAtividadePage> {
  late Future<List<Fazenda>> _fazendasFuture;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  final Set<String> _selectedFazendas = {};

  bool get _isAtividadeDeInventario {
    final tipo = widget.atividade.tipo.toLowerCase();
    return tipo.contains("ipc") || tipo.contains("ifc") || tipo.contains("inventário");
  }

  @override
  void initState() {
    super.initState();
    _carregarFazendas();
  }

  void _carregarFazendas() {
    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedFazendas.clear();
        _fazendasFuture = dbHelper.getFazendasDaAtividade(widget.atividade.id!);
      });
    }
  }

  void _toggleSelectionMode(String? fazendaId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedFazendas.clear();
      if (_isSelectionMode && fazendaId != null) {
        _selectedFazendas.add(fazendaId);
      }
    });
  }

  void _onItemSelected(String fazendaId) {
    setState(() {
      if (_selectedFazendas.contains(fazendaId)) {
        _selectedFazendas.remove(fazendaId);
        if (_selectedFazendas.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFazendas.add(fazendaId);
      }
    });
  }

  Future<void> _deleteSelectedFazendas() async {
    if (_selectedFazendas.isEmpty) return;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar as ${_selectedFazendas.length} fazendas selecionadas e todos os seus dados? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      for (final id in _selectedFazendas) {
        await dbHelper.deleteFazenda(id, widget.atividade.id!);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_selectedFazendas.length} fazendas apagadas.'),
          backgroundColor: Colors.green));
      _carregarFazendas();
    }
  }

  void _navegarParaNovaFazenda() async {
    final bool? fazendaCriada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormFazendaPage(atividadeId: widget.atividade.id!),
      ),
    );
    if (fazendaCriada == true && mounted) {
      _carregarFazendas();
    }
  }

  // =========================================================================
  // ===================== MÉTODO CORRIGIDO (ERRO 1) =========================
  // =========================================================================
  void _navegarParaDetalhesFazenda(Fazenda fazenda) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesFazendaPage(
        fazenda: fazenda,
        atividade: widget.atividade, // <<< Parâmetro obrigatório adicionado
      )),
    ).then((_) => _carregarFazendas());
  }

  // =========================================================================
  // ===================== MÉTODO CORRIGIDO (ERRO 2) =========================
  // =========================================================================
  Future<void> _navegarParaGeracaoDePlano() async {
    // É seguro usar o context aqui, antes do primeiro 'await'
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Buscando talhões da atividade...'),
      duration: Duration(seconds: 2),
    ));

    final fazendas = await dbHelper.getFazendasDaAtividade(widget.atividade.id!);

    // Guarda o BuildContext em uma variável antes do próximo 'await'
    final currentContext = context;

    // Verificação de 'mounted' para o primeiro await
    if (!mounted) return;

    if (fazendas.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(const SnackBar(content: Text('Nenhuma fazenda encontrada nesta atividade.')));
      return;
    }

    List<Talhao> todosOsTalhoes = [];
    for (final fazenda in fazendas) {
      final talhoesDaFazenda = await dbHelper.getTalhoesDaFazenda(fazenda.id, fazenda.atividadeId);
      todosOsTalhoes.addAll(talhoesDaFazenda);
    }
    
    // Verificação de 'mounted' para o segundo await (loop)
    if (!mounted) return;

    if (todosOsTalhoes.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(const SnackBar(content: Text('Nenhum talhão encontrado para gerar o plano.')));
      return;
    }
    
    // Usamos o context que guardamos, após verificar se a tela ainda está montada
    Navigator.push(
      currentContext,
      MaterialPageRoute(
        builder: (context) => RelatorioComparativoPage(
          talhoesSelecionados: todosOsTalhoes,
        ),
      ),
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      title: Text('${_selectedFazendas.length} selecionada(s)'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _toggleSelectionMode(null),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Apagar selecionadas',
          onPressed: _deleteSelectedFazendas,
        ),
      ],
    );
  }
  
  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.atividade.tipo),
      actions: [
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Voltar para o Início',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage(title: 'Geo Forest Analytics')),
            (Route<dynamic> route) => false,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(12.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Detalhes da Atividade', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("Descrição: ${widget.atividade.descricao.isNotEmpty ? widget.atividade.descricao : 'N/A'}",
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('Data de Criação: ${DateFormat('dd/MM/yyyy').format(widget.atividade.dataCriacao)}',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Fazendas da Atividade",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Fazenda>>(
              future: _fazendasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar fazendas: ${snapshot.error}'));
                }

                final fazendas = snapshot.data ?? [];

                if (fazendas.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhuma fazenda encontrada.\nClique no botão "+" para adicionar a primeira.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: fazendas.length,
                  itemBuilder: (context, index) {
                    final fazenda = fazendas[index];
                    final isSelected = _selectedFazendas.contains(fazenda.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128) : null,
                      child: ListTile(
                        onTap: () {
                          if (_isSelectionMode) {
                            _onItemSelected(fazenda.id);
                          } else {
                            _navegarParaDetalhesFazenda(fazenda);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode(fazenda.id);
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : null,
                          child: Icon(isSelected ? Icons.check : Icons.agriculture_outlined),
                        ),
                        title: Text(fazenda.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('ID: ${fazenda.id}\n${fazenda.municipio} - ${fazenda.estado}'),
                        trailing: _isSelectionMode ? null : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            _toggleSelectionMode(fazenda.id);
                            await _deleteSelectedFazendas();
                          },
                        ),
                        selected: isSelected,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode 
        ? null 
        : SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            children: [
              if (_isAtividadeDeInventario)
                SpeedDialChild(
                  child: const Icon(Icons.playlist_add_check_outlined),
                  label: 'Gerar Plano de Cubagem',
                  onTap: _navegarParaGeracaoDePlano,
                ),
              SpeedDialChild(
                child: const Icon(Icons.add_business_outlined),
                label: 'Nova Fazenda',
                onTap: _navegarParaNovaFazenda,
              ),
            ],
        ),
    );
  }
}