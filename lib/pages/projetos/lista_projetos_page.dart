// lib/pages/projetos/lista_projetos_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/pages/projetos/detalhes_projeto_page.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'form_projeto_page.dart'; 

class ListaProjetosPage extends StatefulWidget {
  final String title;
  final bool isImporting;
  final String? importType; // 'parcela', 'cubagem', etc.

  const ListaProjetosPage({
    super.key,
    required this.title,
    this.isImporting = false,
    this.importType,
  });

  @override
  State<ListaProjetosPage> createState() => _ListaProjetosPageState();
}

class _ListaProjetosPageState extends State<ListaProjetosPage> {
  final dbHelper = DatabaseHelper.instance;
  List<Projeto> projetos = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<int> _selectedProjetos = {};

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
  }

  Future<void> _carregarProjetos() async {
    setState(() => _isLoading = true);
    final data = await dbHelper.getTodosProjetos();
    setState(() {
      projetos = data;
      _isLoading = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProjetos.clear();
      _isSelectionMode = false;
    });
  }

  void _toggleSelection(int projetoId) {
    setState(() {
      if (_selectedProjetos.contains(projetoId)) {
        _selectedProjetos.remove(projetoId);
      } else {
        _selectedProjetos.add(projetoId);
      }
      _isSelectionMode = _selectedProjetos.isNotEmpty;
    });
  }
  
  Future<void> _iniciarImportacaoParaProjeto(Projeto projeto) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importação cancelada.')));
      return;
    }

    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Processando arquivo... Isso pode levar um momento.'),
      duration: Duration(seconds: 15),
    ));

    try {
      final file = File(result.files.single.path!);
      final csvContent = await file.readAsString();
      String message;

      switch (widget.importType) {
        case 'cubagem':
          message = await dbHelper.importarCubagemDeEquipe(csvContent, projeto.id!);
          break;
        case 'parcela':
        default:
          message = await dbHelper.importarColetaDeEquipe(csvContent, projeto.id!);
          break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resultado da Importação'),
            content: Text(message),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _importarProjetoGeoJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      final fileContent = await file.readAsString();

      final String message = await dbHelper.importarProjetoCompleto(fileContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ));
        _carregarProjetos();
      }
    }
  }

  Future<void> _deletarProjetosSelecionados() async {
    if (_selectedProjetos.isEmpty) return;

    final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Confirmar Exclusão'),
              content: Text(
                  'Tem certeza que deseja apagar os ${_selectedProjetos.length} projetos selecionados? Todas as atividades, fazendas, talhões e coletas associadas serão perdidas permanentemente.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Apagar')),
              ],
            ));
    if (confirmar == true && mounted) {
      for (final id in _selectedProjetos) {
        await dbHelper.deleteProjeto(id);
      }
      _clearSelection();
      await _carregarProjetos();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedProjetos.length} selecionados'),
              actions: [
                // ====================================================================
                // <<< CORREÇÃO APLICADA AQUI >>>
                // O botão de exportar projetos foi removido, pois a exportação
                // de planos agora é feita pela tela do mapa.
                // ====================================================================
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deletarProjetosSelecionados,
                  tooltip: 'Apagar Selecionados',
                ),
              ],
            )
          : AppBar(
              title: Text(widget.title),
              actions: [
                if (!widget.isImporting)
                  IconButton(
                    icon: const Icon(Icons.upload_file_outlined),
                    onPressed: _importarProjetoGeoJson,
                    tooltip: 'Importar Carga de Projeto (GeoJSON)',
                  ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : projetos.isEmpty
              ? const Center(
                  child: Text(
                      'Nenhum projeto encontrado.\nUse o botão + para adicionar um novo.',
                      textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: projetos.length,
                  itemBuilder: (context, index) {
                    final projeto = projetos[index];
                    final isSelected = _selectedProjetos.contains(projeto.id!);

                    return Card(
                        color: isSelected ? Colors.lightBlue.shade100 : null,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child:
                           ListTile(
                            onTap: () {
                              if (widget.isImporting) {
                                _iniciarImportacaoParaProjeto(projeto);
                              } else if (_isSelectionMode) {
                                _toggleSelection(projeto.id!);
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => DetalhesProjetoPage(projeto: projeto)));
                              }
                            },
                            onLongPress: () {
                              if (!widget.isImporting) {
                                _toggleSelection(projeto.id!);
                              }
                            },
                            leading: Icon(
                                isSelected ? Icons.check_circle : (widget.isImporting ? Icons.file_download_outlined : Icons.folder_outlined),
                                color: Theme.of(context).primaryColor,
                            ),
                            title: Text(projeto.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Responsável: ${projeto.responsavel}'),
                            trailing: Text(DateFormat('dd/MM/yy').format(projeto.dataCriacao)),
                          ),
                        );
                  },
                ),
      floatingActionButton: widget.isImporting ? null : FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FormProjetoPage()),
          ).then((criado) {
            if (criado == true) {
              _carregarProjetos();
            }
          });
        },
        tooltip: 'Adicionar Projeto',
        child: const Icon(Icons.add),
      ),
    );
  }
}