import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../container_actions.dart';

/// Écoute le canal natif `malistock/native` : quand l'utilisateur
/// double-clique un second fichier `.mstk` pendant que l'application
/// tourne déjà, le C++ (windows/runner/flutter_window.cpp, réception
/// de `WM_COPYDATA` envoyé par la nouvelle instance qui vient de se
/// fermer) transmet ici le chemin du fichier, exactement comme si
/// l'utilisateur avait cliqué "Ouvrir" dans le menu Fichier.
///
/// Doit englober `MaterialApp.router` (pas forcément à l'intérieur de
/// son arbre de navigation) : la navigation se fait via
/// `rootNavigatorKey`, pas via le `BuildContext` de ce widget.
class NativeChannelListener extends ConsumerStatefulWidget {
  final Widget child;
  const NativeChannelListener({super.key, required this.child});

  @override
  ConsumerState<NativeChannelListener> createState() =>
      _NativeChannelListenerState();
}

class _NativeChannelListenerState
    extends ConsumerState<NativeChannelListener> {
  static const _canal = MethodChannel('malistock/native');

  @override
  void initState() {
    super.initState();
    _canal.setMethodCallHandler(_onMethodCall);
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'openFileRequested') return;
    final chemin = call.arguments as String?;
    if (chemin == null || chemin.isEmpty) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    await ContainerActions.ouvrir(context, ref, cheminPredefini: chemin);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
