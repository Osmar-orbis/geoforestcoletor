// lib/pages/fazendas/form_fazenda_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:sqflite/sqflite.dart';

class FormFazendaPage extends StatefulWidget {
  // A página precisa saber a qual ATIVIDADE esta fazenda pertence.
  final int atividadeId;

  const FormFazendaPage({super.key, required this.atividadeId});

  @override
  State<FormFazendaPage> createState() => _FormFazendaPageState();
}

class _FormFazendaPageState extends State<FormFazendaPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nomeController = TextEditingController();
  final _municipioController = TextEditingController();
  final _estadoController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _idController.dispose();
    _nomeController.dispose();
    _municipioController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  Future<void> _salvarFazenda() async {
    // Valida o formulário
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      // Cria o objeto Fazenda com os dados dos campos
      final novaFazenda = Fazenda(
        id: _idController.text.trim(),
        atividadeId: widget.atividadeId,
        nome: _nomeController.text.trim(),
        municipio: _municipioController.text.trim(),
        estado: _estadoController.text.trim().toUpperCase(),
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.insertFazenda(novaFazenda);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fazenda criada com sucesso!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true); // Retorna 'true' para a tela anterior recarregar a lista
        }
      } on DatabaseException catch (e) {
        // Trata o erro específico de ID duplicado (chave primária composta)
        if (e.isUniqueConstraintError() && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: O ID "${novaFazenda.id}" já existe para esta atividade.'), backgroundColor: Colors.red),
          );
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro de banco de dados ao salvar: $e'), backgroundColor: Colors.red),
          );
        }
      } 
      catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ocorreu um erro inesperado: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Fazenda'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Campo para o ID da Fazenda (fornecido pelo cliente)
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'ID da Fazenda (Código do Cliente)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O ID da fazenda é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Campo para o Nome da Fazenda
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Fazenda',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.maps_home_work_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome da fazenda é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Outros campos...
              TextFormField(
                controller: _municipioController,
                decoration: const InputDecoration(
                  labelText: 'Município',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O município é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estadoController,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Estado (UF)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public_outlined),
                  counterText: "",
                ),
                 validator: (value) {
                  if (value == null || value.trim().length != 2) {
                    return 'Informe a sigla do estado (ex: SP).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // Botão de Salvar
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvarFazenda,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Fazenda'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}