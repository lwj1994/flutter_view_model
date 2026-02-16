import 'package:view_model/view_model.dart';

class UserState {
  final String name;
  final int age;
  const UserState({this.name = 'Guest', this.age = 0});

  UserState copyWith({String? name, int? age}) {
    return UserState(
      name: name ?? this.name,
      age: age ?? this.age,
    );
  }
}

class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: const UserState());

  void updateName(String newName) {
    setState(state.copyWith(name: newName));
  }
}

final userSpec = ViewModelSpec<UserViewModel>(
  builder: () => UserViewModel(),
);

// Advanced listening in a Binding Host
class AnalyticsTracker with ViewModelBinding {
  void init() {
    // Selective listening: only fires when 'name' changes
    viewModelBinding.listenStateSelect(
      userSpec,
      selector: (state) => state.name,
      onChanged: (prev, curr) {
        print('User name changed from $prev to $curr');
      },
    );
  }
}
