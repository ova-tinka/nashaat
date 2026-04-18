Use case Id: UC14    Manage Friends (CRUD)

**Brief Description**
An authenticated user manages social connections: send friend requests (search by username or invite link), accept or reject requests, view friends list with activity data, and remove friends. Connections are mutual and form the basis for private leaderboards.

**Primary actors**
Authenticated User

**Preconditions:**
1. User is authenticated.
2. Device has active internet connection.

**Post-conditions:**
- Send request: friendships record with status pending; recipient notified.
- Accept: status accepted; both on each other's lists and leaderboards.
- Reject: status rejected; no notification to sender.
- Remove: friendships record deleted; both removed from lists and leaderboards.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User goes to Friends (nav or profile). | 2. Subsystem queries friendships; displays Pending (incoming with Accept/Reject, outgoing with Cancel), Friends list (avatar, name, tier, last activity, streak), "+ Add Friend", "Share Invite Link"; count "Friends (N)". |
| 3. User selects "+ Add Friend", types name/username (min 3 chars), selects "Add Friend" next to result. | 4. Subsystem searches profiles (excludes self, existing friends); creates friendships (pending); notifies receiver; shows "Friend request sent to [Name]." |
| 5. (Or) User selects "Share Invite Link"; subsystem generates invite URL and opens share sheet; recipient taps link and accepts in app or web. | 6. Subsystem creates mutual friendship when recipient accepts; app opens "Friend Request from [Name]" or web shows install + queued request. |
| 7. User accepts or rejects incoming request. | 8. Accept: subsystem updates to accepted, adds to both lists, notifies sender, toast "You and [Name] are now friends!" Reject: subsystem updates to rejected, removes from pending; no notification. |
| 9. User opens friend profile and selects "Remove Friend", then confirms. | 10. Subsystem deletes friendships record; both removed from lists and leaderboards; toast "[Name] removed." No notification to removed friend. |
| 11. User cancels outgoing request. | 12. Subsystem deletes record; request retracted if possible; toast "Friend request to [Name] cancelled." |

**Alternative flows:**
2a. Friend's account deleted: friendship removed during account deletion (UC03); deleted user no longer appears in list.
4a. Search no results: subsystem suggests different name or share invite link.
4b. User cannot add self (filtered from results).
4c. Request already pending: "Add Friend" shows "Pending" and is disabled.
4d. Max friends (Free 25, VIP 100): subsystem prompts to remove one to add.
4e. Rejected user sends again: allowed after 30-day cooldown; subsystem shows "You can send another request in [X] days."
6a. Reciprocal requests: subsystem auto-accepts and notifies both.
6b. Invite link when already friends: subsystem shows "You're already friends!"

**Special Requirements:**
<ToDo: List the non-functional requirements: mutual friendship; Free 25 / VIP 100 friends; max 50 pending outgoing; pending expire 30 days; 30-day cooldown after reject; reciprocal auto-accept; no notification on reject/remove; search min 3 chars, case-insensitive partial; exclude self/friends/blocked; invite link per user, no expiry; remove is hard delete; leaderboards update immediately; "Last active" from latest workout log; default sort most recently active. />
