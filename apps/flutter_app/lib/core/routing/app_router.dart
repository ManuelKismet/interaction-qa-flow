import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/routing/session_deep_link.dart';
import 'package:int_qa_flow/features/admin/presentation/admin_page.dart';
import 'package:int_qa_flow/features/ask/presentation/ask_page.dart';
import 'package:int_qa_flow/features/governance/presentation/review_queue_page.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_page.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_session_page.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';
import 'package:int_qa_flow/features/questions/presentation/question_detail_page.dart';
import 'package:int_qa_flow/features/questions/presentation/questions_page.dart';
import 'package:int_qa_flow/shared/widgets/app_shell.dart';

final appRouterProvider = Provider.autoDispose.family<GoRouter, String>((
  ref,
  _,
) {
  final router = GoRouter(
    initialLocation: sessionDeepLinkInitialLocation(Uri.base),
    overridePlatformDefaultLocation: true,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const AskPage()),
          GoRoute(
            path: '/questions',
            builder: (context, state) => const QuestionsPage(),
          ),
          GoRoute(
            path: '/questions/:questionId',
            builder: (context, state) => QuestionDetailPage(
              questionId: state.pathParameters['questionId']!,
            ),
          ),
          GoRoute(
            path: '/guided',
            builder: (context, state) => const GuidedPage(),
          ),
          GoRoute(
            path: '/guided/sessions/:sessionId',
            builder: (context, state) => GuidedSessionPage(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: '/review-queue',
            builder: (context, state) => const ReviewQueuePage(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminPage(),
          ),
          GoRoute(
            path: '/guest/groups',
            builder: (context, state) {
              final extra = state.extra;
              final entry = extra is Map ? extra : const {};
              return SharedGuestGroupsPage(
                initialGroupId: entry['groupId'] as String?,
                initialEntryId: entry['entryId'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/personal',
            builder: (context, state) => GuestWorkspacePage(
              firebaseReady: true,
              personalWorkspaceEnabled: true,
              membershipStatus: AccountMembershipStatus.active,
              initialKnowledgeItemId: state.extra is Map
                  ? (state.extra as Map)['knowledgeItemId'] as String?
                  : null,
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});