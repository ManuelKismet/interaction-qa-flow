# Organisation improvements — deferred proposal, 2026-10-06

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
