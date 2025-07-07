// lib/pages/vistorias/form_vistoria_page.dart (ADAPTADO PARA GEOVIGILÂNCIA)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// <<< MUDANÇA: Imports dos novos modelos e da nova página de focos >>>
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/models/quarteirao_model.dart';
import 'package:geovigilancia/pages/vistorias/lista_focos_page.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:image_picker/image_picker.dart';

// <<< REMOÇÃO: enum FormaParcela não é mais necessário. >>>

class FormVistoriaPage extends StatefulWidget {
  // <<< MUDANÇA: Tipos de parâmetros atualizados para Vistoria e Quarteirao >>>
  final Vistoria? vistoriaParaEditar;
  final Quarteirao? quarteirao;

  const FormVistoriaPage({super.key, this.vistoriaParaEditar, this.quarteirao})
      : assert(vistoriaParaEditar != null || quarteirao != null, 'É necessário fornecer uma vistoria para editar ou um quarteirão para criar uma nova vistoria.');

  @override
  State<FormVistoriaPage> createState() => _FormVistoriaPageState();
}

class _FormVistoriaPageState extends State<FormVistoriaPage> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper.instance;
  // <<< MUDANÇA: Estado para segurar o objeto Vistoria >>>
  late Vistoria _vistoriaAtual;

  // <<< MUDANÇA: Controllers adaptados para a nova realidade >>>
  final _bairroController = TextEditingController();
  final _idBairroController = TextEditingController();
  final _setorController = TextEditingController();
  final _identificadorImovelController = TextEditingController();
  final _observacaoController = TextEditingController();
  // <<< REMOÇÃO: Controllers de área/dimensão removidos >>>

  // <<< MUDANÇA: Campos para os novos dropdowns >>>
  StatusVisita? _statusVisitaSelecionado;
  String? _tipoImovelSelecionado;
  
  // Lista de opções para os dropdowns
  final List<String> _opcoesTipoImovel = ['Residencial', 'Comercial', 'Terreno Baldio', 'Ponto Estratégico', 'Outro'];

  Position? _posicaoAtualExibicao;
  bool _buscandoLocalizacao = false;
  String? _erroLocalizacao;
  bool _salvando = false;
  
  bool _isModoEdicao = false;
  bool _isVinculadoAQuarteirao = false;

  final ImagePicker _picker = ImagePicker();
  
  bool _isReadOnly = false;

  @override
  void initState() {
    super.initState();
    _setupInitialData();
  }

  // <<< MUDANÇA: Lógica de inicialização adaptada para Vistoria >>>
  Future<void> _setupInitialData() async {
    setState(() { _salvando = true; });

    if (widget.vistoriaParaEditar != null) {
      _isModoEdicao = true;
      final vistoriaDoBanco = await dbHelper.getVistoriaById(widget.vistoriaParaEditar!.dbId!);
      
      if (vistoriaDoBanco != null) {
        _vistoriaAtual = vistoriaDoBanco;
        _vistoriaAtual.focos = await dbHelper.getFocosDaVistoria(_vistoriaAtual.dbId!);
      } else {
        _vistoriaAtual = widget.vistoriaParaEditar!;
      }
      
      _isVinculadoAQuarteirao = _vistoriaAtual.setorId != null;
      // Vistorias fechadas ou recusadas também são read-only
      if (_vistoriaAtual.status != StatusVisita.pendente && _vistoriaAtual.status != StatusVisita.realizada) {
        _isReadOnly = true;
      }
    } else {
      _isModoEdicao = false;
      _isReadOnly = false;
      _isVinculadoAQuarteirao = true;
      // Cria uma nova vistoria vinculada ao quarteirão
      _vistoriaAtual = Vistoria(
        setorId: widget.quarteirao!.id,
        tipoImovel: '', // Será preenchido pelo usuário
        dataColeta: DateTime.now(),
        nomeBairro: widget.quarteirao!.bairroNome,
        nomeSetor: widget.quarteirao!.nome,
        idBairro: widget.quarteirao!.bairroId,
      );
    }
    _preencherControllersComDadosAtuais();
    setState(() { _salvando = false; });
  }

  void _preencherControllersComDadosAtuais() {
    final v = _vistoriaAtual;
    _bairroController.text = v.nomeBairro ?? '';
    _setorController.text = v.nomeSetor ?? '';
    _idBairroController.text = v.idBairro ?? '';
    _identificadorImovelController.text = v.identificadorImovel ?? '';
    _observacaoController.text = v.observacao ?? '';
    
    // Preenche os valores dos dropdowns
    _statusVisitaSelecionado = v.status;
    if (_opcoesTipoImovel.contains(v.tipoImovel)) {
      _tipoImovelSelecionado = v.tipoImovel;
    }
    
    if (v.latitude != null && v.longitude != null) {
      _posicaoAtualExibicao = Position(latitude: v.latitude!, longitude: v.longitude!, timestamp: DateTime.now(), accuracy: 0.0, altitude: 0.0, altitudeAccuracy: 0.0, heading: 0.0, headingAccuracy: 0.0, speed: 0.0, speedAccuracy: 0.0);
    }
  }

  @override
  void dispose() {
    _bairroController.dispose();
    _idBairroController.dispose();
    _setorController.dispose();
    _identificadorImovelController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }
  
  // <<< MUDANÇA: Lógica para construir o objeto Vistoria a partir do formulário >>>
  Vistoria _construirObjetoVistoriaParaSalvar() {
    return _vistoriaAtual.copyWith(
      identificadorImovel: _identificadorImovelController.text.trim(),
      nomeBairro: _bairroController.text.trim(),
      idBairro: _idBairroController.text.trim().isNotEmpty ? _idBairroController.text.trim() : null,
      nomeSetor: _setorController.text.trim(),
      observacao: _observacaoController.text.trim(),
      tipoImovel: _tipoImovelSelecionado,
      status: _statusVisitaSelecionado,
      // O resultado (com/sem foco) será definido na próxima tela
    );
  }
  
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);
      if (pickedFile != null) {
        setState(() => _vistoriaAtual.photoPaths.add(pickedFile.path));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao selecionar imagem: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _reabrirParaEdicao() async {
    // Implementar lógica se necessário, mas geralmente não se reabre vistorias de recusa/fechada.
  }
  
  // <<< MUDANÇA: Salva os dados da vistoria e decide o próximo passo >>>
  Future<void> _salvarEVaiParaFocos() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoImovelSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o tipo de imóvel.'), backgroundColor: Colors.orange));
      return;
    }
    
    setState(() => _salvando = true);

    try {
      final vistoriaParaSalvar = _construirObjetoVistoriaParaSalvar();
      // Define a visita como realizada para poder adicionar focos
      final vistoriaAtualizada = vistoriaParaSalvar.copyWith(status: StatusVisita.realizada);

      // Usamos o novo método do DB Helper
      final vistoriaSalva = await dbHelper.saveFullVistoria(vistoriaAtualizada, _vistoriaAtual.focos);

      if (mounted) {
        // Navega para a tela de lista de focos
        await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ListaFocosPage(vistoria: vistoriaSalva)));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // <<< MUDANÇA: Salva a vistoria com status 'Fechada' ou 'Recusa' e volta. >>>
  Future<void> _finalizarVisitaSemAcesso() async {
    if (_statusVisitaSelecionado == null || _statusVisitaSelecionado == StatusVisita.realizada || _statusVisitaSelecionado == StatusVisita.pendente) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o status "Fechada" ou "Recusa" para usar esta opção.'), backgroundColor: Colors.orange));
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final vistoriaFinalizada = _construirObjetoVistoriaParaSalvar().copyWith(
        status: _statusVisitaSelecionado,
        resultado: 'Não Vistoriado',
      );
      await dbHelper.saveFullVistoria(vistoriaFinalizada, []); // Salva sem focos

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vistoria (sem acesso) salva com sucesso!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao finalizar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
  
  Future<void> _salvarAlteracoes() async {
    // Lógica semelhante ao _salvarEVaiParaFocos, mas sem navegar
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final vistoriaEditada = _construirObjetoVistoriaParaSalvar();
      final vistoriaSalva = await dbHelper.saveFullVistoria(vistoriaEditada, _vistoriaAtual.focos);
      
      if (mounted) {
        setState(() { _vistoriaAtual = vistoriaSalva; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _navegarParaListaFocos() async {
    if (_salvando) return;
    
    final foiAtualizado = await Navigator.push(context, MaterialPageRoute(builder: (context) => ListaFocosPage(vistoria: _vistoriaAtual)));
    
    if (foiAtualizado == true && mounted) {
      _recarregarTela();
    }
  }
  
  Future<void> _recarregarTela() async {
    if (_vistoriaAtual.dbId == null) return;
    final vistoriaRecarregada = await dbHelper.getVistoriaById(_vistoriaAtual.dbId!);
    if(vistoriaRecarregada != null && mounted) {
      final focosRecarregados = await dbHelper.getFocosDaVistoria(vistoriaRecarregada.dbId!);
      vistoriaRecarregada.focos = focosRecarregados;
      setState(() {
        _vistoriaAtual = vistoriaRecarregada;
        if (_vistoriaAtual.status != StatusVisita.pendente && _vistoriaAtual.status != StatusVisita.realizada) {
          _isReadOnly = true;
        }
        _preencherControllersComDadosAtuais();
      });
    }
  }

  Future<void> _obterLocalizacaoAtual() async {
    if (_isReadOnly) return;
    setState(() { _buscandoLocalizacao = true; _erroLocalizacao = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Serviço de GPS desabilitado.';
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permissão negada.';
      }
      if (permission == LocationPermission.deniedForever) throw 'Permissão negada permanentemente.';
      
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
      
      setState(() {
        _posicaoAtualExibicao = position;
        _vistoriaAtual = _vistoriaAtual.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });

    } catch (e) {
      setState(() => _erroLocalizacao = e.toString());
    } finally {
      if (mounted) setState(() => _buscandoLocalizacao = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isModoEdicao ? 'Dados da Vistoria' : 'Nova Vistoria'),
        backgroundColor: const Color(0xFF617359),
        foregroundColor: Colors.white,
      ),
      body: _salvando && !_buscandoLocalizacao
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isReadOnly)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: _vistoriaAtual.status.cor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(_vistoriaAtual.status.icone, size: 18, color: _vistoriaAtual.status.cor),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Visita finalizada como '${_vistoriaAtual.status.name}'.", style: TextStyle(color: _vistoriaAtual.status.cor))),
                        ],
                      ),
                    ),
                  // <<< MUDANÇA: Formulário adaptado para os novos campos >>>
                  _buildCamposHierarquia(),
                  const SizedBox(height: 16),
                  TextFormField(controller: _identificadorImovelController, enabled: !_isReadOnly, decoration: const InputDecoration(labelText: 'Identificação do Imóvel (Rua, Nº)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home_work_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null),
                  const SizedBox(height: 16),
                  _buildCamposDeVistoria(),
                  const SizedBox(height: 16),
                  _buildColetorCoordenadas(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                  const SizedBox(height: 16),
                  TextFormField(controller: _observacaoController, enabled: !_isReadOnly, decoration: const InputDecoration(labelText: 'Observações da Vistoria', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment), helperText: 'Opcional'), maxLines: 3),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
    );
  }

  // <<< MUDANÇA: Novos widgets para organizar o formulário >>>
  Widget _buildCamposHierarquia() {
    return Column(
      children: [
        TextFormField(controller: _bairroController, enabled: !_isVinculadoAQuarteirao && !_isReadOnly, decoration: const InputDecoration(labelText: 'Nome do Bairro', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city))),
        const SizedBox(height: 16),
        TextFormField(controller: _setorController, enabled: !_isVinculadoAQuarteirao && !_isReadOnly, decoration: const InputDecoration(labelText: 'Setor / Quarteirão', border: OutlineInputBorder(), prefixIcon: Icon(Icons.grid_on))),
      ],
    );
  }

  Widget _buildCamposDeVistoria() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _tipoImovelSelecionado,
          items: _opcoesTipoImovel.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: _isReadOnly ? null : (value) => setState(() => _tipoImovelSelecionado = value),
          decoration: const InputDecoration(labelText: 'Tipo do Imóvel', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
          validator: (v) => v == null ? 'Selecione um tipo' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<StatusVisita>(
          value: _statusVisitaSelecionado,
          items: StatusVisita.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
          onChanged: _isReadOnly ? null : (value) => setState(() => _statusVisitaSelecionado = value),
          decoration: const InputDecoration(labelText: 'Status da Visita', border: OutlineInputBorder(), prefixIcon: Icon(Icons.rule_outlined)),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_isReadOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 50, child: OutlinedButton.icon(onPressed: _navegarParaListaFocos, icon: const Icon(Icons.bug_report_outlined), label: const Text('Ver Focos Registrados', style: TextStyle(fontSize: 18)))),
        ],
      );
    }
    
    if (_isModoEdicao) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 50, child: ElevatedButton.icon(onPressed: _salvando ? null : _salvarAlteracoes, icon: _salvando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save_outlined), label: const Text('Salvar Dados da Vistoria', style: TextStyle(fontSize: 18)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white))),
          const SizedBox(height: 12),
          SizedBox(height: 50, child: ElevatedButton.icon(onPressed: _salvando ? null : _navegarParaListaFocos, icon: const Icon(Icons.bug_report_outlined), label: const Text('Ver/Editar Focos', style: TextStyle(fontSize: 18)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4433), foregroundColor: Colors.white))),
        ],
      );
    } else { 
      // Botões para uma nova vistoria
      final bool podeSalvarSemAcesso = _statusVisitaSelecionado == StatusVisita.fechada || _statusVisitaSelecionado == StatusVisita.recusa;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 50, child: OutlinedButton.icon(
            onPressed: _salvando || !podeSalvarSemAcesso ? null : _finalizarVisitaSemAcesso, 
            style: OutlinedButton.styleFrom(side: BorderSide(color: podeSalvarSemAcesso ? const Color(0xFF1D4433) : Colors.grey), foregroundColor: podeSalvarSemAcesso ? const Color(0xFF1D4433) : Colors.grey),
            icon: const Icon(Icons.block_outlined),
            label: const Text('Salvar (Sem Acesso)', style: TextStyle(fontSize: 16))
          )),
          const SizedBox(height: 12),
          SizedBox(height: 50, child: ElevatedButton.icon(
            onPressed: _salvando ? null : _salvarEVaiParaFocos, 
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4433), foregroundColor: Colors.white), 
            icon: _salvando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.arrow_forward_ios),
            label: const Text('Salvar e Adicionar Focos', style: TextStyle(fontSize: 16)))
          ),
        ],
      );
    }
  }

  // O resto dos widgets de build (_buildColetorCoordenadas, _buildPhotoSection) podem ser mantidos como estão.
  // Vou apenas renomear o título da seção de fotos para ficar mais claro.
  Widget _buildColetorCoordenadas() {
    final latExibicao = _posicaoAtualExibicao?.latitude ?? _vistoriaAtual.latitude;
    final lonExibicao = _posicaoAtualExibicao?.longitude ?? _vistoriaAtual.longitude;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coordenadas do Imóvel', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Expanded(
              child: _buscandoLocalizacao
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Buscando...')])
                : _erroLocalizacao != null
                  ? Text('Erro: $_erroLocalizacao', style: const TextStyle(color: Colors.red))
                  : (latExibicao == null)
                    ? const Text('Nenhuma localização obtida.')
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Lat: ${latExibicao.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Lon: ${lonExibicao!.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (_posicaoAtualExibicao != null && _posicaoAtualExibicao!.accuracy > 0)
                          Text('Precisão: ±${_posicaoAtualExibicao!.accuracy.toStringAsFixed(1)}m', style: TextStyle(color: Colors.grey[700])),
                      ]),
            ),
            IconButton(icon: const Icon(Icons.my_location, color: Color(0xFF1D4433)), onPressed: _buscandoLocalizacao || _isReadOnly ? null : _obterLocalizacaoAtual, tooltip: 'Obter localização'),
          ]),
        ),
      ],
    );
  }
  
  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos Gerais do Imóvel', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              _vistoriaAtual.photoPaths.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Text('Nenhuma foto adicionada.')))
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: _vistoriaAtual.photoPaths.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_vistoriaAtual.photoPaths[index]), fit: BoxFit.cover)),
                            if (!_isReadOnly)
                              Positioned(
                                top: -8, right: -8,
                                child: IconButton(
                                  icon: const CircleAvatar(backgroundColor: Colors.white, radius: 12, child: Icon(Icons.close, color: Colors.red, size: 16)),
                                  onPressed: () => setState(() => _vistoriaAtual.photoPaths.removeAt(index)),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              if (!_isReadOnly) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Câmera'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'))),
                  ],
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }
}