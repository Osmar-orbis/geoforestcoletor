// lib/services/licensing_service.dart (CORREÇÃO DE SINTAXE)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);
  @override
  String toString() => message;
}

class LicensingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> checkAndRegisterDevice(User user) async {
    final clienteSnapshot = await _firestore
        .collection('clientes')
        .where('usuariosPermitidos', arrayContains: user.email)
        .limit(1)
        .get();

    if (clienteSnapshot.docs.isEmpty) {
      throw LicenseException('Seu e-mail não está autorizado a usar este aplicativo. Contate o administrador da sua empresa.');
    }

    final clienteDoc = clienteSnapshot.docs.first;
    final clienteData = clienteDoc.data();
    final statusAssinatura = clienteData['statusAssinatura'];
    final limites = clienteData['limites'];

    bool acessoPermitido = false;

    if (statusAssinatura == 'ativa') {
      acessoPermitido = true;
    } 
    else if (statusAssinatura == 'trial') {
      final trialData = clienteData['trial'] as Map<String, dynamic>?;
      if (trialData != null && trialData['ativo'] == true) {
        final dataFimTimestamp = trialData['dataFim'] as Timestamp?;
        if (dataFimTimestamp != null) {
          final dataFim = dataFimTimestamp.toDate();
          if (DateTime.now().isBefore(dataFim)) {
            acessoPermitido = true;
          } else {
            throw LicenseException('Seu período de teste expirou. Contate o suporte para contratar um plano.');
          }
        }
      }
    }

    if (!acessoPermitido) {
      throw LicenseException('A assinatura da sua empresa está inativa ou expirou. Por favor, contate o administrador.');
    }

    final tipoDispositivo = kIsWeb ? 'desktop' : 'smartphone';
    final deviceId = await _getDeviceId();

    if (deviceId == null) {
      throw LicenseException('Não foi possível identificar seu dispositivo.');
    }
    
    final dispositivosAtivosRef = clienteDoc.reference.collection('dispositivosAtivos');
    final dispositivoExistente = await dispositivosAtivosRef.doc(deviceId).get();

    if (dispositivoExistente.exists) {
      print('Dispositivo conhecido. Acesso permitido.');
      return; 
    }

    final dispositivosRegistradosSnapshot = await dispositivosAtivosRef
        .where('tipo', isEqualTo: tipoDispositivo)
        .count()
        .get();
        
    final contagemAtual = dispositivosRegistradosSnapshot.count ?? 0;
    final limiteAtual = limites[tipoDispositivo] as int;

    if (contagemAtual >= limiteAtual) {
      throw LicenseException('O limite de dispositivos do tipo "$tipoDispositivo" foi atingido para sua empresa.');
    }
    
    await dispositivosAtivosRef.doc(deviceId).set({
      'uidUsuario': user.uid,
      'emailUsuario': user.email,
      'tipo': tipoDispositivo,
      'registradoEm': FieldValue.serverTimestamp(),
      'nomeDispositivo': await _getDeviceName(),
    });

    print('Novo dispositivo registrado com sucesso!');
  }

  Future<Map<String, int>> getDeviceUsage(String userEmail) async {
    final clienteSnapshot = await _firestore
        .collection('clientes')
        .where('usuariosPermitidos', arrayContains: userEmail)
        .limit(1)
        .get();

    if (clienteSnapshot.docs.isEmpty) {
      return {'smartphone': 0, 'desktop': 0};
    }

    final clienteDoc = clienteSnapshot.docs.first;
    final dispositivosAtivosRef = clienteDoc.reference.collection('dispositivosAtivos');

    final smartphoneCountSnapshot = await dispositivosAtivosRef
        .where('tipo', isEqualTo: 'smartphone')
        .count()
        .get();
    final smartphoneCount = smartphoneCountSnapshot.count ?? 0;

    final desktopCountSnapshot = await dispositivosAtivosRef
        .where('tipo', isEqualTo: 'desktop')
        .count()
        .get();
    final desktopCount = desktopCountSnapshot.count ?? 0;

    return {
      'smartphone': smartphoneCount,
      'desktop': desktopCount,
    };
  }

  Future<String?> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      return 'web_${webInfo.vendor}_${webInfo.userAgent}';
    }
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor;
    }
    if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      return windowsInfo.deviceId;
    }
    return null;
  }

  Future<String> _getDeviceName() async {
     final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) return 'Navegador Web';
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}';
      }
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.name;
      }
      if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        return info.computerName;
      }
      return 'Dispositivo Desconhecido';
  }
}