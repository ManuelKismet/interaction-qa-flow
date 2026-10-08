import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';
import 'package:int_qa_flow/features/knowledge/presentation/unified_search_results.dart';

void main() {
  testWidgets('filters Knowledge and Interact while retaining match navigation IDs', (tester) async {
    const knowledge = AskKnowledgeHit(id:'knowledge',title:'Approved guidance',source:'Local',attribution:[],matchMethod:'Keyword',relevance:1.5,snippet:'guidance',status:'Saved',destination:'personal');
    const interact = AskKnowledgeHit(id:'session',title:'Interview',source:'Local',attribution:[],matchMethod:'Keyword',relevance:1.5,snippet:'Nested question',status:'Session',destination:'personal',kind:'interact_session',sessionId:'session',questionId:'nested',participantId:'alice');
    AskKnowledgeHit? opened;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:UnifiedSearchResults(suggestions:const AsyncData(AskSuggestions(hasSearched:true,hits:[knowledge,interact])),onRetry:(){},onOpenLocalInteract:(hit){opened=hit;})))));
    expect(find.text('Approved guidance'), findsOneWidget);
    expect(find.text('Interview'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip,'Knowledge'));
    await tester.pump();
    expect(find.text('Approved guidance'), findsOneWidget);
    expect(find.text('Interview'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip,'Interact'));
    await tester.pump();
    expect(find.text('Approved guidance'), findsNothing);
    expect(find.text('Interview'), findsOneWidget);
    await tester.tap(find.text('Interview'));
    expect(opened?.questionId,'nested');
    expect(opened?.participantId,'alice');
    await tester.tap(find.widgetWithText(ChoiceChip,'All'));
    await tester.pump();
    expect(find.text('Approved guidance'), findsOneWidget);
    expect(find.text('Interview'), findsOneWidget);
  });
}
