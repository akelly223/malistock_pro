import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Accès minimal au registre Windows via `advapi32.dll` (présent sur
/// toute machine Windows, rien à installer) : lecture/écriture de
/// valeurs texte. Utilisé par la licence pour lire l'identifiant unique
/// du PC et conserver une copie de l'état d'essai.
///
/// Toutes les méthodes renvoient null/false en cas d'échec plutôt que
/// de lever une exception : la licence doit se dégrader proprement.
abstract final class WindowsRegistry {
  // Valeurs des clés racines telles que définies par les en-têtes
  // Windows : un LONG négatif étendu en signe à la taille d'un pointeur.
  static const int hkeyCurrentUser = -0x7FFFFFFF; // 0x80000001
  static const int hkeyLocalMachine = -0x7FFFFFFE; // 0x80000002

  static const int _rrfRtRegSz = 0x00000002;
  static const int _rrfSubkeyWow6464Key = 0x00010000;
  static const int _regSz = 1;
  static const int _errorSuccess = 0;

  static String? lireTexte(int racine, String sousCle, String nomValeur) {
    if (!Platform.isWindows) return null;
    return using((arena) {
      final pSousCle = sousCle.toNativeUtf16(allocator: arena);
      final pNom = nomValeur.toNativeUtf16(allocator: arena);
      final pTaille = arena<Uint32>();
      const drapeaux = _rrfRtRegSz | _rrfSubkeyWow6464Key;

      var res = _api.regGetValue(
          racine, pSousCle, pNom, drapeaux, nullptr, nullptr, pTaille);
      if (res != _errorSuccess || pTaille.value == 0) return null;

      final tampon = arena<Uint8>(pTaille.value);
      res = _api.regGetValue(
          racine, pSousCle, pNom, drapeaux, nullptr, tampon.cast(), pTaille);
      if (res != _errorSuccess) return null;
      return tampon.cast<Utf16>().toDartString();
    });
  }

  /// Crée la sous-clé si besoin.
  static bool ecrireTexte(
      int racine, String sousCle, String nomValeur, String valeur) {
    if (!Platform.isWindows) return false;
    return using((arena) {
      final pSousCle = sousCle.toNativeUtf16(allocator: arena);
      final pNom = nomValeur.toNativeUtf16(allocator: arena);
      final pValeur = valeur.toNativeUtf16(allocator: arena);
      final octets = (valeur.length + 1) * 2;
      final res = _api.regSetKeyValue(
          racine, pSousCle, pNom, _regSz, pValeur.cast(), octets);
      return res == _errorSuccess;
    });
  }

  /// Identifiant unique de l'installation Windows (`MachineGuid`),
  /// stable tant que Windows n'est pas réinstallé.
  static String? identifiantMachine() => lireTexte(
        hkeyLocalMachine,
        r'SOFTWARE\Microsoft\Cryptography',
        'MachineGuid',
      );

  static final _Advapi32 _api = _Advapi32();
}

class _Advapi32 {
  _Advapi32() : _lib = DynamicLibrary.open('advapi32.dll');

  final DynamicLibrary _lib;

  late final int Function(int, Pointer<Utf16>, Pointer<Utf16>, int,
          Pointer<Uint32>, Pointer<Void>, Pointer<Uint32>) regGetValue =
      _lib.lookupFunction<
          Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Uint32,
              Pointer<Uint32>, Pointer<Void>, Pointer<Uint32>),
          int Function(int, Pointer<Utf16>, Pointer<Utf16>, int,
              Pointer<Uint32>, Pointer<Void>, Pointer<Uint32>)>('RegGetValueW');

  late final int Function(
          int, Pointer<Utf16>, Pointer<Utf16>, int, Pointer<Void>, int)
      regSetKeyValue = _lib.lookupFunction<
          Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Uint32,
              Pointer<Void>, Uint32),
          int Function(int, Pointer<Utf16>, Pointer<Utf16>, int, Pointer<Void>,
              int)>('RegSetKeyValueW');
}
