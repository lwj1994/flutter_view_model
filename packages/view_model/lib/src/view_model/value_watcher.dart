import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:view_model/view_model.dart';

/// Rebuilds from one strongly typed value selected from a [StateViewModel].
///
/// Use a Dart record when several fields should form one update boundary. One
/// state transition then invokes at most one selector listener and schedules
/// at most one rebuild for this widget.
///
/// Example:
/// ```dart
/// StateViewModelSelector<UserState, ({String name, int age})>(
///   viewModel: viewModel,
///   selector: (state) => (name: state.name, age: state.age),
///   builder: (context, value) => Text('${value.name}: ${value.age}'),
/// )
/// ```
class StateViewModelSelector<T, R> extends StatefulWidget {
  /// The ViewModel whose state is observed.
  final StateViewModel<T> viewModel;

  /// Selects the typed value used by [builder].
  final R Function(T state) selector;

  /// Optional equality function for selected values. Defaults to `==`.
  final bool Function(R previous, R current)? equals;

  /// Builds the widget from the latest selected value.
  final Widget Function(BuildContext context, R value) builder;

  const StateViewModelSelector({
    required this.viewModel,
    required this.selector,
    required this.builder,
    this.equals,
    super.key,
  });

  @override
  State<StateViewModelSelector<T, R>> createState() =>
      _StateViewModelSelectorState<T, R>();
}

class _StateViewModelSelectorState<T, R>
    extends State<StateViewModelSelector<T, R>> {
  Function()? _unsubscribe;
  late R _selected;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selector(widget.viewModel.state);
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant StateViewModelSelector<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unsubscribe?.call();
    _selected = widget.selector(widget.viewModel.state);
    _subscribe();
  }

  void _subscribe() {
    void onChanged(R? _, R current) {
      _selected = current;
      _scheduleRebuild();
    }

    final equals = widget.equals;
    _unsubscribe = equals == null
        ? widget.viewModel.listenStateSelect<R>(
            selector: widget.selector,
            onChanged: onChanged,
          )
        : widget.viewModel.listenStateSelectWithEquals<R>(
            selector: widget.selector,
            equals: equals,
            onChanged: onChanged,
          );
  }

  void _scheduleRebuild() {
    if (_disposed || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _selected);

  @override
  void dispose() {
    _disposed = true;
    _unsubscribe?.call();
    _unsubscribe = null;
    super.dispose();
  }
}

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
