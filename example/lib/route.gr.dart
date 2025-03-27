// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'route.dart';

/// generated route for
/// [MyHomePage]
class MyHomeRoute extends PageRouteInfo<void> {
  const MyHomeRoute({List<PageRouteInfo>? children})
      : super(MyHomeRoute.name, initialChildren: children);

  static const String name = 'MyHomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MyHomePage();
    },
  );
}

/// generated route for
/// [SecondPage]
class SecondRoute extends PageRouteInfo<SecondRouteArgs> {
  SecondRoute({required String id, Key? key, List<PageRouteInfo>? children})
      : super(
          SecondRoute.name,
          args: SecondRouteArgs(id: id, key: key),
          initialChildren: children,
        );

  static const String name = 'SecondRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SecondRouteArgs>();
      return SecondPage(args.id, key: args.key);
    },
  );
}

class SecondRouteArgs {
  const SecondRouteArgs({required this.id, this.key});

  final String id;

  final Key? key;

  @override
  String toString() {
    return 'SecondRouteArgs{id: $id, key: $key}';
  }
}
