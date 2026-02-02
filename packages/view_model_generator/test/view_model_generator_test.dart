import 'package:source_gen_test/source_gen_test.dart';
import 'package:view_model_annotation/view_model_annotation.dart';
import 'package:view_model_generator/src/provider_generator.dart';

// 1. Test no-args constructor
@ShouldGenerate(r'''
final noArgsSpec = ViewModelSpec<NoArgs>(builder: () => NoArgs());
''')
@genSpec
class NoArgs {
  NoArgs();
}

// 2. Test constructor with args (ensure fix works: String? name -> String name)
@ShouldGenerate(r'''
final oneArgSpec = ViewModelSpec.arg<OneArg, String>(
  builder: (String name) => OneArg(name),
);
''')
@genSpec
class OneArg {
  final String name;

  OneArg(this.name);
}

// 3. Test named args (verify isRequiredNamed logic)
@ShouldGenerate(r'''
final namedArgSpec = ViewModelSpec.arg<NamedArg, int>(
  builder: (int id) => NamedArg(id: id),
);
''')
@genSpec
class NamedArg {
  final int id;

  NamedArg({required this.id});
}

// 4. Test ignoring named constructors, only take main constructor (verify unnamedConstructor fix)
@ShouldGenerate(r'''
final mainCtorSpec = ViewModelSpec<MainCtor>(builder: () => MainCtor());
''')
@genSpec
class MainCtor {
  MainCtor(); // Main constructor

  MainCtor.other(); // Named constructor, should be ignored
}

@ShouldGenerate(r'''
final vmWithArg2Spec = ViewModelSpec.arg2<VmWithArg2, String, int>(
  builder: (String name, int age) => VmWithArg2(name, age),
);
''')
@genSpec
class VmWithArg2 {
  final String name;
  final int age;

  VmWithArg2(this.name, this.age); // Main constructor
}

// 6. Test ignoring super parameters: only recognize class-owned params
@ShouldGenerate(r'''
final postSpec = ViewModelSpec.arg<PostViewModel, String>(
  builder: (String args) => PostViewModel(args: args),
);
''')
@genSpec
class PostViewModel extends _BaseVM {
  final String args;
  PostViewModel({required super.state, required this.args});
}

class _BaseVM {
  final int state;
  _BaseVM({required this.state});
}

// 7. StateViewModel special case: auto compute state via fromArgs
@ShouldGenerate(r'''
final feedSpec = ViewModelSpec.arg3<FeedViewModel, FeedState, Repository, int>(
  builder: (FeedState state, Repository repo, int page) =>
      FeedViewModel(state: state, repo: repo, page: page),
);
''')
@genSpec
class FeedViewModel extends StateViewModel<FeedState> {
  final Repository repo;
  final int page;

  FeedViewModel(
      {required FeedState state, required this.repo, required this.page})
      : super(state);
}

class StateViewModel<S> {
  final S state;
  StateViewModel(this.state);
}

class Repository {}

class FeedState {
  static FeedState fromArgs(Repository repo, int page) => FeedState();
}

// 8. Prefer factory named 'provider' when it matches main ctor (excluding super)
@ShouldGenerate(r'''
final aSpec = ViewModelSpec.arg<A, P>(builder: (P p) => A.provider(p: p));
''')
@genSpec
class A extends Base {
  final P p;
  A({required super.s, required this.p});
  factory A.provider({required P p}) => A(s: 0, p: p);
}

class Base {
  final int s;
  Base({required this.s});
}

class P {
  final String id = '';
  final String name = '';
}

// 9. key/tag templates with args
@ShouldGenerate(r'''
final bSpec = ViewModelSpec.arg<B, P>(
  builder: (P p) => B(p: p),
  key: (P p) => 'kp-$p',
  tag: (P p) => 'tg-$p',
);
''')
@GenSpec(key: r'kp-$p', tag: r'tg-$p')
class B {
  final P p;
  B({required this.p});
}

// 10. key/tag templates with nested interpolation
@ShouldGenerate(r'''
final b2Spec = ViewModelSpec.arg<B2, P>(
  builder: (P p) => B2(p: p),
  key: (P p) => '${p.id}',
  tag: (P p) => '${p.name}',
);
''')
@GenSpec(key: r'${p.id}', tag: r'${p.name}')
class B2 {
  final P p;
  B2({required this.p});
}

// (removed duplicate B3 block; see test 11 below)

@ShouldGenerate(r'''
final feedVM2Spec = ViewModelSpec.arg3<FeedVM2, FeedState, Repository, int>(
  builder: (FeedState state, Repository repo, int page) =>
      FeedVM2(state: state, repo: repo, page: page),
);
''')
@genSpec
class FeedVM2 extends StateViewModel<FeedState> {
  final Repository repo;
  final int page;

  FeedVM2({required FeedState state, required this.repo, required this.page})
      : super(state);
  factory FeedVM2.create(Repository repo, int page) =>
      FeedVM2(state: FeedState.fromArgs(repo, page), repo: repo, page: page);
}

Future<void> main() async {
  // 1. Get reader, read all files under test/src
  final reader = await initializeLibraryReaderForDirectory(
    'test',
    'view_model_generator_test.dart',
  );

  // 2. Run tests
  initializeBuildLogTracking();

  testAnnotatedElements<GenSpec>(
    reader,
    const ViewModelSpecGenerator(), // Instantiate your Generator
  );
}

// 11. key const Object + tag with interpolation for arg builder
@ShouldGenerate(r'''
final b3Spec = ViewModelSpec.arg<B3, P>(
  builder: (P p) => B3(p: p),
  key: (P p) => const Object(),
  tag: (P p) => '${p.name}',
);
''')
@GenSpec(key: const Object(), tag: r'${p.name}')
class B3 {
  final P p;
  B3({required this.p});
}

// 12. tag constant Object for single-arg builder
@ShouldGenerate(r'''
final cSpec = ViewModelSpec.arg<C, P>(
  builder: (P p) => C(p: p),
  tag: (P p) => const Object(),
);
''')
@GenSpec(tag: const Object())
class C {
  final P p;
  C({required this.p});
}

// 13. key closure + tag constant Object
@ShouldGenerate(r'''
final dSpec = ViewModelSpec.arg<D, P>(
  builder: (P p) => D(p: p),
  key: (P p) => '${p.id}',
  tag: (P p) => const Object(),
);
''')
@GenSpec(key: r'${p.id}', tag: const Object())
class D {
  final P p;
  D({required this.p});
}

// 14. no-arg provider with constant key/tag
@ShouldGenerate(r'''
final eSpec = ViewModelSpec<E>(
  builder: () => E(),
  key: 'fixed',
  tag: const Object(),
);
''')
@GenSpec(key: 'fixed', tag: const Object())
class E {
  E();
}

// 15. arg2 provider, constant tag
@ShouldGenerate(r'''
final fSpec = ViewModelSpec.arg2<F, P, int>(
  builder: (P p, int n) => F(p, n),
  tag: (P p, int n) => const Object(),
);
''')
@GenSpec(tag: const Object())
class F {
  final P p;
  final int n;
  F(this.p, this.n);
}

// 16. Expr for expression unwrapping to non-string
@ShouldGenerate(r'''
final gSpec = ViewModelSpec.arg<G, Repository>(
  builder: (Repository repo) => G(repo: repo),
  key: (Repository repo) => repo,
  tag: (Repository repo) => repo.id,
);
''')
@GenSpec(key: Expression('repo'), tag: Expression('repo.id'))
class G {
  final Repository repo;
  G({required this.repo});
}

// 17. Mixed: string literal for key/tag, no Expr needed
@ShouldGenerate(r'''
final hSpec = ViewModelSpec.arg<H, P>(
  builder: (P p) => H(p: p),
  key: (P p) => '${p.id}',
  tag: (P p) => 'user_key',
);
''')
@GenSpec(key: r'${p.id}', tag: 'user_key')
class H {
  final P p;
  H({required this.p});
}

// 18. arg2 with Expr for id/page
@ShouldGenerate(r'''
final i2Spec = ViewModelSpec.arg2<I2, String, int>(
  builder: (String id, int page) => I2(id, page),
  key: (String id, int page) => id,
  tag: (String id, int page) => page,
);
''')
@GenSpec(key: Expression('id'), tag: Expression('page'))
class I2 {
  final String id;
  final int page;
  I2(this.id, this.page);
}

// 19. constants: number/bool
@ShouldGenerate(r'''
final kSpec = ViewModelSpec.arg<K, P>(
  builder: (P p) => K(p: p),
  key: (P p) => 123,
  tag: (P p) => true,
);
''')
@GenSpec(key: 123, tag: true)
class K {
  final P p;
  K({required this.p});
}

// 20. null tag
@ShouldGenerate(r'''
final nSpec = ViewModelSpec.arg<N, P>(
  builder: (P p) => N(p: p),
  tag: (P p) => null,
);
''')
@GenSpec(tag: null)
class N {
  final P p;
  N({required this.p});
}

// 21. complex Expr method call
@ShouldGenerate(r'''
final mSpec = ViewModelSpec.arg2<M, Repository, int>(
  builder: (Repository repo, int page) => M(repo: repo, page: page),
  key: (Repository repo, int page) => repo.compute(page),
  tag: (Repository repo, int page) => 'ok',
);
''')
@GenSpec(key: Expression('repo.compute(page)'), tag: 'ok')
class M {
  final Repository repo;
  final int page;
  M({required this.repo, required this.page});
}

// 22. Singleton mode - REMOVED (deprecated)
@ShouldGenerate(r'''
final singletonVMSpec = ViewModelSpec<SingletonVM>(
  builder: () => SingletonVM(),
);
''')
@GenSpec()
class SingletonVM {
  SingletonVM();
}

// 23. Singleton mode with explicit key - REMOVED (deprecated)
@ShouldGenerate(r'''
final singletonWithKeyVMSpec = ViewModelSpec<SingletonWithKeyVM>(
  builder: () => SingletonWithKeyVM(),
  key: 'MyKey',
);
''')
@GenSpec(key: 'MyKey')
class SingletonWithKeyVM {
  SingletonWithKeyVM();
}

// 24. Singleton mode with args - REMOVED (deprecated)
@ShouldGenerate(r'''
final singletonArgVMSpec = ViewModelSpec.arg<SingletonArgVM, int>(
  builder: (int id) => SingletonArgVM(id),
);
''')
@GenSpec()
class SingletonArgVM {
  final int id;
  SingletonArgVM(this.id);
}

// 25. factory with no args (provider) should be used if present
@ShouldGenerate(r'''
final islandSpec = ViewModelSpec<IslandViewModel>(
  builder: () => IslandViewModel.provider(),
);
''')
@GenSpec()
class IslandViewModel extends StateViewModel<IslandViewModelState> {
  IslandViewModel({required IslandViewModelState state}) : super(state);

  factory IslandViewModel.provider() {
    return IslandViewModel(state: IslandViewModelState());
  }
}

class IslandViewModelState {}

@ShouldGenerate(r'''
final nullArgSpec = ViewModelSpec.arg<NullArg, int?>(
  builder: (int? id) => NullArg(id: id),
);
''')
@genSpec
class NullArg {
  final int? id;

  NullArg({required this.id});
}

@ShouldGenerate(r'''
final nullArg2Spec = ViewModelSpec.arg3<NullArg2, int?, String?, int>(
  builder: (int? id, String? name, int age) =>
      NullArg2.provider(id: id, name: name, age: age),
);
''')
@genSpec
class NullArg2 {
  final int? id;
  NullArg2({this.id});
  factory NullArg2.provider({int? id, String? name, required int age}) =>
      NullArg2(id: id);
}

// 26. aliveForever with Arg1
@ShouldGenerate(r'''
final liveForeverArg1Spec = ViewModelSpec.arg<LiveForeverArg1, int>(
  builder: (int id) => LiveForeverArg1(id),
  aliveForever: (int id) => true,
);
''')
@GenSpec(aliveForever: true)
class LiveForeverArg1 {
  final int id;
  LiveForeverArg1(this.id);
}

// 27. aliveForever with Arg2
@ShouldGenerate(r'''
final liveForeverArg2Spec = ViewModelSpec.arg2<LiveForeverArg2, int, String>(
  builder: (int id, String name) => LiveForeverArg2(id, name),
  aliveForever: (int id, String name) => true,
);
''')
@GenSpec(aliveForever: true)
class LiveForeverArg2 {
  final int id;
  final String name;
  LiveForeverArg2(this.id, this.name);
}

// 28. aliveForever with Arg3
@ShouldGenerate(r'''
final liveForeverArg3Spec =
    ViewModelSpec.arg3<LiveForeverArg3, int, String, bool>(
      builder: (int id, String name, bool active) =>
          LiveForeverArg3(id, name, active),
      aliveForever: (int id, String name, bool active) => true,
    );
''')
@GenSpec(aliveForever: true)
class LiveForeverArg3 {
  final int id;
  final String name;
  final bool active;
  LiveForeverArg3(this.id, this.name, this.active);
}

// 29. aliveForever with Arg4
@ShouldGenerate(r'''
final liveForeverArg4Spec =
    ViewModelSpec.arg4<LiveForeverArg4, int, String, bool, double>(
      builder: (int id, String name, bool active, double score) =>
          LiveForeverArg4(id, name, active, score),
      aliveForever: (int id, String name, bool active, double score) => true,
    );
''')
@GenSpec(aliveForever: true)
class LiveForeverArg4 {
  final int id;
  final String name;
  final bool active;
  final double score;
  LiveForeverArg4(this.id, this.name, this.active, this.score);
}
