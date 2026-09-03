import 'package:flutter/material.dart';

void main() {
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'view_model runtime benchmark\n\n'
              '请通过 integration_test/runtime_benchmark_test.dart 运行。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
