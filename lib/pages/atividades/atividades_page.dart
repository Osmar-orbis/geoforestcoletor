// lib/pages/atividades/atividades_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

// Importações dos seus arquivos
import '../../data/datasources/local/database_helper.dart';
import '../../models/atividade_model.dart';
import '../../models/projeto_model.dart';
import 'detalhes_atividade_page.dart';
import 'form_atividade_page.dart';

class AtividadesPage extends StatefulWidget {
  // A página recebe o objeto do projeto para saber de qual projeto listar as atividades
  final Projeto projeto;

  const AtividadesPage({
    super.key,
    required this.projeto,
  });

  @override
  State<AtividadesPage> createState() => _AtividadesPageState();
}

class _AtividadesPageState extends State<AtividadesPage> {
  final dbHelper = DatabaseHelper.instance;
  late Future<List<Atividade>> _atividadesFuture;

  @override
  void initState() {
    super.initState();
    _carregarAtividades();
  }

  void _carregarAtividades() {
    setState(() {
      // Pede ao serviço de banco de dados para buscar as atividades pelo ID do projeto
      _atividadesFuture = dbHelper.getAtividadesDoProjeto(widget.projeto.id!);
    });
  }

  // Função para mostrar um diálogo de confirmação antes de excluir
  Future<void> _mostrarDialogoDeConfirmacao(Atividade atividade) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja excluir a atividade "${atividade.tipo}" e todos os seus dados?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Excluir'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    
    if (confirmar == true && mounted) {
      await dbHelper.deleteAtividade(atividade.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atividade excluída com sucesso!'), backgroundColor: Colors.red),
      );
      _carregarAtividades(); // Recarrega a lista para refletir a exclusão
    }
  }

  // Navega para a tela de formulário para criar uma nova atividade
  void _navegarParaFormularioAtividade() async {
    final bool? atividadeCriada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormAtividadePage(projetoId: widget.projeto.id!),
      ),
    );
    // Se a tela de formulário retornar 'true', recarrega a lista
    if (atividadeCriada == true && mounted) {
      _carregarAtividades();
    }
  }
  
  // Navega para a tela de detalhes da atividade
  void _navegarParaDetalhes(Atividade atividade) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesAtividadePage(atividade: atividade),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Usa o nome do projeto no título da página
        title: Text('Atividades de ${widget.projeto.nome}'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Atividade>>(
        future: _atividadesFuture,
        builder: (context, snapshot) {
          // Enquanto está carregando, mostra um indicador de progresso
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Se deu algum erro na busca
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar atividades: ${snapshot.error}'));
          }
          // Se a busca foi concluída mas não retornou dados
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma atividade encontrada.\nToque no botão + para adicionar a primeira!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final atividades = snapshot.data!;

          // Se chegou aqui, temos dados. Construímos a lista.
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Espaço para o botão flutuante
            itemCount: atividades.length,
            itemBuilder: (context, index) {
              final atividade = atividades[index];
              return Slidable(
                key: ValueKey(atividade.id),
                // Ações que aparecem ao deslizar para a esquerda
                endActionPane: ActionPane(
                  motion: const StretchMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => _mostrarDialogoDeConfirmacao(atividade),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline,
                      label: 'Excluir',
                    ),
                  ],
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text((index + 1).toString())),
                    title: Text(
                      atividade.tipo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${atividade.descricao.isNotEmpty ? atividade.descricao : 'Sem descrição'}\nCriado em: ${DateFormat('dd/MM/yyyy HH:mm').format(atividade.dataCriacao)}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _navegarParaDetalhes(atividade),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarParaFormularioAtividade,
        icon: const Icon(Icons.add),
        label: const Text('Nova Atividade'),
        tooltip: 'Adicionar Nova Atividade',
      ),
    );
  }
}