// lib/widgets/foco_dialog.dart (ADAPTADO PARA GEOVIGILÂNCIA)

import 'package:flutter/material.dart';
// <<< MUDANÇA: Imports dos novos modelos e do DB Helper >>>
import 'package:geovigilancia/models/foco_model.dart';
import 'package:geovigilancia/models/tipo_criadouro_model.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';

// <<< REMOÇÃO: A classe DialogResult foi removida por simplicidade. >>>
// O diálogo agora retorna diretamente um objeto Foco ou null.

class FocoDialog extends StatefulWidget {
  final Foco? focoParaEditar;
  final int vistoriaId;

  const FocoDialog({
    super.key,
    this.focoParaEditar,
    required this.vistoriaId,
  });

  bool get isEditing => focoParaEditar != null;

  @override
  State<FocoDialog> createState() => _FocoDialogState();
}

class _FocoDialogState extends State<FocoDialog> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper.instance;

  // <<< MUDANÇA: Estados para os novos campos de Foco >>>
  String? _tipoCriadouroSelecionado;
  bool _larvasEncontradas = false;
  String? _tratamentoRealizado;
  // (fotoUrl seria adicionado aqui se fôssemos capturar a foto dentro do dialog)

  // Estado para carregar os tipos de criadouro do banco
  late Future<List<TipoCriadouro>> _tiposCriadouroFuture;
  final List<String> _opcoesTratamento = ['Eliminação Mecânica', 'Larvicida', 'Orientação', 'Não Tratado'];

  @override
  void initState() {
    super.initState();
    // Carrega a lista de tipos de criadouro do banco de dados
    _tiposCriadouroFuture = dbHelper.getTodosTiposCriadouro();

    if (widget.isEditing) {
      final foco = widget.focoParaEditar!;
      _tipoCriadouroSelecionado = foco.tipoCriadouro;
      _larvasEncontradas = foco.larvasEncontradas;
      _tratamentoRealizado = foco.tratamentoRealizado;
    }
  }

  @override
  void dispose() {
    // Não temos mais controllers para dar dispose
    super.dispose();
  }

  // <<< MUDANÇA: Lógica de submissão simplificada >>>
  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Cria o objeto Foco com os dados do formulário
      final foco = Foco(
        id: widget.focoParaEditar?.id,
        vistoriaId: widget.vistoriaId,
        tipoCriadouro: _tipoCriadouroSelecionado!,
        larvasEncontradas: _larvasEncontradas,
        tratamentoRealizado: _tratamentoRealizado,
        // fotoUrl: ... (a ser implementado)
      );

      // Retorna o objeto Foco para a tela anterior
      Navigator.of(context).pop(foco);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing ? 'Editar Foco' : 'Adicionar Novo Foco',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // <<< MUDANÇA: Dropdown para Tipos de Criadouro >>>
                    FutureBuilder<List<TipoCriadouro>>(
                      future: _tiposCriadouroFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('Erro ao carregar tipos de criadouro.');
                        }
                        final tipos = snapshot.data!;
                        // Garante que o valor selecionado esteja na lista
                        if (_tipoCriadouroSelecionado != null && !tipos.any((t) => t.nome == _tipoCriadouroSelecionado)) {
                          _tipoCriadouroSelecionado = null;
                        }
                        return DropdownButtonFormField<String>(
                          value: _tipoCriadouroSelecionado,
                          decoration: const InputDecoration(labelText: 'Tipo de Criadouro'),
                          items: tipos.map((tc) => DropdownMenuItem(value: tc.nome, child: Text(tc.nome))).toList(),
                          onChanged: (value) => setState(() => _tipoCriadouroSelecionado = value),
                          validator: (v) => v == null ? 'Campo obrigatório' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // <<< MUDANÇA: Switch para Larvas Encontradas >>>
                    SwitchListTile(
                      title: const Text('Larvas Encontradas?'),
                      value: _larvasEncontradas,
                      onChanged: (value) => setState(() => _larvasEncontradas = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const SizedBox(height: 16),

                    // <<< MUDANÇA: Dropdown para Tratamento Realizado >>>
                    DropdownButtonFormField<String>(
                      value: _tratamentoRealizado,
                      decoration: const InputDecoration(labelText: 'Tratamento Realizado'),
                      items: _opcoesTratamento.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (value) => setState(() => _tratamentoRealizado = value),
                       validator: (v) => v == null ? 'Campo obrigatório' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // <<< MUDANÇA: Botões simplificados >>>
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: Text(widget.isEditing ? 'Atualizar' : 'Salvar Foco'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}