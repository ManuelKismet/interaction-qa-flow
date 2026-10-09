import 'package:flutter/material.dart';
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
import 'package:int_qa_flow/features/organisation/presentation/organisation_page.dart';
import 'package:int_qa_flow/shared/widgets/app_shell.dart';
import 'package:int_qa_flow/shared/widgets/knowledge_section_tabs.dart';

final appRouterProvider = Provider.autoDispose.family<GoRouter, String>((
  ref,
  _,
) {
  final router = GoRouter(
    initialLocation: sessionDeepLinkInitialLocation(Uri.base),
    overridePlatformDefaultLocation: true,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentPath: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const AskPage()),
          GoRoute(
            path: '/organisation',
            builder: (context, state) => const OrganisationPage(),
          ),
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
              initialQuestionId: state.uri.queryParameters['questionId'],
              initialParticipantId: state.uri.queryParameters['participantId'],
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
                initialQuestionId: state.uri.queryParameters['questionId'],
                initialParticipantId:
                    state.uri.queryParameters['participantId'],
                initialGroupId:
                    state.uri.queryParameters['groupId'] ??
                    entry['groupId'] as String?,
                initialEntryId:
                    state.uri.queryParameters['entryId'] ??
                    entry['entryId'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/personal',
            builder: (context, state) => GuestWorkspacePage(
              firebaseReady: true,
              personalWorkspaceEnabled: true,
              membershipStatus: AccountMembershipStatus.active,
              initialKnowledgeItemId:
                  state.uri.queryParameters['knowledgeItemId'] ??
                  (state.extra is Map
                      ? (state.extra as Map)['knowledgeItemId'] as String?
                      : null),
              initialKnowledgeSection: KnowledgeSection.ask,
              onKnowledgeSectionChanged: (section) => context.go(
                section == KnowledgeSection.ask
                    ? '/personal/ask'
                    : '/personal/questions',
              ),
              onWorkspaceTabChanged: (index) =>
                  context.go(index == 0 ? '/personal' : '/personal/interact'),
            ),
          ),
          GoRoute(
            path: '/personal/ask',
            builder: (context, state) => GuestWorkspacePage(
              firebaseReady: true,
              personalWorkspaceEnabled: true,
              membershipStatus: AccountMembershipStatus.active,
              initialKnowledgeItemId:
                  state.uri.queryParameters['knowledgeItemId'],
              initialKnowledgeSection: KnowledgeSection.ask,
              onKnowledgeSectionChanged: (section) => context.go(
                section == KnowledgeSection.ask
                    ? '/personal/ask'
                    : '/personal/questions',
              ),
              onWorkspaceTabChanged: (index) => context.go(
                index == 0 ? '/personal/ask' : '/personal/interact',
              ),
            ),
          ),
          GoRoute(
            path: '/personal/questions',
            builder: (context, state) => GuestWorkspacePage(
              firebaseReady: true,
              personalWorkspaceEnabled: true,
              membershipStatus: AccountMembershipStatus.active,
              initialKnowledgeItemId:
                  state.uri.queryParameters['knowledgeItemId'],
              initialKnowledgeSection: KnowledgeSection.questions,
              onKnowledgeSectionChanged: (section) => context.go(
                section == KnowledgeSection.ask
                    ? '/personal/ask'
                    : '/personal/questions',
              ),
              onWorkspaceTabChanged: (index) => context.go(
                index == 0 ? '/personal/questions' : '/personal/interact',
              ),
            ),
          ),
          GoRoute(
            path: '/personal/interact',
            pageBuilder: (context, state) => _personalInteractPage(context),
          ),
          GoRoute(
            path: '/personal/interact/sessions/:sessionId',
            pageBuilder: (context, state) => _personalInteractPage(
              context,
              sessionId: state.pathParameters['sessionId'],
              questionId: state.uri.queryParameters['questionId'],
              participantId: state.uri.queryParameters['participantId'],
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// The personal Interact list and its session editor share one page key so the
/// workspace state (pending account writes, local save timers) is kept while
/// the URL switches between the list and a session.
Page<void> _personalInteractPage(
  BuildContext context, {
  String? sessionId,
  String? questionId,
  String? participantId,
}) => MaterialPage<void>(
  key: const ValueKey('personal-interact-workspace'),
  child: GuestWorkspacePage(
    firebaseReady: true,
    personalWorkspaceEnabled: true,
    membershipStatus: AccountMembershipStatus.active,
    initialWorkspaceTab: 1,
    initialSessionId: sessionId,
    initialQuestionId: questionId,
    initialParticipantId: participantId,
    onSessionRouteChanged: (id) => context.go(
      id == null
          ? '/personal/interact'
          : '/personal/interact/sessions/${Uri.encodeComponent(id)}',
    ),
    onWorkspaceTabChanged: (index) =>
        context.go(index == 0 ? '/personal' : '/personal/interact'),
  ),
);
