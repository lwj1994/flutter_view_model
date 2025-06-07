class CounterState {
  final int count;
  final int incrementBy;

  const CounterState({
    this.count = 0,
    this.incrementBy = 1,
  });

  CounterState copyWith({
    int? count,
    int? incrementBy,
  }) {
    return CounterState(
      count: count ?? this.count,
      incrementBy: incrementBy ?? this.incrementBy,
    );
  }
}
