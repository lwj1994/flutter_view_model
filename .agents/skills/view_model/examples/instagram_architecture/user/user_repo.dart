import 'package:view_model/view_model.dart';

import '../core/instagram_api.dart';
import '../models/user.dart';

final userRepoSpec = ViewModelSpec<UserRepo>(
  builder: UserRepo.new,
  key: 'instagram.user-repo',
);

class UserRepo with ViewModel {
  InstagramApi get api => viewModelBinding.read(instagramApiSpec);

  Future<User> getUser(String userId) => api.fetchUser(userId);
}
