import 'package:built_redux/built_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_built_redux/flutter_built_redux.dart' as redux;

export 'package:flutter_built_redux/flutter_built_redux.dart'
    hide StoreConnection;

/// Re-evaluate display values on rebuilds, including locale and clock changes.
/// The original subscription still filters state updates; the child keeps its
/// identity, navigation state, focus, and text controllers.
class StoreConnection<S, A extends ReduxActions, L>
    extends redux.StoreConnection<S, A, L> {
  StoreConnection({super.key, required super.connect, required super.builder});

  @override
  Widget build(BuildContext context, L state, A actions) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<redux.ReduxProvider>()!;
    return super.build(context, connect(provider.store.state as S), actions);
  }
}
