import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';

import 'main.dart';
import 'page.dart';

part 'route.gr.dart';

/// @author luwenjie on 2024/7/27 23:47:56

final appRouter = AppRouter();

@AutoRouterConfig(
  replaceInRouteName: 'Page,Route',
)
// extend the generated private router
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => _buildRouteType();
  RouteType _buildRouteType() {
    return const RouteType.cupertino();
  }

  @override
  final List<AutoRoute> routes = [
    AutoRoute(path: "/", page: MyHomeRoute.page),
    AutoRoute(path: "/second", page: SecondRoute.page),
  ];
}
