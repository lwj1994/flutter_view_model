import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

import 'app/instagram_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ViewModel.initialize();
  runApp(const InstagramApp(currentUserId: 'user-milu'));
}
