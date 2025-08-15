import 'package:flutter_test/flutter_test.dart';

/// Data model for ViewModel information
class ViewModelInfo {
  final String id;
  final String type;
  final String? key;
  final String? tag;
  final bool isActive;
  final DateTime createdAt;
  final List<String> watchers;

  ViewModelInfo({
    required this.id,
    required this.type,
    this.key,
    this.tag,
    required this.isActive,
    required this.createdAt,
    required this.watchers,
  });
}

/// Data model for dependency statistics
class DependencyStats {
  final int totalInstances;
  final int activeInstances;
  final int sharedInstances;
  final int orphanedInstances;

  DependencyStats({
    required this.totalInstances,
    required this.activeInstances,
    required this.sharedInstances,
    required this.orphanedInstances,
  });
}

/// Mock data for testing ViewModelScreen
class MockViewModelData {
  static List<ViewModelInfo> getMockViewModels() {
    return [
      ViewModelInfo(
        id: 'vm_1',
        type: 'CounterViewModel',
        key: 'counter_main',
        tag: 'main_screen',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        watchers: ['Widget_1', 'Widget_2'],
      ),
      ViewModelInfo(
        id: 'vm_2',
        type: 'UserViewModel',
        key: null,
        tag: 'profile',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        watchers: ['ProfileWidget'],
      ),
      ViewModelInfo(
        id: 'vm_3',
        type: 'TodoViewModel',
        key: 'todo_list',
        tag: null,
        isActive: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        watchers: [],
      ),
    ];
  }

  static DependencyStats getMockStats(List<ViewModelInfo> viewModels) {
    return DependencyStats(
      totalInstances: viewModels.length,
      activeInstances: viewModels.where((vm) => vm.isActive).length,
      sharedInstances: viewModels.where((vm) => vm.watchers.length > 1).length,
      orphanedInstances: viewModels.where((vm) => vm.watchers.isEmpty).length,
    );
  }
}

void main() {
  group('ViewModelScreen Tests', () {
    test('Mock data should have correct structure', () {
      final mockData = MockViewModelData.getMockViewModels();
      expect(mockData.length, 3);
      expect(mockData[0].type, 'CounterViewModel');
      expect(mockData[0].watchers.length, 2);
      expect(mockData[2].watchers.isEmpty, true);
    });

    test('Mock stats should calculate correctly', () {
      final mockData = MockViewModelData.getMockViewModels();
      final stats = MockViewModelData.getMockStats(mockData);
      expect(stats.totalInstances, 3);
      expect(stats.activeInstances, 2);
      expect(stats.sharedInstances, 1);
      expect(stats.orphanedInstances, 1);
    });
  });
}
