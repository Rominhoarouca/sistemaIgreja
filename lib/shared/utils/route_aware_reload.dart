import 'package:flutter/widgets.dart';

import '../../routing/route_observer.dart';

/// Recarrega a tela quando a rota empilhada por cima dela é fechada.
///
/// Sem isso, cadastrar em outra tela ("Novo Cadastro", "Nova Célula") e voltar
/// deixava a lista antiga até um pull-to-refresh manual.
///
/// Uso: `with RouteAwareReload<MinhaPagina>` no `State` e implementar
/// [onRouteReturn] chamando o próprio carregamento.
mixin RouteAwareReload<T extends StatefulWidget> on State<T> implements RouteAware {
  ModalRoute<void>? _route;

  /// Chamado quando esta rota volta a ser a do topo.
  void onRouteReturn();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    if (_route != null) appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => onRouteReturn();

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
