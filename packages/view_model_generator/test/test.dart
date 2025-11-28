import 'package:source_gen_test/source_gen_test.dart';
import 'package:view_model_annotation/view_model_annotation.dart';
import 'package:view_model_generator/src/provider_generator.dart';

// 1. Test no-args constructor
@ShouldGenerate(r'''
final noArgsProvider = ViewModelProvider<NoArgs>(builder: () => NoArgs());
''')
@genProvider
class NoArgs {
  NoArgs();
}

// 2. Test constructor with args (ensure fix works: String? name -> String name)
@ShouldGenerate(r'''
final oneArgProvider = ViewModelProvider.arg<OneArg, String>(
  builder: (String name) => OneArg(name),
);
''')
@genProvider
class OneArg {
  final String name;

  OneArg(this.name);
}

// 3. Test named args (verify isRequiredNamed logic)
@ShouldGenerate(r'''
final namedArgProvider = ViewModelProvider.arg<NamedArg, int>(
  builder: (int id) => NamedArg(id: id),
);
''')
@genProvider
class NamedArg {
  final int id;

  NamedArg({required this.id});
}

// 4. Test ignoring named constructors, only take main constructor (verify unnamedConstructor fix)
@ShouldGenerate(r'''
final mainCtorProvider = ViewModelProvider<MainCtor>(builder: () => MainCtor());
''')
@genProvider
class MainCtor {
  MainCtor(); // Main constructor

  MainCtor.other(); // Named constructor, should be ignored
}

@ShouldGenerate(r'''
final vmWithArg2Provider = ViewModelProvider.arg2<VmWithArg2, String, int>(
  builder: (String name, int age) => VmWithArg2(name, age),
);
''')
@genProvider
class VmWithArg2 {
  final String name;
  final int age;

  VmWithArg2(this.name, this.age); // Main constructor
}

// 6. Test ignoring super parameters: only recognize class-owned params
@ShouldGenerate(r'''
final postProvider = ViewModelProvider.arg<PostViewModel, String>(
  builder: (String args) => PostViewModel(args: args),
);
''')
@genProvider
class PostViewModel extends _BaseVM {
  final String args;
  PostViewModel({required super.state, required this.args});
}

class _BaseVM {
  final int state;
  _BaseVM({required this.state});
}

Future<void> main() async {
  // 1. Get reader, read all files under test/src
  final reader = await initializeLibraryReaderForDirectory(
    'test',
    'test.dart', // Specify the input file just written
  );

  // 2. Run tests
  initializeBuildLogTracking();

  testAnnotatedElements<GenProvider>(
    reader,
    ViewModelProviderGenerator(), // Instantiate your Generator
  );
}
