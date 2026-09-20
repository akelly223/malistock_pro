import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// AES-256-GCM via l'API CNG native de Windows (`bcrypt.dll`), accessible
/// sur toute machine Windows 10+ sans rien à installer ni compiler
/// (contrairement à `package:cryptography`, pur Dart, mesuré à ~9 Mo/s
/// seulement sur cette machine — voir la discussion de performance
/// d'ouverture des fichiers `.mstk`).
///
/// N'existe QUE pour accélérer le chiffrement/déchiffrement du payload
/// (AES-GCM) : la dérivation de clé (PBKDF2/HKDF) reste gérée par
/// `package:cryptography` dans [MstkCrypto], seul AES-GCM étant coûteux
/// à l'échelle d'un fichier `.mstk` de plusieurs dizaines de Mo.
abstract final class MstkCryptoWindowsNative {
  static bool get disponible => Platform.isWindows;

  /// Chiffre [clair] avec AES-256-GCM. Retourne (ciphertext, tag 16 octets).
  static (Uint8List ciphertext, Uint8List tag) chiffrer({
    required Uint8List cle,
    required Uint8List nonce,
    required Uint8List clair,
  }) =>
      _chiffrerOuDechiffrer(
        cle: cle,
        nonce: nonce,
        entree: clair,
        chiffrement: true,
        tagAttendu: null,
      );

  /// Déchiffre [ciphertext] avec le [tag] d'authentification fourni.
  /// Lève [MstkAuthTagInvalideException] si le tag ne correspond pas
  /// (mot de passe incorrect ou contenu altéré).
  static Uint8List dechiffrer({
    required Uint8List cle,
    required Uint8List nonce,
    required Uint8List ciphertext,
    required Uint8List tag,
  }) {
    final (clair, _) = _chiffrerOuDechiffrer(
      cle: cle,
      nonce: nonce,
      entree: ciphertext,
      chiffrement: false,
      tagAttendu: tag,
    );
    return clair;
  }

  static (Uint8List, Uint8List) _chiffrerOuDechiffrer({
    required Uint8List cle,
    required Uint8List nonce,
    required Uint8List entree,
    required bool chiffrement,
    required Uint8List? tagAttendu,
  }) {
    final bcrypt = _BCrypt.instance;

    final phAlgorithm = calloc<IntPtr>();
    final phKey = calloc<IntPtr>();
    Pointer<Uint8> pbKeyObject = nullptr;
    Pointer<Uint8> pbCle = nullptr;
    Pointer<Uint8> pbNonce = nullptr;
    Pointer<Uint8> pbTag = nullptr;
    Pointer<Uint8> pbEntree = nullptr;
    Pointer<Uint8> pbSortie = nullptr;
    Pointer<Uint32> pcbResultat = nullptr;
    Pointer<_BCryptAuthCipherModeInfo> pInfo = nullptr;
    Pointer<Utf16> pAlgId = nullptr;
    Pointer<Utf16> pChainingProp = nullptr;
    Pointer<Utf16> pChainingVal = nullptr;
    Pointer<Utf16> pObjLenProp = nullptr;

    try {
      pAlgId = 'AES'.toNativeUtf16();
      var status =
          bcrypt.bCryptOpenAlgorithmProvider(phAlgorithm, pAlgId, nullptr, 0);
      _verifier(status, 'BCryptOpenAlgorithmProvider');
      final hAlgorithm = phAlgorithm.value;

      pChainingProp = 'ChainingMode'.toNativeUtf16();
      pChainingVal = 'ChainingModeGCM'.toNativeUtf16();
      status = bcrypt.bCryptSetProperty(
        hAlgorithm,
        pChainingProp,
        pChainingVal.cast(),
        (('ChainingModeGCM'.length + 1) * 2),
        0,
      );
      _verifier(status, 'BCryptSetProperty(ChainingMode)');

      // Taille du buffer nécessaire pour l'objet clé (dépend de l'algo).
      pObjLenProp = 'ObjectLength'.toNativeUtf16();
      final pcbObjLen = calloc<Uint32>();
      final pcbResult0 = calloc<Uint32>();
      status = bcrypt.bCryptGetProperty(
          hAlgorithm, pObjLenProp, pcbObjLen.cast(), 4, pcbResult0, 0);
      _verifier(status, 'BCryptGetProperty(ObjectLength)');
      final cbKeyObject = pcbObjLen.value;
      calloc.free(pcbObjLen);
      calloc.free(pcbResult0);

      pbKeyObject = calloc<Uint8>(cbKeyObject);
      pbCle = calloc<Uint8>(cle.length);
      pbCle.asTypedList(cle.length).setAll(0, cle);

      status = bcrypt.bCryptGenerateSymmetricKey(
          hAlgorithm, phKey, pbKeyObject, cbKeyObject, pbCle, cle.length, 0);
      _verifier(status, 'BCryptGenerateSymmetricKey');
      final hKey = phKey.value;

      pbNonce = calloc<Uint8>(nonce.length);
      pbNonce.asTypedList(nonce.length).setAll(0, nonce);

      const tagLength = 16;
      pbTag = calloc<Uint8>(tagLength);
      if (!chiffrement && tagAttendu != null) {
        pbTag.asTypedList(tagLength).setAll(0, tagAttendu);
      }

      pInfo = calloc<_BCryptAuthCipherModeInfo>();
      final info = pInfo.ref;
      info.cbSize = sizeOf<_BCryptAuthCipherModeInfo>();
      info.dwInfoVersion = 1;
      info.pbNonce = pbNonce;
      info.cbNonce = nonce.length;
      info.pbAuthData = nullptr;
      info.cbAuthData = 0;
      info.pbTag = pbTag;
      info.cbTag = tagLength;
      info.pbMacContext = nullptr;
      info.cbMacContext = 0;
      info.cbAAD = 0;
      info.cbData = 0;
      info.dwFlags = 0;

      pbEntree = calloc<Uint8>(entree.isEmpty ? 1 : entree.length);
      if (entree.isNotEmpty) {
        pbEntree.asTypedList(entree.length).setAll(0, entree);
      }
      pbSortie = calloc<Uint8>(entree.isEmpty ? 1 : entree.length);
      pcbResultat = calloc<Uint32>();

      if (chiffrement) {
        status = bcrypt.bCryptEncrypt(hKey, pbEntree, entree.length,
            pInfo.cast(), nullptr, 0, pbSortie, entree.length, pcbResultat, 0);
        _verifier(status, 'BCryptEncrypt');
      } else {
        status = bcrypt.bCryptDecrypt(hKey, pbEntree, entree.length,
            pInfo.cast(), nullptr, 0, pbSortie, entree.length, pcbResultat, 0);
        if (status == _statusAuthTagMismatch) {
          throw const MstkAuthTagInvalideException();
        }
        _verifier(status, 'BCryptDecrypt');
      }

      final sortie =
          Uint8List.fromList(pbSortie.asTypedList(pcbResultat.value));
      final tagFinal = Uint8List.fromList(pbTag.asTypedList(tagLength));

      bcrypt.bCryptDestroyKey(hKey);
      bcrypt.bCryptCloseAlgorithmProvider(hAlgorithm, 0);

      return (sortie, tagFinal);
    } finally {
      calloc.free(phAlgorithm);
      calloc.free(phKey);
      if (pbKeyObject != nullptr) calloc.free(pbKeyObject);
      if (pbCle != nullptr) calloc.free(pbCle);
      if (pbNonce != nullptr) calloc.free(pbNonce);
      if (pbTag != nullptr) calloc.free(pbTag);
      if (pbEntree != nullptr) calloc.free(pbEntree);
      if (pbSortie != nullptr) calloc.free(pbSortie);
      if (pcbResultat != nullptr) calloc.free(pcbResultat);
      if (pInfo != nullptr) calloc.free(pInfo);
      if (pAlgId != nullptr) calloc.free(pAlgId);
      if (pChainingProp != nullptr) calloc.free(pChainingProp);
      if (pChainingVal != nullptr) calloc.free(pChainingVal);
      if (pObjLenProp != nullptr) calloc.free(pObjLenProp);
    }
  }

  static const int _statusAuthTagMismatch = -1073700862; // 0xC000A002

  static void _verifier(int status, String appel) {
    if (status != 0) {
      throw StateError(
          '$appel a échoué : NTSTATUS 0x${status.toRadixString(16)}');
    }
  }
}

/// Le tag d'authentification AES-GCM ne correspond pas : mot de passe
/// incorrect ou contenu altéré (équivalent natif de
/// `SecretBoxAuthenticationError` de `package:cryptography`).
class MstkAuthTagInvalideException implements Exception {
  const MstkAuthTagInvalideException();
}

final class _BCryptAuthCipherModeInfo extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int dwInfoVersion;
  external Pointer<Uint8> pbNonce;
  @Uint32()
  external int cbNonce;
  external Pointer<Uint8> pbAuthData;
  @Uint32()
  external int cbAuthData;
  external Pointer<Uint8> pbTag;
  @Uint32()
  external int cbTag;
  external Pointer<Uint8> pbMacContext;
  @Uint32()
  external int cbMacContext;
  @Uint32()
  external int cbAAD;
  @Uint64()
  external int cbData;
  @Uint32()
  external int dwFlags;
}

typedef _BCryptOpenAlgorithmProviderNative = Int32 Function(
    Pointer<IntPtr> phAlgorithm,
    Pointer<Utf16> pszAlgId,
    Pointer<Utf16> pszImplementation,
    Uint32 dwFlags);
typedef _BCryptOpenAlgorithmProviderDart = int Function(
    Pointer<IntPtr> phAlgorithm,
    Pointer<Utf16> pszAlgId,
    Pointer<Utf16> pszImplementation,
    int dwFlags);

typedef _BCryptSetPropertyNative = Int32 Function(IntPtr hObject,
    Pointer<Utf16> pszProperty, Pointer<Uint8> pbInput, Uint32 cbInput,
    Uint32 dwFlags);
typedef _BCryptSetPropertyDart = int Function(int hObject,
    Pointer<Utf16> pszProperty, Pointer<Uint8> pbInput, int cbInput,
    int dwFlags);

typedef _BCryptGetPropertyNative = Int32 Function(
    IntPtr hObject,
    Pointer<Utf16> pszProperty,
    Pointer<Uint8> pbOutput,
    Uint32 cbOutput,
    Pointer<Uint32> pcbResult,
    Uint32 dwFlags);
typedef _BCryptGetPropertyDart = int Function(
    int hObject,
    Pointer<Utf16> pszProperty,
    Pointer<Uint8> pbOutput,
    int cbOutput,
    Pointer<Uint32> pcbResult,
    int dwFlags);

typedef _BCryptGenerateSymmetricKeyNative = Int32 Function(
    IntPtr hAlgorithm,
    Pointer<IntPtr> phKey,
    Pointer<Uint8> pbKeyObject,
    Uint32 cbKeyObject,
    Pointer<Uint8> pbSecret,
    Uint32 cbSecret,
    Uint32 dwFlags);
typedef _BCryptGenerateSymmetricKeyDart = int Function(
    int hAlgorithm,
    Pointer<IntPtr> phKey,
    Pointer<Uint8> pbKeyObject,
    int cbKeyObject,
    Pointer<Uint8> pbSecret,
    int cbSecret,
    int dwFlags);

typedef _BCryptEncryptDecryptNative = Int32 Function(
    IntPtr hKey,
    Pointer<Uint8> pbInput,
    Uint32 cbInput,
    Pointer<Void> pPaddingInfo,
    Pointer<Uint8> pbIV,
    Uint32 cbIV,
    Pointer<Uint8> pbOutput,
    Uint32 cbOutput,
    Pointer<Uint32> pcbResult,
    Uint32 dwFlags);
typedef _BCryptEncryptDecryptDart = int Function(
    int hKey,
    Pointer<Uint8> pbInput,
    int cbInput,
    Pointer<Void> pPaddingInfo,
    Pointer<Uint8> pbIV,
    int cbIV,
    Pointer<Uint8> pbOutput,
    int cbOutput,
    Pointer<Uint32> pcbResult,
    int dwFlags);

typedef _BCryptDestroyKeyNative = Int32 Function(IntPtr hKey);
typedef _BCryptDestroyKeyDart = int Function(int hKey);

typedef _BCryptCloseAlgorithmProviderNative = Int32 Function(
    IntPtr hAlgorithm, Uint32 dwFlags);
typedef _BCryptCloseAlgorithmProviderDart = int Function(
    int hAlgorithm, int dwFlags);

/// Liaisons FFI minimales vers `bcrypt.dll` (Windows CNG), chargées une
/// seule fois (singleton) — seules les fonctions utilisées par
/// [MstkCryptoWindowsNative] sont liées.
class _BCrypt {
  static final _BCrypt instance = _BCrypt._();

  late final DynamicLibrary _lib;
  late final _BCryptOpenAlgorithmProviderDart bCryptOpenAlgorithmProvider;
  late final _BCryptSetPropertyDart bCryptSetProperty;
  late final _BCryptGetPropertyDart bCryptGetProperty;
  late final _BCryptGenerateSymmetricKeyDart bCryptGenerateSymmetricKey;
  late final _BCryptEncryptDecryptDart bCryptEncrypt;
  late final _BCryptEncryptDecryptDart bCryptDecrypt;
  late final _BCryptDestroyKeyDart bCryptDestroyKey;
  late final _BCryptCloseAlgorithmProviderDart bCryptCloseAlgorithmProvider;

  _BCrypt._() {
    _lib = DynamicLibrary.open('bcrypt.dll');
    bCryptOpenAlgorithmProvider = _lib.lookupFunction<
        _BCryptOpenAlgorithmProviderNative,
        _BCryptOpenAlgorithmProviderDart>('BCryptOpenAlgorithmProvider');
    bCryptSetProperty = _lib.lookupFunction<_BCryptSetPropertyNative,
        _BCryptSetPropertyDart>('BCryptSetProperty');
    bCryptGetProperty = _lib.lookupFunction<_BCryptGetPropertyNative,
        _BCryptGetPropertyDart>('BCryptGetProperty');
    bCryptGenerateSymmetricKey = _lib.lookupFunction<
        _BCryptGenerateSymmetricKeyNative,
        _BCryptGenerateSymmetricKeyDart>('BCryptGenerateSymmetricKey');
    bCryptEncrypt = _lib.lookupFunction<_BCryptEncryptDecryptNative,
        _BCryptEncryptDecryptDart>('BCryptEncrypt');
    bCryptDecrypt = _lib.lookupFunction<_BCryptEncryptDecryptNative,
        _BCryptEncryptDecryptDart>('BCryptDecrypt');
    bCryptDestroyKey = _lib.lookupFunction<_BCryptDestroyKeyNative,
        _BCryptDestroyKeyDart>('BCryptDestroyKey');
    bCryptCloseAlgorithmProvider = _lib.lookupFunction<
        _BCryptCloseAlgorithmProviderNative,
        _BCryptCloseAlgorithmProviderDart>('BCryptCloseAlgorithmProvider');
  }
}
