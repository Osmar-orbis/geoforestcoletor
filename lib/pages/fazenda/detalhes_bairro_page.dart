// lib/pages/bairros/detalhes_bairro_page.dart (ADAPTADO PARA GEOVIGILÂNCIA)

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
// <<< MUDANÇA: Imports adaptados >>>
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:geovigilancia/models/quarteirao_model.dart';
import 'package:geovigilancia/pages/quarteiroes/form_quarteirao_page.dart';
import 'package:geovigilancia/pages/quarteiroes/detalhes_quarteirao_page.dart';
import 'package:geovigilancia/pages/menu/home_page.dart';

class DetalhesBairroPage extends StatefulWidget {
  // <<< MUDANÇA: Recebe Bairro em vez de Fazenda >>>
  final Bairro bairro;
  final Atividade atividade;

  const DetalhesBairroPage(
      {super.key, required this.bairro, required this.atividade});

  @override
  State<DetalhesBairroPage> createState() => _DetalhesBairroPageState();
}

class _DetalhesBairroPageState extends State<DetalhesBairroPage> {
  // <<< MUDANÇA: Tipagem para Quarteirao >>>
  List<Quarteirao> _quarteiroes = [];
  bool _isLoading = true;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  final Set<int> _selectedQuarteiroes = {};

  @override
  void initState() {
    super.initState();
    _carregarQuarteiroes();
  }

  // <<< MUDANÇA: Carrega Quarteirões (Setores) em vez de Talhões >>>
  void _carregarQuarteiroes() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isSelectionMode = false;
        _selectedQuarteiroes.clear();
      });
    }

    final todosOsQuarteiroes = await dbHelper.getSetoresDoBairro(
        widget.bairro.id, widget.bairro.atividadeId);

    if (mounted) {
      setState(() {
        _quarteiroes = todosOsQuarteiroes;
        _isLoading = false;
      });
    }
  }

  void _toggleSelectionMode(int? quarteiraoId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedQuarteiroes.clear();
      if (_isSelectionMode && quarteiraoId != null) {
        _selectedQuarteiroes.add(quarteiraoId);
      }
    });
  }

  void _onItemSelected(int quarteiraoId) {
    setState(() {
      if (_selectedQuarteiroes.contains(quarteiraoId)) {
        _selectedQuarteiroes.remove(quarteiraoId);
        if (_selectedQuarteiroes.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedQuarteiroes.add(quarteiraoId);
      }
    });
  }

  Future<void> _deleteQuarteirao(Quarteirao quarteirao) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja apagar o setor/quarteirão "${quarteirao.nome}" e todas as suas vistorias?'),
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
      // <<< MUDANÇA: Chama o método deleteSetor >>>
      await dbHelper.deleteSetor(quarteirao.id!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Setor/Quarteirão apagado.'), backgroundColor: Colors.red));
      _carregarQuarteiroes();
    }
  }

  // <<< MUDANÇA: Navegação para o formulário de Quarteirão >>>
  void _navegarParaNovoQuarteirao() async {
    final bool? quarteiraoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormQuarteiraoPage(
          bairroId: widget.bairro.id,
          bairroAtividadeId: widget.bairro.atividadeId,
        ),
      ),
    );
    if (quarteiraoCriado == true && mounted) {
      _carregarQuarteiroes();
    }
  }

  void _navegarParaEdicaoQuarteirao(Quarteirao quarteirao) async {
    final bool? quarteiraoEditado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormQuarteiraoPage(
          bairroId: quarteirao.bairroId,
          bairroAtividadeId: quarteirao.bairroAtividadeId,
          quarteiraoParaEditar: quarteirao,
        ),
      ),
    );
    if (quarteiraoEditado == true && mounted) {
      _carregarQuarteiroes();
    }
  }

  void _navegarParaDetalhesQuarteirao(Quarteirao quarteirao) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => DetalhesQuarteiraoPage(
                quarteirao: quarteirao,
                atividade: widget.atividade,
              )),
    ).then((_) => _carregarQuarteiroes());
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      title: Text('${_selectedQuarteiroes.length} selecionado(s)'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _toggleSelectionMode(null),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Apagar selecionados',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Use o deslize para apagar individualmente.')));
          },
        ),
      ],
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.bairro.nome),
      actions: [
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Voltar para o Início',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) =>
                    const HomePage(title: 'GeoVigilância')),
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
                  Text('Detalhes do Bairro', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("ID do Bairro: ${widget.bairro.id}", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                      "Local: ${widget.bairro.municipio} - ${widget.bairro.estado.toUpperCase()}",
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Setores / Quarteirões do Bairro",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _quarteiroes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Nenhum setor/quarteirão encontrado.\nClique no botão "+" para adicionar o primeiro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _quarteiroes.length,
                        itemBuilder: (context, index) {
                          final quarteirao = _quarteiroes[index];
                          final isSelected = _selectedQuarteiroes.contains(quarteirao.id!);
                          return Slidable(
                            key: ValueKey(quarteirao.id),
                            startActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) => _navegarParaEdicaoQuarteirao(quarteirao),
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit_outlined,
                                  label: 'Editar',
                                ),
                              ],
                            ),
                            endActionPane: ActionPane(
                              motion: const BehindMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) => _deleteQuarteirao(quarteirao),
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_outline,
                                  label: 'Excluir',
                                ),
                              ],
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128) : null,
                              child: ListTile(
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _onItemSelected(quarteirao.id!);
                                  } else {
                                    _navegarParaDetalhesQuarteirao(quarteirao);
                                  }
                                },
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    _toggleSelectionMode(quarteirao.id!);
                                  }
                                },
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : null,
                                  child: Icon(isSelected ? Icons.check : Icons.grid_on_outlined),
                                ),
                                title: Text(quarteirao.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Área: ${quarteirao.areaHa?.toStringAsFixed(2) ?? 'N/A'} ha'),
                                trailing: const Icon(Icons.swap_horiz_outlined, color: Colors.grey),
                                selected: isSelected,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _navegarParaNovoQuarteirao,
              tooltip: 'Novo Setor / Quarteirão',
              icon: const Icon(Icons.add_road_outlined),
              label: const Text('Novo Setor'),
            ),
    );
  }
}