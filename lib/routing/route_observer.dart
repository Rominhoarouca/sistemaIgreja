import 'package:flutter/widgets.dart';

/// Observador do navegador raiz.
///
/// Existe para as telas de lista recarregarem sozinhas quando a rota empilhada
/// por cima delas é fechada — cadastrar um líder em "Novo Cadastro" e voltar
/// para a home deixava a lista antiga na tela até um pull-to-refresh.
///
/// Uso: `with RouteAware` no State, `subscribe` no `didChangeDependencies`,
/// `unsubscribe` no `dispose`, e recarregar em `didPopNext()`.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
