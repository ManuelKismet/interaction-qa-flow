# Firebase backend security review — 2026-10-02

Scope: PR #4 at 862ecef2c9716510cec5f1e68d61ffb0b9f60838.
Source review and independent synthetic ASGI/SQLite checks in a detached
Codespace worktree; no hosted database changes, IAM grants, merge or deployment.

## Evidence

- Nine existing Firebase auth/security tests passed independently.
- An additional guard probe exercised every documented /api/v1 operation:
  all 81 returned HTTP 401 without identity. Organisation bootstrap remains
  unregistered. Health and API documentation are outside that protected group.
- Sampled boundary checks: another tenant's question ID returned 404; a forged
  organisation parameter returned 403; employee department creation returned 403.
- Real identity dependencies and Firebase UID membership resolution were used;
  cryptographic token verification was mocked. These checks do not validate
  real signed tokens, hosted ADC, PostgreSQL constraints or every business action.
- Combined result: 11 passed (9 security cases plus 2 observation probes),
  with one harmless pytest cache-path warning. Passing observation assertions
  confirm the defects below; they are not successful privacy acceptance.

## Findings

| Finding | Evidence | Required acceptance |
| --- | --- | --- |
| IQ-03, P1: Knowledge actor visibility remains missing | Private employee question detail, list and answer listing return 200 to unrelated same-tenant people_owner; that actor can add a comment (201). QuestionService.get/list and AnswerService/CommentService paths use tenant scope without actor visibility. | Apply one actor visibility policy to detail/list, aliases/canonical metadata, answers, comments and related actions; deny private and wrong-department access with regression tests. |
| IQ-04, P1: null department still authorizes Interact access | Department-visible session with no department is created (201); unrelated departmentless actor reads it (200). GuidedService._require_view still permits null == null. | Require a valid tenant-scoped department for department visibility; reject null equality across list/detail/report/export paths. |
| IQ-05, P2: private-session policy discrepancy remains | Tenant admin reads another owner's private Interact session (200); source also permits admin mutations while architecture promises owner-only. | Founder must decide owner-only versus owner-plus-admin, then align disclosure, authorization and tests. |
| Runtime configuration dependency: revocation checks require Auth user read | dependencies.verify_id_token sets check_revoked=True; installed Firebase SDK calls get_user. The approved API account currently has Cloud SQL Client and one-secret access only. | Before hosted sign-in, review the minimal firebaseauth.users.get permission and verify ADC/revocation under the intended runtime identity. No access grant was added during this review. |

The runtime-permission finding is an inference from the installed SDK's call
and the independently verified account grants, not a live hosted failure.
Reference: https://firebase.google.com/docs/auth/admin/manage-sessions and
https://firebase.google.com/docs/projects/iam/permissions.

Identity protections improved: SDK signature/expiry verification, explicit
audience/issuer checks, unique UID mapping, active database membership,
legacy-header rejection and server-derived tenant/role. App Check is an
independent dependency and observation explicitly admits missing tokens.
These improvements do not close IQ-03/IQ-04 or constitute release approval.

## Reproduce

Use the reviewed commit and a separate Python environment with its backend
requirements installed. From backend, with PYTHONPATH set to that directory:

```sh
EMBEDDING_PROVIDER=fake python -m pytest -q -s -p no:cacheprovider   tests/test_firebase_auth.py   /workspaces/intqaflow/docs/operations/review-probes/backend_security_observations.py
```

The probes use only disposable in-memory synthetic fixtures and make no
Firebase/cloud calls. Convert defect-observation assertions to deny-access
acceptance tests when implementing fixes.

Flutter blockers are recorded separately in firebase-flutter-validation.md.
The existing embedding/provider proposal failure (IQ-07), other original audit
findings and hosted end-to-end checks remain outstanding. Full authorization
coverage and Firebase revocation under real service credentials remain pending.
