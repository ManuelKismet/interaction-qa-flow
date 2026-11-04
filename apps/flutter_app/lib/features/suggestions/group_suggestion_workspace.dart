import 'package:flutter/material.dart';
import 'package:int_qa_flow/features/suggestions/suggestion_bank_page.dart';

/// Uses the existing account-scoped Group dialog lifecycle, without a second
/// browser router, authentication owner or organisation membership dependency.
class GroupSuggestionWorkspace extends StatefulWidget {
  const GroupSuggestionWorkspace({required this.groupId, super.key});
  final String groupId;
  @override
  State<GroupSuggestionWorkspace> createState() =>
      _GroupSuggestionWorkspaceState();
}

class _GroupSuggestionWorkspaceState extends State<GroupSuggestionWorkspace> {
  String? selectedId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Group Suggestion Bank'),
      leading: IconButton(
        tooltip: 'Back to Group',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (selectedId != null) {
            setState(() => selectedId = null);
          } else {
            Navigator.pop(context);
          }
        },
      ),
    ),
    body: SuggestionBankPage(
      key: ValueKey(selectedId),
      realm: 'group',
      initialScopeId: widget.groupId,
      suggestionId: selectedId,
      onOpenSuggestion: (id) => setState(() => selectedId = id),
      onOpenGroupEntry: (groupId, entryId) {
        if (mounted) {
          Navigator.pop(context, {'groupId': groupId, 'entryId': entryId});
        }
      },
    ),
  );
}
