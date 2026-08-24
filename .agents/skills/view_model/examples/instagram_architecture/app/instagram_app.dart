import 'dart:async';

import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

import '../core/load_phase.dart';
import '../feed/post_feed_page.dart';
import 'init_view_model.dart';

class InstagramApp extends StatefulWidget {
  const InstagramApp({required this.currentUserId, super.key});

  final String currentUserId;

  @override
  State<InstagramApp> createState() => _InstagramAppState();
}

class _InstagramAppState extends State<InstagramApp>
    with ViewModelStateMixin<InstagramApp> {
  InitViewModel get init =>
      viewModelBinding.watch(initViewModelSpec(widget.currentUserId));

  @override
  void initState() {
    super.initState();
    unawaited(init.initialize());
  }

  @override
  Widget build(BuildContext context) {
    final initState = init.state;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [ViewModel.routeObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: switch (initState.phase) {
        LoadPhase.ready => PostFeedPage(userId: widget.currentUserId),
        LoadPhase.failure => _StartupFailure(
            error: initState.error,
            retry: init.initialize,
          ),
        LoadPhase.idle || LoadPhase.loading => const _StartupLoading(),
      },
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error, required this.retry});

  final Object? error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Startup failed: $error'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(retry()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
