import 'package:flutter/material.dart';

bool questionVisibilityHasScope(
  String visibility,
  String? departmentId,
  String? teamId,
) =>
    (visibility != 'department' || departmentId != null) &&
    (visibility != 'team' || teamId != null);

class QuestionVisibilityField extends StatelessWidget {
  const QuestionVisibilityField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey('question-visibility-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Who can see this question?',
        ),
        items: [
          const DropdownMenuItem(
            value: 'organisation',
            child: Text('Organisation'),
          ),
          const DropdownMenuItem(
            value: 'department',
            child: Text('Selected department only'),
          ),
          const DropdownMenuItem(
            value: 'team',
            child: Text('Selected team only'),
          ),
          if (value == 'private')
            const DropdownMenuItem(value: 'private', child: Text('Private')),
        ],
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
      const SizedBox(height: 8),
      Text(switch (value) {
        'department' =>
          'Choose your department below. Only its members can read this question, answers and comments. Changing the department changes the audience.',
        'team' =>
          'Choose a team you belong to below. Only its current members can read this question, answers and comments. Changing the team changes the audience.',
        'private' => 'Only the question author can read this question.',
        _ =>
          'All organisation members can read this question. Assignment controls who handles it.',
      }),
    ],
  );
}
