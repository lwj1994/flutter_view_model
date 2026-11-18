import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/view_model.dart';

/// A shared ViewModel read by every cell of a long list, whose dependencies
/// mirror every cell as an owner. Owner propagation must stay linear per
/// owner change, otherwise building or unmounting such a list hangs.
class _Chain with ViewModel {
  _Chain(this.name, this.next, this.disposed) {
    if (next != null) viewModelBinding.read(next!);
  }

  final String name;
  final ViewModelFactory<_Chain>? next;
  final List<String> disposed;

  @override
  void onDispose(InstanceArg arg) {
    disposed.add(name);
    super.onDispose(arg);
  }
}

class _Cell extends ViewModelBinding {
  _Cell(this.spec);
  final ViewModelFactory<_Chain> spec;
  _Chain get vm => read(spec);
}

InstanceHandle<_Chain> _handle(String key) =>
    instanceManager.getNotifier<_Chain>(
      factory: InstanceFactory(arg: InstanceArg(key: key)),
    );

void main() {
  final disposed = <String>[];
  setUp(() {
    ViewModel.reset();
    disposed.clear();
  });
  tearDown(ViewModel.reset);

  ViewModelFactory<_Chain> chain(int depth) {
    ViewModelFactory<_Chain>? next;
    for (var level = depth - 1; level >= 0; level--) {
      final below = next;
      next = ViewModelSpec<_Chain>(
        builder: () => _Chain('level$level', below, disposed),
        key: 'level$level',
      );
    }
    return next!;
  }

  test('thousands of owners propagate to dependencies in linear time', () {
    const owners = 1500;
    const depth = 4;
    final spec = chain(depth);
    final cells = [for (var i = 0; i < owners; i++) _Cell(spec)];

    final watch = Stopwatch()..start();
    for (final cell in cells) {
      cell.vm;
    }
    final bound = watch.elapsed;

    for (var level = 0; level < depth; level++) {
      // Deeper levels are also owned by the parent's dependency binding.
      final handle = _handle('level$level');
      expect(handle.bindingIds, hasLength(owners + (level == 0 ? 0 : 1)),
          reason: 'level$level');
      expect(handle.instance.refHandler.externalOwners, hasLength(owners));
    }

    // Unmount in the order a list unmounts its cells.
    watch.reset();
    for (final cell in cells) {
      cell.dispose();
    }
    final released = watch.elapsed;

    expect(disposed, ['level0', 'level1', 'level2', 'level3']);
    // Quadratic owner sync took about a minute here. Debug mode still pays
    // O(owners) per change for the DevTools snapshot, so the bound is loose;
    // release builds take milliseconds.
    expect(bound + released, lessThan(const Duration(seconds: 5)),
        reason: 'bind $bound, release $released');
  });

  test('releasing owners from the middle keeps the remaining propagation', () {
    const owners = 200;
    final spec = chain(3);
    final cells = [for (var i = 0; i < owners; i++) _Cell(spec)];
    for (final cell in cells) {
      cell.vm;
    }

    for (var i = 0; i < owners; i += 2) {
      cells[i].dispose();
    }
    final kept = [for (var i = 1; i < owners; i += 2) cells[i].id];
    final cellIds = {for (final cell in cells) cell.id};
    for (var level = 0; level < 3; level++) {
      final handle = _handle('level$level');
      expect(handle.bindingIds.where(cellIds.contains), kept,
          reason: 'level$level');
      expect(
        handle.instance.refHandler.externalOwners.map((owner) => owner.id),
        kept,
      );
    }
    expect(disposed, isEmpty);

    for (var i = 1; i < owners; i += 2) {
      cells[i].dispose();
    }
    expect(disposed, ['level0', 'level1', 'level2']);
  });
}
