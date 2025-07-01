// lib/pages/talhoes/detalhes_talhao_page.dart (VERSÃO FINAL CONTEXTUAL)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/pages/menu/map_import_page.dart';
import 'package:geoforestcoletor/pages/menu/home_page.dart';
import 'package:geoforestcoletor/pages/dashboard/talhao_dashboard_page.dart';
import 'package:geoforestcoletor/pages/amostra/coleta_dados_page.dart';
import 'package:geoforestcoletor/pages/cubagem/cubagem_dados_page.dart';

class DetalhesTalhaoPage extends StatefulWidget {
  final Talhao talhao;
  final Atividade atividade; // Recebe o contexto da atividade

  const DetalhesTalhaoPage({super.key, required this.talhao, required this.atividade});

  @override
  State<DetalhesTalhaoPage> createState() => _DetalhesTalhaoPageState();
}

class _DetalhesTalhaoPageState extends State<DetalhesTalhaoPage> {
  // O Future agora pode carregar tanto Parcelas quanto Cubagens
  late Future<List<dynamic>> _dataFuture;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  final Set<int> _selectedItens = {};

  // Propriedade computada para saber o contexto da página
  bool get _isAtividadeDeInventario {
    final tipo = widget.atividade.tipo.toLowerCase();
    return tipo.contains("ipc") || tipo.contains("ifc") || tipo.contains("inventário");
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedItens.clear();
        // Carrega os dados corretos com base no tipo de atividade
        if (_isAtividadeDeInventario) {
          _dataFuture = dbHelper.getParcelasDoTalhao(widget.talhao.id!);
        } else {
          _dataFuture = dbHelper.getTodasCubagensDoTalhao(widget.talhao.id!);
        }
      });
    }
  }

  void _toggleSelectionMode(int? itemId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItens.clear();
      if (_isSelectionMode && itemId != null) {
        _selectedItens.add(itemId);
      }
    });
  }
  
  void _onItemSelected(int itemId) {
    setState(() {
      if (_selectedItens.contains(itemId)) {
        _selectedItens.remove(itemId);
        if (_selectedItens.isEmpty) _isSelectionMode = false;
      } else {
        _selectedItens.add(itemId);
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItens.isEmpty || !mounted) return;
    
    final itemType = _isAtividadeDeInventario ? 'parcelas' : 'cubagens';
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar os ${_selectedItens.length} $itemType selecionados?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Apagar')),
        ],
      ),
    );

    if (confirmar == true) {
      if (_isAtividadeDeInventario) {
        await dbHelper.deletarMultiplasParcelas(_selectedItens.toList());
      } else {
        await dbHelper.deletarMultiplasCubagens(_selectedItens.toList());
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedItens.length} $itemType apagados.'), backgroundColor: Colors.green));
      _carregarDados();
    }
  }

  // --- MÉTODOS DE NAVEGAÇÃO ---
  void _navegarParaMapa() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MapImportPage(talhao: widget.talhao)));
  }

  Future<void> _navegarParaNovaParcela() async {
    final bool? recarregar = await Navigator.push(context, MaterialPageRoute(builder: (context) => ColetaDadosPage(talhao: widget.talhao)));
    if (recarregar == true && mounted) _carregarDados();
  }

  Future<void> _navegarParaNovaCubagem() async {
    final arvoreCubagem = CubagemArvore(
      talhaoId: widget.talhao.id,
      nomeFazenda: widget.talhao.fazendaNome ?? 'N/A',
      nomeTalhao: widget.talhao.nome,
      identificador: 'Cubagem Avulsa', // Identificador padrão
    );
    final bool? recarregar = await Navigator.push(context, MaterialPageRoute(builder: (context) => CubagemDadosPage(metodo: 'Fixas', arvoreParaEditar: arvoreCubagem,)));
    if(recarregar == true && mounted) _carregarDados();
  }

  Future<void> _navegarParaDetalhesParcela(Parcela parcela) async {
    final bool? recarregar = await Navigator.push(context, MaterialPageRoute(builder: (context) => ColetaDadosPage(parcelaParaEditar: parcela)));
     if(recarregar == true && mounted) _carregarDados();
  }

  Future<void> _navegarParaDetalhesCubagem(CubagemArvore arvore) async {
    final bool? recarregar = await Navigator.push(context, MaterialPageRoute(builder: (context) => CubagemDadosPage(metodo: arvore.tipoMedidaCAP, arvoreParaEditar: arvore,)));
    if(recarregar == true && mounted) _carregarDados();
  }


  // --- WIDGETS DE CONSTRUÇÃO DA UI ---
  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Talhão: ${widget.talhao.nome}'),
      actions: [
        if (_isAtividadeDeInventario)
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Ver Análise do Talhão',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TalhaoDashboardPage(talhao: widget.talhao))),
          ),
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
      appBar: _isSelectionMode 
        ? AppBar(
            leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _toggleSelectionMode(null)),
            title: Text('${_selectedItens.length} selecionados'),
            actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteSelectedItems, tooltip: 'Apagar Selecionados')],
          )
        : _buildAppBar(),
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
                  Text('Detalhes do Talhão', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("Atividade: ${widget.atividade.tipo}", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Fazenda: ${widget.talhao.fazendaNome ?? 'Não informada'}", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text("Espécie: ${widget.talhao.especie ?? 'Não informada'}", style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: ElevatedButton.icon(onPressed: _navegarParaMapa, icon: const Icon(Icons.map_outlined), label: const Text('Abrir Talhão no Mapa'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              _isAtividadeDeInventario ? "Coletas de Parcela" : "Árvores para Cubagem",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
                
                final itens = snapshot.data ?? [];
                if (itens.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _isAtividadeDeInventario 
                          ? 'Nenhuma parcela coletada.\nClique no botão "+" para iniciar.'
                          : 'Nenhuma árvore para cubar.\nClique no botão "+" para adicionar uma cubagem manual.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }
                // Renderiza a lista correta com base no tipo de atividade
                return _isAtividadeDeInventario
                   ? _buildListaDeParcelas(itens.cast<Parcela>())
                   : _buildListaDeCubagens(itens.cast<CubagemArvore>());
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: _isAtividadeDeInventario ? _navegarParaNovaParcela : _navegarParaNovaCubagem,
        tooltip: _isAtividadeDeInventario ? 'Nova Parcela' : 'Nova Cubagem Manual',
        icon: Icon(_isAtividadeDeInventario ? Icons.add_location_alt_outlined : Icons.add),
        label: Text(_isAtividadeDeInventario ? 'Nova Parcela' : 'Nova Cubagem'),
      ),
    );
  }

  Widget _buildListaDeParcelas(List<Parcela> parcelas) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: parcelas.length,
      itemBuilder: (context, index) {
        final parcela = parcelas[index];
        final isSelected = _selectedItens.contains(parcela.dbId!);
        final dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(parcela.dataColeta!);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128) : null,
          child: ListTile(
            onTap: () => _isSelectionMode ? _onItemSelected(parcela.dbId!) : _navegarParaDetalhesParcela(parcela),
            onLongPress: () => _toggleSelectionMode(parcela.dbId!),
            leading: CircleAvatar(
              backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : parcela.status.cor,
              child: Icon(isSelected ? Icons.check : parcela.status.icone, color: Colors.white),
            ),
            title: Text('Parcela ID: ${parcela.idParcela}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Coletado em: $dataFormatada'),
            trailing: _isSelectionMode ? null : IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () { _selectedItens.clear(); _selectedItens.add(parcela.dbId!); _deleteSelectedItems(); },
            ),
            selected: isSelected,
          ),
        );
      },
    );
  }

  Widget _buildListaDeCubagens(List<CubagemArvore> cubagens) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: cubagens.length,
      itemBuilder: (context, index) {
        final arvore = cubagens[index];
        final isSelected = _selectedItens.contains(arvore.id!);
        final isConcluida = arvore.alturaTotal > 0;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128) : null,
          child: ListTile(
            onTap: () => _isSelectionMode ? _onItemSelected(arvore.id!) : _navegarParaDetalhesCubagem(arvore),
            onLongPress: () => _toggleSelectionMode(arvore.id!),
            leading: CircleAvatar(
              backgroundColor: isConcluida ? Colors.green : (isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
              child: Icon(isSelected ? Icons.check : (isConcluida ? Icons.check : Icons.pending_outlined), color: Colors.white),
            ),
            title: Text(arvore.identificador),
            subtitle: Text('Classe: ${arvore.classe ?? "Avulsa"}'),
            trailing: _isSelectionMode ? null : IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () { _selectedItens.clear(); _selectedItens.add(arvore.id!); _deleteSelectedItems(); },
            ),
            selected: isSelected,
          ),
        );
      },
    );
  }
}