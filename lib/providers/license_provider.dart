// lib/providers/license_provider.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoforestcoletor/services/licensing_service.dart';

// Um modelo simples para guardar as informações da licença carregada
class LicenseInfo {
  final Map<String, dynamic> limits;
  final Map<String, dynamic> features;
  final String planName;

  LicenseInfo({
    required this.limits,
    required this.features,
    required this.planName,
  });

  // Getter para verificar se a feature de análise está habilitada
  bool get canUseAnalysis => features['analise'] ?? false;
  
  // Adicione outros getters para outras features premium aqui.
}

class LicenseProvider with ChangeNotifier {
  final LicensingService _licensingService = LicensingService();
  LicenseInfo? _licenseInfo;
  bool _isLoading = false;
  String? _error;

  // Getters para a UI usar
  bool get isLoading => _isLoading;
  String? get error => _error;
  LicenseInfo? get licenseInfo => _licenseInfo;

  // Carrega os detalhes da licença para um usuário específico
  Future<void> loadLicense(User user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Usa o serviço para buscar os detalhes da licença no Firestore
      final licenseDetails = await _licensingService.getLicenseDetailsForUser(user);
      final planoData = licenseDetails['planoData'] as Map<String, dynamic>;
      
      // Cria o nosso objeto LicenseInfo com os dados do plano
      _licenseInfo = LicenseInfo(
        limits: planoData['limites'] as Map<String, dynamic>? ?? {},
        features: planoData['features'] as Map<String, dynamic>? ?? {},
        planName: planoData['nome'] as String? ?? 'Desconhecido',
      );

    } catch (e) {
      _error = e.toString();
      _licenseInfo = null; // Garante que não haja licença em caso de erro
    } finally {
      _isLoading = false;
      notifyListeners(); // Notifica a UI que o carregamento terminou
    }
  }

  // Limpa os dados da licença ao fazer logout
  void clearLicense() {
    _licenseInfo = null;
    _error = null;
    notifyListeners();
  }
}