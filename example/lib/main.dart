import 'dart:async';
import 'dart:math';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart' as vm;
import 'package:view_model/view_model.dart';

import 'other/view_model.dart' as mainvm2;
import 'route.dart';

void main() {
  runApp(const MyApp());
  vm.ViewModel.logEnable = (true);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerDelegate: appRouter.delegate(navigatorObservers: () {
        return [];
      }),
      routeInformationParser: appRouter.defaultRouteParser(),
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}

@RoutePage()
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with ViewModelStateMixin {
  MainViewModel get _viewModel =>
      getViewModel<MainViewModel>(factory: MainViewModelFactory(arg: "1"));

  mainvm2.MainViewModel get _viewModel2 => getViewModel<mainvm2.MainViewModel>(
        factory: mainvm2.MainViewModelFactory(arg: "mainvm2"),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Text("main vm state:${_viewModel.state}"),
          Text("main vm2 state:${_viewModel2.state}"),
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
  bool unique() {
    return true;
  }
}

class MainViewModel extends ViewModel<String> {
  MainViewModel({required super.state}) {
    print("MainViewModel create : $hashCode");
    final t = Timer.periodic(Duration(seconds: 1), (t) {
      setState((s) => "update ${t.tick}");
    });
    addDispose(t.cancel);
  }

  @override
  void dispose() {
    super.dispose();
    print("MainViewModel dispose $hashCode");
  }
}
