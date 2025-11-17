import 'package:flutter/widgets.dart';

class PageRouteAwareController implements RouteAware {
  final Function() onPause;
  final Function() onResume;
  PageRouteAwareController(
    this.observer, {
    required this.onPause,
    required this.onResume,
  });

  final RouteObserver<PageRoute> observer;
  final List<PageRoute> _subscribedRoutes = [];

  bool _isPaused = false;

  bool get isPaused => _isPaused;

  void subscribe(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      if (!_subscribedRoutes.contains(route)) {
        if (_subscribedRoutes.isNotEmpty) {
          unsubscribe();
        }
        _subscribedRoutes.add(route);
        observer.subscribe(this, route);
      }
    }
  }

  void unsubscribe() {
    observer.unsubscribe(this);
    _subscribedRoutes.clear();
  }

  @override
  void didPop() {}

  @override
  void didPopNext() {
    _isPaused = false;
    onResume();
  }

  @override
  void didPush() {}

  @override
  void didPushNext() {
    _isPaused = true;
    onPause();
  }
}
