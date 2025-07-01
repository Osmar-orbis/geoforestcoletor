// lib/pages/fazenda/detalhes_fazenda_page.dart (VERSÃO CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart'; // <<< IMPORT NECESSÁRIO
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/talhoes/form_talhao_page.dart';
import 'package:geoforestcoletor/pages/talhoes/detalhes_talhao_page.dart';
import 'package:geoforestcoletor/pages/menu/home_page.dart';

class DetalhesFazendaPage extends StatefulWidget {
  final Fazenda fazenda;
  // <<< O WIDGET AGORA RECEBE A ATIVIDADE DA TELA ANTERIOR >>>
  final Atividade atividade; 
  
  const DetalhesFazendaPage({super.key, required this.fazenda, required this.atividade});

  @override
  State<DetalhesFazendaPage> createState() => _DetalhesFazendaPageState();
}

class _DetalhesFazendaPageState extends State<DetalhesFazendaPage> {
  late Future<List<Talhao>> _talhoesFuture;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  final Set<int> _selectedTalhoes = {};

  @override
  void initState() {
    super.initState();
    _carregarTalhoes();
  }

  void _carregarTalhoes() {
    if(mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedTalhoes.clear();
        _talhoesFuture = dbHelper.getTalhoesDaFazenda(widget.fazenda.id, widget.fazenda.atividadeId);
      });
    }
  }

  // --- MÉTODOS DE SELEÇÃO E EXCLUSÃO (sem alteração) ---
  void _toggleSelectionMode(int? talhaoId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedTalhoes.clear();
      if (_isSelectionMode && talhaoId != null) {
        _selectedTalhoes.add(talhaoId);
      }
    });
  }

  void _onItemSelected(int talhaoId) {
    setState(() {
      if (_selectedTalhoes.contains(talhaoId)) {
        _selectedTalhoes.remove(talhaoId);
        if (_selectedTalhoes.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTalhoes.add(talhaoId);
      }
    });
  }

  Future<void> _deleteSelectedTalhoes() async {
    if (_selectedTalhoes.isEmpty) return;
    
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar os ${_selectedTalhoes.length} talhões selecionados e todos os seus dados? Esta ação não pode ser desfeita.'),
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
      for (final id in _selectedTalhoes) {
        await dbHelper.deleteTalhao(id);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_selectedTalhoes.length} talhões apagados.'),
          backgroundColor: Colors.green));
      _carregarTalhoes();
    }
  }

  // --- MÉTODOS DE NAVEGAÇÃO ---
  void _navegarParaNovoTalhao() async {
    final bool? talhaoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormTalhaoPage(
          fazendaId: widget.fazenda.id,
          fazendaAtividadeId: widget.fazenda.atividadeId,
        ),
      ),
    );
    if (talhaoCriado == true && mounted) {
      _carregarTalhoes();
    }
  }
  
  void _navegarParaDetalhesTalhao(Talhao talhao) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesTalhaoPage(
        talhao: talhao,
        atividade: widget.atividade, // <<< PASSANDO A ATIVIDADE PARA A TELA SEGUINTE
      )),
    ).then((_) => _carregarTalhoes());
  }

  // --- WIDGETS DE CONSTRUÇÃO DA UI (sem alteração) ---
  AppBar _buildSelectionAppBar() {
    return AppBar(
      title: Text('${_selectedTalhoes.length} selecionado(s)'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _toggleSelectionMode(null),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Apagar selecionados',
          onPressed: _deleteSelectedTalhoes,
        ),
      ],
    );
  }
  
  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.fazenda.nome),
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
                  Text('Detalhes da Fazenda', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("ID: ${widget.fazenda.id}", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text("Local: ${widget.fazenda.municipio} - ${widget.fazenda.estado.toUpperCase()}", style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Talhões da Fazenda",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Talhao>>(
              future: _talhoesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar talhões: ${snapshot.error}'));
                }

                final talhoes = snapshot.data ?? [];

                if (talhoes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhum talhão encontrado.\nClique no botão "+" para adicionar o primeiro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: talhoes.length,
                  itemBuilder: (context, index) {
                    final talhao = talhoes[index];
                    final isSelected = _selectedTalhoes.contains(talhao.id!);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128) : null,
                      child: ListTile(
                        onTap: () {
                          if (_isSelectionMode) {
                            _onItemSelected(talhao.id!);
                          } else {
                            _navegarParaDetalhesTalhao(talhao);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode(talhao.id!);
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : null,
                          child: Icon(isSelected ? Icons.check : Icons.park_outlined),
                        ),
                        title: Text(talhao.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Área: ${talhao.areaHa?.toStringAsFixed(2) ?? 'N/A'} ha - Espécie: ${talhao.especie ?? 'N/A'}'),
                        trailing: _isSelectionMode ? null : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                             _toggleSelectionMode(talhao.id!);
                             await _deleteSelectedTalhoes();
                          }
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
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: _navegarParaNovoTalhao,
        tooltip: 'Novo Talhão',
        icon: const Icon(Icons.add_chart),
        label: const Text('Novo Talhão'),
      ),
    );
  }
}