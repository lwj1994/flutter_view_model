import 'dart:async';
import 'dart:math';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart' as vm;
import 'package:view_model/view_model.dart';

import 'route.dart';

void main() {
  runApp(const MyApp());
  ViewModel.initConfig(ViewModelConfig(logEnable: true));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerDelegate: appRouter.delegate(navigatorObservers: () {
        return [];
      }),
      routeInformationParser: appRouter.defaultRouteParser(),
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}

@RoutePage()
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with ViewModelStateMixin {
  MainViewModel get _viewModel =>
      getViewModel<MainViewModel>(factory: MainViewModelFactory(arg: "arg1"));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Text("main vm state:${_viewModel.state}"),
          FilledButton(
              onPressed: () {
                appRouter
                    .push(SecondRoute(id: Random().nextInt(1000).toString()));
              },
              child: const Text("push random id")),
          FilledButton(
              onPressed: () {
                appRouter.push(SecondRoute(id: "1"));
              },
              child: const Text("push 1")),
        ],
      ),
    );
  }
}

class MainViewModelFactory with vm.ViewModelFactory<MainViewModel> {
  final String arg;

  MainViewModelFactory({this.arg = ""});

  @override
  MainViewModel build() {
    return MainViewModel(state: arg);
  }

  @override
  bool singleton() {
    return true;
  }
}

class MainViewModel extends ViewModel<String> {
  MainViewModel({required super.state}) {
    print("MainViewModel create : $hashCode");
    final t = Timer.periodic(Duration(seconds: 1), (t) {
      setState("update ${t.tick}");
    });
    addDispose(t.cancel);
  }

  @override
  void dispose() {
    super.dispose();
    print("MainViewModel dispose $hashCode");
  }
}
