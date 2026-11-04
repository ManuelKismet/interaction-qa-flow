import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

final askControllerProvider = AsyncNotifierProvider<AskController, void>(
  AskController.new,
);

class AskController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> submit({
    required String title,
    String? body,
    String? departmentId,
    String? teamId,
    String visibility = 'organisation',
  }) async {
    String? questionId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      questionId = await ref
          .read(questionsRepositoryProvider)
          .createQuestion(
            title: title,
            body: body,
            departmentId: departmentId,
            teamId: teamId,
            visibility: visibility,
          );
    });
    return state.hasError ? null : questionId;
  }
}

final departmentsProvider = FutureProvider<List<DepartmentSummary>>((ref) {
  return ref.watch(questionsRepositoryProvider).listDepartments();
});

final teamsProvider = FutureProvider<List<TeamSummary>>((ref) {
  return ref.watch(questionsRepositoryProvider).listTeams();
});

String? suggestedDepartmentForTeam(
  List<TeamSummary> teams,
  String? teamId,
  String? currentDepartmentId,
) {
  if (teamId == null) return currentDepartmentId;
  final selected = teams.where((team) => team.id == teamId).firstOrNull;
  return selected?.departmentId ?? currentDepartmentId;
}
