# Organisation improvements — deferred proposal, 2026-10-06

## Superseding founder authorisation — 2026-10-07

After confirmed unified Ask/search rollout f662a6c, founder reviewed all nine
agreed organisation improvements and instructed "Action" at09:26BST.
The nine-point scope below is now authorised for implementation; prior
search-first deferral is historical and no longer blocks this scope.
Copilot owns application/test/migration code; Codex applies unchanged artifacts,
independently reviews/tests, and manages configuration/docs and gated DEV-only
rollout. No production, merge, live purge/downgrade, security weakening or new
permissions are authorised. No real live owner/admin appointments are made
merely by this implementation instruction; provisioning follows reviewed workflow.
Real semantic embeddings/provider billing explicitly deferred until first customer;
keep fake-provider DEV. Personal import E2E/F04/F08/F09 remain separate.
Baseline f662a6cff70526f287fb521bea25ec24860d8f4a on
fix/unified-search-dev-20261006; schema0014. New separate organisation task,
not old PR13 or completed PR19/20 continuation. Reject quarantined old output.
Task provenance and independent results will be recorded here.

## Priority and authorisation

Founder instructed: complete only the search work already sent to Copilot, verify
it and push to development first. Organisation implementation must wait for the
founder's explicit instruction after search is confirmed working. Do not send
these changes to Copilot or include them in the search rollout.

## Agreed findings for later implementation

1. My organisation view: organisation, primary department, Teams, role and who
   manages assignments; clear not-assigned and no-organisation states.
2. Organisation owner: backend operations provisions the initial owner; ordinary
   registration never grants ownership. Owner appoints admins.
3. Delegated admins: owner grants explicit permissions for Team creation,
   membership management, reviews and answer approvals, with department/Team or
   organisation-wide scopes. Admin title alone grants no unassigned powers.
4. Team management: authorised admins create Teams and add/remove members already
   belonging to the same organisation. Teams may span departments.
5. Join requests: organisation members request Team membership or a department
   change. An authorised admin approves/declines; pending requests grant no access.
6. Knowledge boundaries: Team membership respects existing visibility policy.
   Personal Groups remain separate; organisation policy governs sharing into them.
7. Existing question/answer authorship and protected-content change requests stay
   intact and separate from organisation ownership and delegated administration.
8. Audit appointments, delegation/revocation, memberships, join-request decisions
   and approvals. Owners can revoke delegations.
9. Safe transition: preserve current full admin authority under the owner model,
   protect the last active owner and reuse existing department answer-owner
   permissions rather than create overlapping authority.

Team creation requires delegated permission; join requests ARE included in this
proposal. They were incorrectly marked deferred in an earlier conversational
draft and that was corrected. The entire organisation proposal is now deferred
only because the founder chose search first.

Current implementation remains admin-managed department/Team assignments and
admin-only Team creation/membership management; no owner/delegated-admin or
join-request implementation is claimed.

See [active search checkpoint](unified-knowledge-search-checkpoint-2026-10-06.md)
and [current development checkpoint](README.md).
