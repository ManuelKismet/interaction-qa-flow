import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum KnowledgeSection { ask, questions }

class KnowledgeSectionTabs extends StatelessWidget {
  const KnowledgeSectionTabs({
    required this.selected,
    this.onChanged,
    super.key,
  });

  final KnowledgeSection selected;
  final ValueChanged<KnowledgeSection>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = selected.index;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 320,
        child: DefaultTabController(
          length: KnowledgeSection.values.length,
          initialIndex: selectedIndex,
          child: TabBar(
            onTap: (index) {
              if (index == selectedIndex) return;
              final section = KnowledgeSection.values[index];
              final callback = onChanged;
              if (callback != null) {
                callback(section);
              } else {
                context.go(
                  index == KnowledgeSection.ask.index ? '/' : '/questions',
                );
              }
            },
            tabs: const [
              Tab(text: 'Ask & search'),
              Tab(text: 'Questions'),
            ],
          ),
        ),
      ),
    );
  }
}
