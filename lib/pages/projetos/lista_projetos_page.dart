// lib/pages/projetos/lista_projetos_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/pages/projetos/detalhes_projeto_page.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'form_projeto_page.dart'; 

class ListaProjetosPage extends StatefulWidget {
  final String title;
  final bool isImporting; // <<< NOVO PARÂMETRO

  const ListaProjetosPage({
    super.key,
    required this.title,
    this.isImporting = false, // <<< VALOR PADRÃO
  });

  @override
  State<ListaProjetosPage> createState() => _ListaProjetosPageState();
}

class _ListaProjetosPageState extends State<ListaProjetosPage> {
  final dbHelper = DatabaseHelper.instance;
  final exportService = ExportService();
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
  
  // =============================================================
  // ============ NOVA FUNÇÃO DE IMPORTAÇÃO DE COLETAS ===========
  // =============================================================
  Future<void> _importarColetasParaProjeto(Projeto projeto) async {
    // 1. Pede ao usuário para escolher o arquivo CSV
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importação cancelada pelo usuário.')),
      );
      return;
    }

    if (!mounted) return;
    
    // Mostra um feedback de que o processamento começou
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Processando arquivo... Isso pode levar um momento.'),
      duration: Duration(seconds: 10),
    ));

    try {
      final file = File(result.files.single.path!);
      final csvContent = await file.readAsString();
      
      // 2. Chama o método do DatabaseHelper (que vamos criar no próximo passo)
      // final String message = await dbHelper.importarColetaDeEquipe(csvContent, projeto.id!);
      
      // Por enquanto, vamos simular o sucesso
      final String message = await dbHelper.importarColetaDeEquipe(csvContent, projeto.id!);

  if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove a msg "processando"
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resultado da Importação'),
            content: Text(message),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
          ),
        );
        Navigator.of(context).pop(); // Volta para o menu principal
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

  Future<void> _exportarProjetosSelecionados() async {
    if (_selectedProjetos.isEmpty) return;

    await exportService.exportarProjetosCompletos(
      context: context,
      projetoIds: _selectedProjetos.toList(),
    );

    _clearSelection();
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
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: _exportarProjetosSelecionados,
                  tooltip: 'Exportar Selecionados',
                ),
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
                // Esconde o botão de importar GeoJSON se estivermos no modo de importar CSV
                if (!widget.isImporting)
                  IconButton(
                    icon: const Icon(Icons.upload_file_outlined),
                    onPressed: _importarProjetoGeoJson,
                    tooltip: 'Importar Projeto (GeoJSON)',
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
                              // ================================================
                              // ========== LÓGICA DE ONTAP ATUALIZADA ==========
                              // ================================================
                              if (widget.isImporting) {
                                // Se estamos importando, o clique inicia a importação
                                _importarColetasParaProjeto(projeto);
                              } else if (_isSelectionMode) {
                                // Se estamos no modo de seleção, o clique seleciona/desseleciona
                                _toggleSelection(projeto.id!);
                              } else {
                                // Caso contrário, navega para os detalhes do projeto
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
      // Esconde o botão de adicionar se estivermos no modo de importação
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