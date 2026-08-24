import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

class DraftViewModel with ViewModel {
  DraftViewModel(this.documentId);

  final String documentId;
  String title = '';

  void updateTitle(String value) => update(() => title = value);
}

/// The explicit key lets bindings on different pages resolve the same instance.
///
/// `aliveForever` remains false, so the instance is automatically reclaimed
/// after the final page unbinds. The document ID identifies the shared scope
/// and prevents concurrent edits of different documents from sharing state.
final draftViewModelSpec = ViewModelSpec.arg<DraftViewModel, String>(
  builder: DraftViewModel.new,
  key: (documentId) => ('draft', documentId),
);

class PageA extends StatefulWidget {
  const PageA({required this.documentId, super.key});

  final String documentId;

  @override
  State<PageA> createState() => _PageAState();
}

class _PageAState extends State<PageA> with ViewModelStateMixin<PageA> {
  DraftViewModel get draft =>
      viewModelBinding.watch(draftViewModelSpec(widget.documentId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: Column(
        children: [
          Text(draft.title),
          FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PageB(documentId: widget.documentId),
              ),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class PageB extends StatefulWidget {
  const PageB({required this.documentId, super.key});

  final String documentId;

  @override
  State<PageB> createState() => _PageBState();
}

class _PageBState extends State<PageB> with ViewModelStateMixin<PageB> {
  /// Use `read` instead if this page only writes and never reacts to VM
  /// updates.
  DraftViewModel get draft =>
      viewModelBinding.watch(draftViewModelSpec(widget.documentId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit')),
      body: TextFormField(
        initialValue: draft.title,
        onChanged: draft.updateTitle,
      ),
    );
  }
}
