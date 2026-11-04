import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';

Future<T?> showGuidedScopedDialog<T>({
  required BuildContext context,
  required GuidedRepository repository,
  required WidgetBuilder builder,
  bool Function()? isCurrent,
}) => showDialog<T>(
  context: context,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final current = ref.watch(guidedRepositoryProvider);
      ref.watch(
        authStateProvider.select((state) => (state.isLoading, state.hasError)),
      );
      ref.watch(
        currentMembershipProvider.select(
          (state) => (state.isLoading, state.hasError),
        ),
      );
      ref.watch(
        organisationProfileProvider.select(
          (state) => (state.isLoading, state.hasError),
        ),
      );
      var allowed =
          identical(current, repository) && (isCurrent?.call() ?? true);
      try {
        repository.ensureCurrent();
      } catch (_) {
        allowed = false;
      }
      if (!allowed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
        return const AlertDialog(
          title: Text('Interact access changed'),
          content: Text('Reopen this action in your current workspace.'),
        );
      }
      return builder(context);
    },
  ),
);
