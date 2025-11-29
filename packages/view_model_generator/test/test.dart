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

// 7. StateViewModel special case: auto compute state via fromArgs
@ShouldGenerate(r'''
final feedProvider =
    ViewModelProvider.arg3<FeedViewModel, FeedState, Repository, int>(
      builder: (FeedState state, Repository repo, int page) =>
          FeedViewModel(state: state, repo: repo, page: page),
    );
''')
@genProvider
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
final aProvider = ViewModelProvider.arg<A, P>(
  builder: (P p) => A.provider(p: p),
);
''')
@genProvider
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
final bProvider = ViewModelProvider.arg<B, P>(
  builder: (P p) => B(p: p),
  key: (P p) => 'kp-$p',
  tag: (P p) => 'tg-$p',
);
''')
@GenProvider(key: r'kp-$p', tag: r'tg-$p')
class B {
  final P p;
  B({required this.p});
}

// 10. key/tag templates with nested interpolation
@ShouldGenerate(r'''
final b2Provider = ViewModelProvider.arg<B2, P>(
  builder: (P p) => B2(p: p),
  key: (P p) => '${p.id}',
  tag: (P p) => '${p.name}',
);
''')
@GenProvider(key: r'${p.id}', tag: r'${p.name}')
class B2 {
  final P p;
  B2({required this.p});
}

// (removed duplicate B3 block; see test 11 below)

@ShouldGenerate(r'''
final feedVM2Provider =
    ViewModelProvider.arg3<FeedVM2, FeedState, Repository, int>(
      builder: (FeedState state, Repository repo, int page) =>
          FeedVM2(state: state, repo: repo, page: page),
    );
''')
@genProvider
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
    'test.dart', // Specify the input file just written
  );

  // 2. Run tests
  initializeBuildLogTracking();

  testAnnotatedElements<GenProvider>(
    reader,
    ViewModelProviderGenerator(), // Instantiate your Generator
  );
}

// 11. key const Object + tag with interpolation for arg builder
@ShouldGenerate(r'''
final b3Provider = ViewModelProvider.arg<B3, P>(
  builder: (P p) => B3(p: p),
  key: (P p) => Object(),
  tag: (P p) => '${p.name}',
);
''')
@GenProvider(key: Object(), tag: r'${p.name}')
class B3 {
  final P p;
  B3({required this.p});
}

// 12. tag constant Object for single-arg builder
@ShouldGenerate(r'''
final cProvider = ViewModelProvider.arg<C, P>(
  builder: (P p) => C(p: p),
  tag: (P p) => Object(),
);
''')
@GenProvider(tag: Object())
class C {
  final P p;
  C({required this.p});
}

// 13. key closure + tag constant Object
@ShouldGenerate(r'''
final dProvider = ViewModelProvider.arg<D, P>(
  builder: (P p) => D(p: p),
  key: (P p) => '${p.id}',
  tag: (P p) => Object(),
);
''')
@GenProvider(key: r'${p.id}', tag: Object())
class D {
  final P p;
  D({required this.p});
}

// 14. no-arg provider with constant key/tag
@ShouldGenerate(r'''
final eProvider = ViewModelProvider<E>(
  builder: () => E(),
  key: 'fixed',
  tag: Object(),
);
''')
@GenProvider(key: 'fixed', tag: Object())
class E {
  E();
}

// 15. arg2 provider, constant tag
@ShouldGenerate(r'''
final fProvider = ViewModelProvider.arg2<F, P, int>(
  builder: (P p, int n) => F(p, n),
  tag: (P p, int n) => Object(),
);
''')
@GenProvider(tag: Object())
class F {
  final P p;
  final int n;
  F(this.p, this.n);
}

// 16. Expr for expression unwrapping to non-string
@ShouldGenerate(r'''
final gProvider = ViewModelProvider.arg<G, Repository>(
  builder: (Repository repo) => G(repo: repo),
  key: (Repository repo) => repo,
  tag: (Repository repo) => repo.id,
);
''')
@GenProvider(key: Expression('repo'), tag: Expression('repo.id'))
class G {
  final Repository repo;
  G({required this.repo});
}

// 17. Mixed: string literal for key/tag, no Expr needed
@ShouldGenerate(r'''
final hProvider = ViewModelProvider.arg<H, P>(
  builder: (P p) => H(p: p),
  key: (P p) => '${p.id}',
  tag: (P p) => 'user_key',
);
''')
@GenProvider(key: r'${p.id}', tag: 'user_key')
class H {
  final P p;
  H({required this.p});
}

// 18. arg2 with Expr for id/page
@ShouldGenerate(r'''
final i2Provider = ViewModelProvider.arg2<I2, String, int>(
  builder: (String id, int page) => I2(id, page),
  key: (String id, int page) => id,
  tag: (String id, int page) => page,
);
''')
@GenProvider(key: Expression('id'), tag: Expression('page'))
class I2 {
  final String id;
  final int page;
  I2(this.id, this.page);
}

// 19. constants: number/bool
@ShouldGenerate(r'''
final kProvider = ViewModelProvider.arg<K, P>(
  builder: (P p) => K(p: p),
  key: (P p) => 123,
  tag: (P p) => true,
);
''')
@GenProvider(key: 123, tag: true)
class K {
  final P p;
  K({required this.p});
}

// 20. null tag
@ShouldGenerate(r'''
final nProvider = ViewModelProvider.arg<N, P>(
  builder: (P p) => N(p: p),
  tag: (P p) => null,
);
''')
@GenProvider(tag: null)
class N {
  final P p;
  N({required this.p});
}

// 21. complex Expr method call
@ShouldGenerate(r'''
final mProvider = ViewModelProvider.arg2<M, Repository, int>(
  builder: (Repository repo, int page) => M(repo: repo, page: page),
  key: (Repository repo, int page) => repo.compute(page),
  tag: (Repository repo, int page) => 'ok',
);
''')
@GenProvider(key: Expression('repo.compute(page)'), tag: 'ok')
class M {
  final Repository repo;
  final int page;
  M({required this.repo, required this.page});
}
