// lib/pages/analises/definicao_sortimento_page.dart (ARQUIVO NOVO)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/sortimento_model.dart';
import 'package:geoforestcoletor/pages/analises/form_sortimento_page.dart';

class DefinicaoSortimentoPage extends StatefulWidget {
  const DefinicaoSortimentoPage({super.key});

  @override
  State<DefinicaoSortimentoPage> createState() => _DefinicaoSortimentoPageState();
}

class _DefinicaoSortimentoPageState extends State<DefinicaoSortimentoPage> {
  late Future<List<SortimentoModel>> _sortimentosFuture;

  @override
  void initState() {
    super.initState();
    _carregarSortimentos();
  }

  void _carregarSortimentos() {
    setState(() {
      _sortimentosFuture = DatabaseHelper.instance.getTodosSortimentos();
    });
  }

  void _navegarParaFormulario([SortimentoModel? sortimento]) async {
    final recarregar = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormSortimentoPage(sortimentoParaEditar: sortimento),
      ),
    );
    if (recarregar == true) {
      _carregarSortimentos();
    }
  }

  Future<void> _deletarSortimento(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja apagar esta definição de sortimento?'),
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
      await DatabaseHelper.instance.deleteSortimento(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Definição apagada.'), backgroundColor: Colors.red),
      );
      _carregarSortimentos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Definição de Sortimentos')),
      body: FutureBuilder<List<SortimentoModel>>(
        future: _sortimentosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final sortimentos = snapshot.data ?? [];
          if (sortimentos.isEmpty) {
            return const Center(child: Text('Nenhum sortimento definido. Clique em + para adicionar.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: sortimentos.length,
            itemBuilder: (context, index) {
              final s = sortimentos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(s.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Comp: ${s.comprimento}m | Dmin: ${s.diametroMinimo}cm | Dmax: ${s.diametroMaximo}cm'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _navegarParaFormulario(s)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deletarSortimento(s.id!)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navegarParaFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Novo Sortimento'),
      ),
    );
  }
}