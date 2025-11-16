import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/view_model.dart';

/// A widget that listens to a [StateViewModel] and rebuilds itself when the
/// selected parts of the state change.
///
/// This widget is typically used with a [StateViewModel] obtained
/// via `readViewModel`.
///
/// [StateViewModelValueWatcher] is useful for rebuilding a small part of the
/// UI in response
/// to state changes, without rebuilding the entire widget tree.
///
/// It takes a [viewModel], a list of [selectors], and a [builder].
/// The [selectors] are functions that extract values from the view model's
/// state.
/// The [builder] is called whenever any of the selected values change.
///
/// Example:
/// ```dart
/// final myViewModel = readViewModel<MyViewModel>(factory:
///                                                 MyViewModelFactory());
///
/// StateViewModelValueWatcher<MyState>(
///   viewModel: myViewModel,
///   selectors: [(state) => state.name, (state) => state.age],
///   builder: (state) {
///     return Text('Name: ${state.name}, Age: ${state.age}');
///   },
/// )
/// ```
class StateViewModelValueWatcher<T> extends StatefulWidget {
  final List<dynamic Function(T state)> selectors;
  final Widget Function(T state) builder;
  final StateViewModel<T> viewModel;

  const StateViewModelValueWatcher({
    required this.selectors,
    required this.builder,
    required this.viewModel,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _State<T>();
  }
}

class _State<T> extends State<StateViewModelValueWatcher<T>> {
  final List<Function()> _disposes = [];
  bool _dispose = false;
  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _rebuildState() {
    if (_dispose) return;
    if (context.mounted &&
        SchedulerBinding.instance.schedulerPhase !=
            SchedulerPhase.persistentCallbacks) {
      setState(() {});
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_dispose && context.mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant StateViewModelValueWatcher<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unsubscribe();
    _subscribe();
  }

  void _subscribe() {
    for (final selector in widget.selectors) {
      _disposes.add(
        widget.viewModel.listenStateSelect(
          selector: selector,
          onChanged: (dynamic previous, dynamic current) {
            _rebuildState();
          },
        ),
      );
    }
  }

  void _unsubscribe() {
    for (final dispose in _disposes) {
      dispose();
    }
    _disposes.clear();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.viewModel.state);
  }

  @override
  void dispose() {
    _dispose = true;
    _unsubscribe();
    super.dispose();
  }
}
