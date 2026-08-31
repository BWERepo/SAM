# SAM Project Status

**Last updated:** 2026-08-31 — **checkpoints v6.7 and v6.8**: Print Bid Sheets went from 2 single-sided pages per item to **4 pages forming 2 duplex (double-sided) sheets** — a new continuation bid-table page prints on the back of page 1, and the back of page 2 (the label page) is left blank. Also fixed a real bug along the way: the "Bid Amount" table header was silently wrapping to two lines, eating into the row-height budget and causing rows to overflow onto the next page — the row-height constant was shrunk (v6.7) to work around it, then correctly reverted back to its original page-filling value (v6.8) once the header-wrap fix and the user's own bad print-dialog scaling setting were identified as the *actual* causes. Separately, `deploy.ps1` was switched from `curl.exe` to a .NET `FtpWebRequest` because curl's Schannel TLS backend was **silently failing deploys while reporting success** against this host. **Read "Bid Sheet duplex layout & row-height saga" in open item #13 below before touching `printBiddingSheets()`'s row-height/continuation-row constants again** — the right numbers depend on each other and got revised twice in one day.

This file exists so a brand-new Claude Code session can resume this work with zero prior conversation context. Read this alongside `CLAUDE.md` (architecture/rules) before touching code.

---

## Current state (as of this doc)

- **Deployed version:** **v6.8** (`index.html` footer `#app-version`) — deployed code matches the latest checkpoint commit, no drift.
- **Git:** `main` branch, last commit `57e0e30` ("Checkpoint v6.8: Bid Sheets - revert row height to 0.40in, fix continuation page overflow"), pushed to `origin` (https://github.com/ETCCRepo/ETCCSAM.git). Working tree is clean. (`3f2bbee`, "Switch deploy.ps1 from curl to .NET FtpWebRequest", sits between v6.7 and v6.8 — a `deploy.ps1`-only commit, not a checkpoint, per the project's "commit and push" vs. "checkpoint" distinction.)
- **Regression suite (`test.html`) was updated at both checkpoints this session (v6.7, v6.8) and confirmed green by the user** before each one.
- **No uncommitted app-code work** as of this doc.
- **⚠️ `deploy.ps1` deploy mechanism changed this session — read before assuming curl-based troubleshooting advice from older sessions still applies.** It now uses `System.Net.FtpWebRequest` instead of `curl.exe`. See open item #14 below.
- **New in v6.7/v6.8:** Print Bid Sheets is now a 4-page-per-item duplex layout, not 2 single-sided pages — see open item #13 below before assuming the old 2-page-per-item mental model still holds.
- **Note on version bumping earlier in this session:** `/ETCCSAMCheckpoint v6.0` (an explicit version argument) was correctly interpreted as a requested major bump earlier in this multi-day arc. Later in that session, `/ETCCSAMCheckpoint` (no argument) was run and a major bump to v7.0 was applied by mistake — the assistant caught it, reverted to v6.3 (correct minor bump from v6.2) before committing, and no v7.0 was ever pushed or deployed. Worth knowing only because it means version history has no v7.0 gap to explain if noticed later — it never left the working tree.

### ⚠️ Open items carried into the next session

1. **The settings-password "corrupted again" investigation from several sessions ago is still not conclusively closed.** The working theory (a transcription/autofill issue at the password prompt, not a code bug) was never confirmed. If it resurfaces, start by asking whether the bypass test was ever tried, rather than re-diagnosing from scratch.
2. **`api.php`/`add-item.php` deploys via `deploy.ps1` have been intermittently unreliable in past sessions** (`curl: (56)`/`curl: (18) ... got 450`) — manual upload via Hostinger File Manager is the fallback that has worked. This session's deploys (including `.php` files) all reported success first try, but keep verifying with a diff/marker check if one ever looks suspicious.
3. **The Gmail-scan workflow's UI is hidden (`display:none`), not deleted**, and a large amount of supporting JS remains in `index.html`, unreferenced by any visible UI. Couldn't be fully removed because the **Gmail OAuth Settings card is still load-bearing** for **Announce Winners → Email Winners** (`sendWinnerEmails()` → `sendEmailsViaGmail()`).
4. **`donate-item.php` remains fully removed** — `add-item.php` is the only item-donation entry point. Its old SQL-side backend is still there in `api.php`, unused, per the "flag, don't delete" convention.
5. **`starting-bid-list.php` has no password gate**, matching `add-item.php`'s convention — anyone with the URL can view the full donated-items list with donor names and starting bids. Not explicitly discussed as a security tradeoff; flag it if the club raises privacy concerns.
6. **⚠️ Bid sheet algorithm — read this before changing `printBiddingSheets()` or `starting-bid-list.php`.** The two computations live in different files/languages (`index.html` JS, `starting-bid-list.php` PHP) and must be kept in sync — a header comment in the PHP file cross-references the JS function. The **current, final rule** (as of v6.3, unchanged in v6.4): every item is either an **OPEN auction** (Item Value alone — never reserve — is ≤ Settings → Auction Setup → "Open Bids", default $35) or a **PREMIUM auction** (Value above that). OPEN preprints only the first bid (reserve if set, else $1) with blank rows after; PREMIUM preprints all 20 rows, first bid = reserve if set else 30% of Value, increment = 10% of Value if Value < $100 else 7% if Value ≥ $100 (bracket boundary is `>=`, not `>` — a real bug fixed this session). **Reserve never decides OPEN vs. PREMIUM membership** — a mid-session revision briefly let a low reserve make an expensive item OPEN, and it shipped in v6.2 before a real bug report (item 800-1: Value $50/Reserve $25 printing a blank sheet) reversed it back to Value-alone in v6.3. `test.html` has a suite specifically documenting that reversal so it isn't accidentally resurrected from old commit history or a stale conversation summary.
7. **PHP files cannot be syntax-checked locally** — `php` is not on PATH in this environment (`php -l` fails with "command not found"). Edits to `.php` files are verified by inspection only, then confirmed by loading the live page. PHP 8's nested-ternary parenthesization requirement has bitten this project before — watch for it.
8. **A near-duplicate of `add-item.php` was created and fully removed in the v5.1 session** (`silent-auction-form.php`). If a future request sounds like "a public item-donation form without the member picker," check that session's history first.
9. **The "Bidders: 17 vs. 25" Home/Registrations mismatch (v5.4 session) was explained but never confirmed fixed.** Not touched again this session — still open if it resurfaces.
10. **Bid sheet row height is now `BID_SHEET_ROW_HEIGHT_IN = 0.40` in `printBiddingSheets()`**, a hardcoded JS constant with no UI to change it (the v3.1-era per-item override column and toolbar control were both removed this session). If a future request wants it configurable again, that's new work, not a revert — the old mechanism (`updateItemRowHeight()`, `#bs-row-height-input`, the per-item cascade-on-change logic) no longer exists in the codebase at all, only in git history.
11. **Two donor-name overflow bugs and one table-height bug were found by the user reviewing live screens this session** (not from code review) — worth remembering that pattern: `#items-table`'s fix didn't automatically cover `#bs-items-table` because they have entirely separate row-rendering functions (`refreshItemsTable()` vs. `refreshBsItemsTable()`), and the Registrations table's `calc(100vh - 388px)` was a silent outlier compared to every sibling screen's `calc(100vh - 278px)`. If another table shows a similar overflow or excessive-whitespace symptom, check for this same "fix applied to one twin table but not the other" pattern first.
12. **⚠️ Donated Items row editing changed shape in v6.6 — the old in-row Edit button is gone.** Double-clicking a row now opens `#item-edit-modal` (`openItemEditModal()`/`saveItemEditModal()`/`closeItemEditModal()`, all in `index.html`). The Actions column (View/Edit buttons) was removed from `#items-table` entirely. The **old in-row editor is flagged ORPHANED, not deleted** — `ITEM_EDIT_COLS_MAIN`, `rowCheckboxOffset()`, `editItemByNumber()`, `saveItemEdit()`, `cancelItemEdit()` all still exist (with a comment block explaining why, right above `ITEM_EDIT_COLS_MAIN`) but have **no live callers** as of this doc. Do not assume `editItemByNumber()` is reachable from the UI — it isn't. If reviving in-row editing is ever requested, that code is still there to resurrect; if extending item-editing, extend `saveItemEditModal()` instead. Note also that the modal's rename-a-winner-record-when-Item-#-changes handling is new in v6.6 and does **not** exist in the orphaned `saveItemEdit()`, in case that old code path is ever revived without noticing the gap.
13. **⚠️ Bid Sheet duplex layout & row-height saga (v6.7/v6.8) — read before touching `printBiddingSheets()`'s layout constants.** Each printed item now emits **4 page `<div>`s in this order**: `.sheet` (page 1 front, the original 20-row bid table + description/info boxes), `.sheet.sheet-continuation` (page 1 back, a new continuation bid table with **no** description/info boxes), `.label-page` (page 2 front, the description/donor label — unchanged from before), `.blank-page` (page 2 back, empty). With a printer set to duplex, this pairs correctly; **the app cannot force a printer/browser print dialog into duplex mode or a specific scale/margins setting** — no web API exposes that, it's entirely OS/driver-level. Two constants govern the fit and are **coupled**, not independent: `BID_SHEET_ROW_HEIGHT_IN` (currently `0.40`) sets every row's height on both the front and continuation tables, and `continuationRowCount` (currently `23`) sets how many rows the continuation page gets — since that page has no info boxes above the table, it can (and must, to fill the page) hold more rows than page 1's fixed `bidCount = 20`, but the exact number has to be recalculated any time the row height changes, or the continuation table overflows onto page 2's front (confirmed by a real screenshot this session). **What actually happened, in order:** (a) row height was `0.40` going in; (b) a screenshot showed only 16-17 of 20 rows fitting on page 1, so row height was shrunk to `0.35` then `0.28`, and `.sheet` padding shrunk `0.12in→0.05in`, to compensate; (c) the *real* root cause turned out to be the "Bid Amount" `<th>` silently wrapping to two lines ("Bid"/"Amount"), taking more vertical space than assumed — fixed properly with `white-space: nowrap` on `.bid-table th`; (d) separately, the user's own print-dialog **scale setting was also wrong** at the time of the overflow screenshots, compounding the apparent problem; (e) once both the header-wrap bug and the user's scaling were fixed, row height and `.sheet` padding were reverted back to their original `0.40`/`0.12in` values, since the row-height shrink was never actually necessary; (f) `continuationRowCount`, which had been set to `26` to fill the page at the smaller `0.28in` rows, then overflowed onto page 2 once rows went back to `0.40in` — reduced to `23` (confirmed via a real print screenshot showing the overflow, then confirmed fixed). **If asked to change row height again, remember to recompute `continuationRowCount` too** — there's no automatic scaling between the two, they're independent literals in the same function (`printBiddingSheets()`, `index.html`).
14. **`deploy.ps1`'s FTP transport was replaced this session — `curl.exe` is no longer used at all.** Root cause: on this machine, `curl.exe` uses the Windows Schannel TLS backend, which has a bug against this host's FTPS server — the file transfers **completely** (100% of bytes sent, confirmed via `curl -v` trace), but curl fails to read the server's final "226 Transfer complete" response over the control channel and exits with code 56 (`response reading failed`). The dangerous part: **this looked like a normal transient failure** (`deploy.ps1` printed "FAILED" with the curl error), but retrying the exact same command 3-5 times in a row all failed *identically* while `Last-Modified` on the live file never changed — meaning **every one of those retries had silently not deployed anything**, despite the appearance of a real attempt each time. `Deploy-File` in `deploy.ps1` now uses `System.Net.FtpWebRequest` instead, with a new `New-RemoteDir` helper recreating curl's old `--ftp-create-dirs` auto-directory-creation behavior, and a 300ms `Start-Sleep` between files in full-deploy mode (rapid back-to-back connections briefly triggered a real, transient `450 File unavailable (file busy)` from the host — confirmed to succeed instantly on individual retry, unlike the curl issue). This was verified end-to-end: single-file mode, full-deploy mode (all files, including nested `backend/routes/*.js`), and repeated `Last-Modified`-header checks confirming every "OK" now corresponds to a real change on the server. **If a future deploy ever reports failure, don't assume it's the old curl bug** — that transport is gone; a `FtpWebRequest` exception means something else (credentials, network, actual server rejection) and should be investigated fresh, not worked around via manual `.NET` scripting like this session's `/tmp/ftpupload.ps1` had to do before the permanent fix landed.

---

## What was accomplished this session (checkpoints v6.7, v6.8)

New day, new topic from the v6.6 session above — Print Bid Sheets' output layout, driven entirely by real print screenshots the user sent along the way, plus an unrelated but important deploy-tooling fix discovered mid-session.

### 1. New feature — Print Bid Sheets goes from 2 pages/item to 4-page duplex layout
**Request:** "Print 2 double sided pages. Page 1 side 1 as it currently is. Page 1 side 2 fill with 20+ rows. Page 2 side 1: the current page 2. Page 2 side 2: blank page."

Implemented in `printBiddingSheets()` (`index.html`): each item's HTML block now emits 4 page `<div>`s in order — `.sheet` (unchanged page-1-front bid table), a new `.sheet.sheet-continuation` (page-1-back — bid table only, no description/info boxes, header reads "Item # X (continued)"), `.label-page` (unchanged page-2-front description/donor page), and a new empty `.blank-page` (page-2-back). With a printer set to duplex, sides pair up correctly. The bid-amount ladder (Premium items) was made continuous across both bid tables: `bidAmounts` now generates `bidCount + continuationRowCount` values in one loop (so `prevAmt`/ascending-dedup logic runs unbroken), then splits into `bidRows`/`bidRows2` by slicing. Open-bid items correctly leave every continuation row blank too (`mkBidRow(amt, idx)` blanks any row where `isOpenBid && idx > 0`, and continuation rows pass `idx = i + bidCount` so they're always `> 0`).

Initial continuation row count was `26` (chosen when row height was `0.28in`, see below) — reduced to `23` after row height reverted to `0.40in`, once a real print screenshot showed the continuation table overflowing onto page 2's front at the taller row height.

### 2. Real bug — "Bid Amount" header silently wrapping to two lines, plus row-height back-and-forth
**Symptom (from a screenshot):** only ~16-17 of the intended 20 rows fit on page 1 before overflowing onto the next physical page.

**What happened, in order (see open item #13 above for the full narrative):**
1. Assumed the fixed `BID_SHEET_ROW_HEIGHT_IN` (was `0.40`) was simply too tall for the page budget — shrunk it to `0.35`, still overflowed per a second screenshot (17 of 20 rows), shrunk further to `0.28`, plus `.sheet` padding `0.12in→0.05in` to reclaim more space. This "worked" (all 20 rows fit) but left a lot of unused blank space at the bottom of the page.
2. Later, the user reported their **print-dialog scale setting had been wrong** and asked to "fix layout" now that scaling was corrected. Re-examining the screenshots at that point pointed at the true root cause: the `.bid-table th` "Bid Amount" header was wrapping to two lines ("Bid"/"Amount") in a narrow column, silently taking more vertical space than assumed and eating into the 20-row budget — not that `0.40in` rows were inherently too tall.
3. Fixed properly with `white-space: nowrap` on `.bid-table th`, then **reverted** `BID_SHEET_ROW_HEIGHT_IN` back to `0.40` and `.sheet` padding back to `0.12in 0.25in` — the shrink was a workaround for a bug that's now actually fixed, and page 1 now fills properly again at the original page-filling size.
4. That revert then broke the continuation page (still using `continuationRowCount = 26`, sized for the smaller `0.28in` rows) — a screenshot showed it overflowing onto page 2's front. Reduced to `23`, confirmed via the user's next screenshot check.

**Takeaway for future sessions:** row height and continuation-row-count are coupled constants in the same function with no automatic relationship between them — changing one without recalculating the other will overflow a page. Also: always ask/verify the user's print-dialog **Scale** and **Margins** settings match between destinations (PDF vs. physical printer) before diagnosing a layout bug as a CSS issue — a wrong Scale setting on the user's end can look identical to a real overflow bug in a screenshot.

### 3. Deploy tooling — `deploy.ps1` switched from `curl.exe` to `.NET FtpWebRequest`
**Discovered mid-checkpoint:** `deploy.ps1`'s curl-based upload started failing on *every* attempt (not intermittently) — `curl: (56) response reading failed`. Investigated with `curl -v`: the file transferred **100% of its bytes** every time, but curl couldn't read the server's final "226 Transfer complete" response over the control channel (`schannel: server close notification received` right after the data upload finished) and reported exit 56 regardless. Confirmed via `Last-Modified` header checks that **repeated identical-looking "failures" had genuinely not updated the live file** — a real correctness risk, since `deploy.ps1` was reporting "FAILED" honestly, but a less careful read of that output (or a differently-behaved retry) could easily be mistaken for "probably fine, curl is just flaky."

**Root cause:** `curl.exe` on this machine uses the Windows Schannel TLS backend, which has a bug/incompatibility with this Hostinger FTPS server's connection-closing behavior after a completed transfer.

**Fix:** rewrote `Deploy-File` in `deploy.ps1` to use `System.Net.FtpWebRequest` directly instead of shelling out to curl — reads the local file into memory, opens the FTP request stream, writes the bytes, and checks the server's actual response object rather than an external process's exit code. Added `New-RemoteDir` to recreate curl's old `--ftp-create-dirs` auto-directory-creation (walks each path segment, calling `MakeDirectory`, ignoring "already exists" errors). Added a 300ms `Start-Sleep` between files in full-deploy mode after hitting a real (but different, and transient) `450 File unavailable (file busy)` error under rapid back-to-back connections — confirmed that error resolves on individual retry, unlike the curl issue which did not. Verified end-to-end: single-file deploys, a full all-files deploy (including nested `backend/routes/*.js` — exercises `New-RemoteDir`), and `Images/ETCC-Logo.ico`/`js/toolbar.js` specifically (the two files that hit the transient busy error). Every "OK" now cross-checked against a fresh `Last-Modified` header to confirm it's not a repeat of the curl false-positive/false-negative problem. Committed separately from the checkpoints (`3f2bbee`, "Switch deploy.ps1 from curl to .NET FtpWebRequest") since the user asked for it as a standalone "commit deploy.ps1", not as part of a checkpoint.

### 4. `test.html` updated, confirmed green (both checkpoints)
**v6.7:** new suites `'Bid Sheet — duplex 4-page layout (v6.7)'` (8 assertions covering the 4-page structure, continuation page content, and the continuous bid ladder) and `'Bid Sheet — page 1 row height fits all 20 rows (v6.7)'` (3 assertions, later annotated as superseded once v6.8 reverted the values). The pre-existing `'Bid Sheet — exactly two pages per item'` suite was renamed to `'Bid Sheet — description & label-page layout'` and its page-count-specific assertions removed, since the app no longer emits exactly two pages per item.

**v6.8:** new suite `'Bid Sheet — row height reverted to page-filling value (v6.8)'` (3 assertions covering the `0.40in`/`0.12in`/`continuationRowCount=23` revert), plus the v6.7 row-height suite and the duplex-layout suite's stale `26`/`0.28in`/`46`-specific assertion text updated to reflect the final v6.8 numbers and point at v6.8 for the current state.

### 5. Checkpoints v6.7 and v6.8 (minor version bumps)
Two straightforward minor bumps (`.\bump-version.ps1`, no `-Major` requested) — v6.7 after the duplex-layout feature landed and was confirmed working via screenshot, v6.8 after the row-height revert/continuation-count fix was confirmed via a follow-up screenshot.

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`7f6ddea` for v6.7, `57e0e30` for v6.8) | `printBiddingSheets()`: 4-page duplex template, continuous bid ladder across pages, row-height/padding/continuation-count constants revised twice; `.bid-table th { white-space: nowrap }` fix; `.blank-page`/`.sheet-continuation` CSS added; version bumps to v6.7 then v6.8 |
| `test.html` | committed (`7f6ddea`, `57e0e30`) | v6.7: 2 new suites/11 assertions, 1 suite renamed+trimmed. v6.8: 1 new suite/3 assertions, 2 prior suites' text updated to point at final values. Confirmed green by the user both times. |
| `deploy.ps1` | committed separately (`3f2bbee`, between v6.7 and v6.8) | `Deploy-File` rewritten to use `System.Net.FtpWebRequest`; new `New-RemoteDir` helper; 300ms inter-file delay in full-deploy mode; netrc-file setup/cleanup removed as dead code |

---

## What was accomplished this session (checkpoint v6.6)

Two-part follow-up in the same day as v6.5 below — a new interaction pattern requested by the user (double-click to edit), then a cleanup request that removed the UI it replaced.

### 1. New feature — double-click a Donated Items row opens an Edit Item modal
**First request:** "double clicking a row should open editing" — implemented initially as attaching a double-click handler that called the existing in-row `editItemByNumber()` (same as the Edit button, just triggered by a dblclick instead of a click).

**Follow-up request, same turn:** "open editing form in a modular page with save and cancel" — this meant a proper modal, not in-row inline editing. Built `#item-edit-modal` (`index.html`, inserted at the end of the Step 1 `screen-item-load` section, right before its closing `</section>`) modeled directly on the existing `#bidder-edit-modal` pattern:
- Fields: Item #, Category (`<select>` built from the global `CATEGORIES` map), Submission Date, Description (`<textarea>`), Item Value, Reserve Amount, Donor Name (`<textarea>`), Donor Email (`<textarea>`), Donor Phone.
- `openItemEditModal(itemNumber)` populates every field and stores the original item number on `modal.dataset.originalItemNumber` (so a rename mid-edit doesn't break the save lookup).
- `saveItemEditModal()` writes all fields back, sets `source = 'Edited'`, and — **a real improvement over the old in-row editor, which never had this** — if the Item # was changed and a winner record exists under the old number, it's copied to the new key and the old key deleted, so renaming an item no longer silently orphans a recorded win.
- `closeItemEditModal()` is a plain hide, no side effects (Cancel behavior).
- The double-click listener (attached per-row in `refreshItemsTable()`) skips read-only mode, and bails via `e.target.closest('input, button, select, textarea, a')` so clicking the row's checkbox or (at the time) the Edit/View buttons didn't also fire the modal.

**Follow-up sizing request:** a screenshot of the modal in use showed the Description box looking cramped relative to real donation descriptions — bumped `#edit-item-description` from `rows="3"` to `rows="8"` to match.

### 2. Removed — the Actions column (View/Edit buttons) from Donated Items
Once double-click became the primary edit path, the user asked to remove the Actions column and its buttons entirely. Removed:
- `<th>Actions</th>`, its `<col style="width:200px;">`, and the row template's trailing `<td>` (View + Edit buttons) from `#items-table`.
- Table `min-width` recalculated 1986px → 1786px (verified against the sum of the 11 remaining column widths); empty-state colspan 12 → 11.
- `emailIdx`/`EMAIL_ICON`, which existed solely to feed the removed View button — deleted outright as genuinely dead loop-local code, not flagged (there's nothing standalone worth preserving there, unlike a whole function).

**Orphaned, not deleted** (per the project's standing convention): `ITEM_EDIT_COLS_MAIN`, `rowCheckboxOffset()`, `editItemByNumber()`, `saveItemEdit()`, `cancelItemEdit()` — the whole in-row-edit cluster lost its only caller. Left in place with an explicit `ORPHANED` comment block above `ITEM_EDIT_COLS_MAIN` naming the cluster, explaining why, pointing at the replacement, and flagging that `ITEM_EDIT_COLS_MAIN`'s `actions:10` index is now stale (the column it pointed at no longer exists) in case this code is ever revived without updating it first.

**Checked, needed no change:** `showEmailModal()` itself is still called from the separate Email inbox table's own View button — only the Donated Items call site was removed. The View All modal clones `#items-table`'s thead/tbody dynamically with no hardcoded column-count assumption, so it picked up the Actions-column removal automatically.

### 3. `test.html` updated, confirmed green
Three new suites: the modal itself (8 assertions — population, field types, save/rename-carries-winner/empty-Item#-rejected, cancel), the Actions-column removal (5 assertions), and the orphaned-code flagging (3 assertions).

### 4. Checkpoint v6.6 (minor version bump)
Straightforward minor bump from v6.5 via `.\bump-version.ps1` (no `-Major` requested).

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`b3b80a7`) | `#item-edit-modal` + `openItemEditModal()`/`saveItemEditModal()`/`closeItemEditModal()`; double-click listener in `refreshItemsTable()`; Actions column removed (header/colgroup/row/colspan/min-width); `emailIdx`/`EMAIL_ICON` deleted; in-row-edit cluster flagged orphaned; version bump to v6.6 |
| `test.html` | committed (`b3b80a7`) | 3 new suites / 16 assertions. Confirmed green by the user. |

---

## What was accomplished this session (checkpoint v6.5)

Small, single-topic follow-up in the same day as v6.1→v6.4 below — the user pointed out a real overflow issue on a report screen not touched earlier in this session.

### 1. Real bug — Items Not Won report's Item # and Donor Phone columns wrapped onto two lines
**Symptom (from a screenshot):** on the standalone "Items Not Won" print report (`printItemsNotWonReport()` in `index.html`, ~line 8750), the "Item #" header wrapped to "Item" / "#" and "Donor Phone" wrapped to "Donor" / "Phone" — the narrow columns didn't have room for the two-word labels on one line, and phone number values in the data rows could wrap too.

**Fix:** added `style="white-space:nowrap;"` to both the `<th>` header cells and the corresponding `<td>` data cells for Item # and Donor Phone. Left Description, Category, Donor Name, and Donor Email untouched — those are meant to wrap.

### 2. `test.html` updated, confirmed green
New suite `'Items Not Won report — Item # / Donor Phone no longer wrap (v6.5)'` (3 assertions covering the header fix, the data-cell fix, and that unrelated columns were left alone). Deployed via `.\deploy.ps1 test.html`, confirmed green by the user before the checkpoint.

### 3. Checkpoint v6.5 (minor version bump)
Straightforward minor bump from v6.4 via `.\bump-version.ps1` (no `-Major` requested).

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`7636b2c`) | `white-space:nowrap` added to Item # / Donor Phone header + data cells in the Items Not Won report; version bump to v6.5 |
| `test.html` | committed (`7636b2c`) | 1 new suite / 3 assertions. Confirmed green by the user. |

---

## What was accomplished this session (checkpoint v6.4)

Small follow-up found by the user reviewing live screens right after the v6.3 checkpoint — the same donor-name overflow bug fixed on the Donated Items table earlier in this session had a twin on a different table, and a page-height inconsistency on Registrations.

### 1. Real bug — Donor Name/Email overflow recurred on the Create Bid Sheets table
**Symptom:** the same visual overflow already fixed earlier this session on `#items-table` (Donated Items) reappeared on `#bs-items-table` (Create Bid Sheets) for the same item (900-1, "Wilderness Trail Distillery, Attn. Grayson Yaden").

**Root cause:** the two tables have **entirely separate row-rendering functions** (`refreshItemsTable()` vs. `refreshBsItemsTable()`) — fixing one's Donor Name/Email `<td>` styling doesn't touch the other's.

**Fix:** added the same `white-space:normal;word-break:break-word;vertical-align:top` to `refreshBsItemsTable()`'s donorName/donorEmail cells (`index.html:6053-6054`). Also checked `printDonatedItemsList()` (the standalone "🖨 Print" page) — it uses default (non-`table-layout:fixed`) table layout, so it isn't exposed to this bug class at all and needed no change.

### 2. Real bug — Registrations table subtracting ~110px more than sibling screens
**Symptom:** the Registrations table (32 bidders) showed noticeably fewer rows before scrolling than comparable screens, with unexplained empty space below the card.

**Root cause:** `#bidders-card`'s scroll container used `max-height:calc(100vh - 388px)`, while every structurally similar screen (Winning Bidders, Create Bid Sheets, Payments) uses `calc(100vh - 278px)` — despite those screens having comparable extra content above their tables (e.g. Winning Bidders' save-note bar vs. Registrations' metric-row). No comment explained the 388px figure; it was a silent outlier.

**Fix:** matched the established `278px` convention rather than guessing a new number (`index.html:1255`).

### 3. `test.html` updated, confirmed green
New suite `'Create Bid Sheets table — Donor Name/Email wrap fix (v6.4)'` (2 assertions) and `'Registrations table — scroll height matched to sibling screens (v6.4)'` (2 assertions).

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`35ae34f`) | `#bs-items-table` donor wrap fix; `#bidders-card` scroll height 388px→278px; version bump to v6.4 |
| `test.html` | committed (`35ae34f`) | 2 new suites / 4 assertions. Confirmed green by the user. |

---

## What was accomplished this session (checkpoint v6.3)

The largest single checkpoint of this multi-day arc — the bid sheet algorithm was restated from scratch by the user, went through a mid-session revision that turned out wrong, got corrected by a real bug report, and the printed sheet's layout was overhauled to a fully fixed-height design. Three test suites had gone stale or actively wrong by the end and were rewritten, not just added to.

### 1. Bid sheet algorithm restated as OPEN vs. PREMIUM auctions
The user restated the entire algorithm explicitly (quoted here since it's the rule now in force):

> First a bid sheet is either for an **open auction** (Value ≤ $35.00) or a **premium auction** (Value > $35.00). Open auction: only the first bid is preprinted — $1 with no reserve, or the reserve when present. Premium auction: all bids preprinted — first bid is the reserve when present or 30% of value when no reserve; increment is 10% of value if value < $100, 7% if value ≥ $100.

Implemented in `printBiddingSheets()` (`index.html`) with `isOpenBid`/`startingBid`/`incPct` variables named to match this terminology directly, replacing several sessions' worth of accumulated ad-hoc comments. **Caught and fixed a real boundary bug while rewriting**: the old code used `Value > $100 → 7%`; the user's restatement is `Value ≥ $100 → 7%`. An item valued at exactly $100 was getting the wrong bracket before this fix.

### 2. Mid-session revision, then a reversal (important — read if touching this code)
Before landing on the above, this session went through **two prior revisions of "what counts as OPEN"** within the same conversation:
1. **v6.0** (previous checkpoint): OPEN required *no reserve at all* — any reserve excluded an item outright, regardless of value.
2. **A revision partway through this session**: a reserve counted toward the OPEN check too — an item was OPEN if `(reserve if set, else value) <= threshold`. This shipped as part of the v6.2 checkpoint.
3. **This session's correction**: a live bug report — item 800-1, Value $50 (above the $35 threshold) but Reserve $25 (below it) — printed a **blank** OPEN-style sheet under rule #2, when the user expected a normal, fully preprinted sheet since the item's actual value was well above the threshold. The user confirmed explicitly: **Value alone decides OPEN vs. PREMIUM membership**; reserve only ever affects the *first bid amount*, never membership. Rule #2 was reverted.

`test.html` now carries a suite specifically titled to document this reversal (`'Bid Sheets — reserve does NOT decide OPEN/PREMIUM membership (v6.2, corrected)'`) so a future session reading old commits or a stale summary doesn't resurrect rule #2.

### 3. `starting-bid-list.php` updated to match, each time
Both the reserve-counts revision and its reversal were mirrored into `starting-bid-list.php` in the same sessions they happened in JS, keeping the two files in sync throughout (per the standing convention documented in open item #6 above).

### 4. Bid sheet layout — fixed-height Description and Category/Donor/Value/Reserve boxes
Requested from a screenshot of a real printed sheet showing a 4-line Description box and a 2-line Category/Donor/Value row — the user wanted every sheet to use that same fixed layout regardless of content length.

- **Description box**: `height:0.92in` (computed from the box's 16.8px font / 1.2 line-height + padding/border), `overflow:hidden`, `box-sizing:border-box`. Hard `height`, not `min-height` — the user explicitly asked for fixed values, not a content-driven minimum.
- **Category/Donor/Value/Reserve row**: `height:0.50in` on the CSS grid container, plus explicit `line-height:1.2` on each cell (not previously set).
- **Real bug found and fixed mid-implementation**: setting `height:0.50in` on the grid container alone wasn't enough — its implicit `auto`-sized row track still grew to fit the tallest cell's natural content, and a 3-line donor address ("Wilderness Trail Distillery, Attn. Grayson Yaden") bled into the bid table's header row below it, even though each cell already had its own `overflow:hidden`. Fixed by adding `grid-auto-rows:0.50in` **and** `overflow:hidden` **on the container itself** — a child's own overflow:hidden doesn't stop its grid container from growing.
- Simplified `page-break-inside` to always `'avoid'` (previously switched to `'auto'` past 400 description characters to avoid a Chrome print-layout hang) — now that every box is fixed-height, the sheet's total height can never grow, so that risk no longer exists.
- **Row height raised 0.28in → 0.40in** ("to better fill the page" — this became the v6.4-adjacent `BID_SHEET_ROW_HEIGHT_IN` constant, see below).

### 5. Removed: per-item Row Height column + toolbar control (Create Bid Sheets table)
Per explicit user request ("remove row height from each row and header", then "eliminate the toolbar's single global Row Height (in) control" as a follow-up in the same turn):
- Removed `<th>Row Height</th>`, its `<col>`, the per-row `<input class="bs-row-height">`, and `updateItemRowHeight()` (no remaining callers).
- Removed the entire toolbar `rowHeightWrap`/`rowHeightInput` construction and its change handler, including the per-item cascade-cleanup logic that only existed to service the now-gone override.
- Replaced with a single fixed JS constant, `BID_SHEET_ROW_HEIGHT_IN` (0.28, later changed to 0.40 per item 4 above), read nowhere from Settings.
- `DEFAULT_SETTINGS.bidRowHeight` left in place, flagged as orphaned in a comment (existing stored settings/items may still carry the old value) — nothing reads or writes it anymore.

### 6. Removed: Date Loaded column (Create Bid Sheets table)
Straightforward column removal (header, `<col>`, row cell, empty-state colspan). The underlying `item.loaded_date` data field is untouched — still set on item creation elsewhere, just no longer displayed in this table.

### 7. `test.html` — three suites rewritten (not just added to), because they had gone stale or actively wrong
- `'Bid Sheet — Bid Amount Algorithm'` (v3.1) — was still asserting the pre-Open-Bids formula (increment based on reserve-substituted value, not Item Value). Updated the local `computeBidAmounts()` mirror and its expected numbers (one assertion's expected diff changed from 8 to 7).
- `'Bid Sheet — Row Height (Global + Per-Item)'` (v3.1) — described a feature that no longer exists. Rewritten to explicitly document the removal rather than deleted outright, so a future session sees "this was removed" instead of just finding no test at all.
- The three "Open Bids" suites from v6.0/v6.2 — one still used the old `reserveRaw === 0` check, one **actively asserted the now-reversed rule** ("a reserve counts toward Open Bids"), and the Starting Bid List suite quoted stale PHP. All rewritten; the reversed one was kept as its own dedicated suite specifically to document the reversal (see item 2 above).
- Every executable numeric assertion (`bidLadder()`, `computeBidAmounts()`) was independently re-verified against the real formulas in a standalone Node script before deploying, not just eyeballed — this caught the false "Open Bids = 0 disables the category entirely" claim from the v6.0 session (a $0/undeclared item still qualifies at exactly 0) during a prior pass, and this session's rewrite followed the same discipline.

### 8. Checkpoint v6.3 — version bump correction
`/ETCCSAMCheckpoint` (no version argument) was run and a **major** bump to v7.0 was applied by mistake — the standing procedure is minor-by-default, major only if the user explicitly asks, and no such request was made this time. Caught before committing; reverted to **v6.3** (correct minor bump from v6.2) via a direct edit to the footer span, then re-deployed and committed normally. No v7.0 was ever pushed or is live anywhere.

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`94fd61d`) | OPEN/PREMIUM algorithm rewrite + `>=100` bracket fix; fixed-height Description/info-row boxes + grid overflow fix; Row Height column/toolbar removed, replaced with `BID_SHEET_ROW_HEIGHT_IN` (0.40); Date Loaded column removed; version bump to v6.3 (corrected from an erroneous v7.0) |
| `starting-bid-list.php` | committed (`94fd61d`) | Mirrors the final OPEN/PREMIUM Value-alone rule; header comment updated |
| `test.html` | committed (`94fd61d`) | 3 suites rewritten (not just added), 3 new suites added, all executable assertions independently re-verified in Node. Confirmed green by the user. |

---

## What was accomplished this session (checkpoint v6.2)

Continuation of the same-day v6.1 session. Two new bid-sheet features plus one iOS bug fix — note that this checkpoint's "reserve counts toward Open Bids" change was **reversed in the very next checkpoint (v6.3)** after a real bug report; see that write-up above for the full story. Read this section for historical context only, not as the current rule.

### 1. Favicon — apple-touch-icon added for iOS
**Symptom reported:** the favicon didn't appear on iPhone/iPad. **Root cause:** iOS Safari ignores `<link rel="icon">` entirely — it only reads `<link rel="apple-touch-icon">`, which this app never had. **Fix:** added the tag to `<head>`, wired `updateFavicon()` to keep it in lockstep with the regular favicon (same Club Favicon URL setting, no new field). **Known limitation, explicitly flagged in a test assertion:** the current default image (`Images/ETCClogoWhiteBackground.png`) is 150×116px and non-square, below Apple's 180×180 square guidance — no image-editing tooling was available in this environment to produce a proper one, so iOS may crop/pad it imperfectly. Shows something now rather than nothing, but isn't crisp.

### 2. "Open Bids" — new bid-sheet category (first version, later revised)
New Settings → Auction Setup → "Open Bids" threshold (default $35): items at or below it get a $1 (or reserve, if the reserve itself was also ≤ threshold under this version's rule) opening bid with no preprinted increments. **This session's rule for what counted as "open"** — a reserve counted toward the check, not just an unreserved low-value item — **was reversed in v6.3**; see that write-up for why. The Settings UI, `DEFAULT_SETTINGS.openBidMax`, and the general shape of the feature (fixed row 1, blank rows 2-20) all survived into the current version unchanged; only the membership rule changed.

### 3. Bid ladder — every preprinted row forced strictly higher than the last
Real bug: rounding a sub-$1 increment could collapse consecutive rows onto the same dollar figure (e.g. a $2 reserve stepping by $0.20 printed `2, 2, 2, 3, 3...`). Fixed with a per-row guard (`if (prevAmt !== null && amt <= prevAmt) amt = prevAmt + 1`) rather than rounding the increment up globally, specifically so already-correct ladders keep their exact amounts. This guard is unchanged in the current (v6.3) version of the algorithm.

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`6be9812`) | apple-touch-icon + `updateFavicon()` sync; Open Bids setting (first version, later revised) + rising-ladder guard; version bump to v6.2 |
| `starting-bid-list.php` | committed (`6be9812`) | Open Bids rule mirrored (first version, later revised) |
| `test.html` | committed (`6be9812`) | New suites for apple-touch-icon and the first Open Bids version (the latter later rewritten in v6.3). Confirmed green by the user. |

---

## What was accomplished this session (checkpoint v6.1)

Small, single-topic follow-up in the same day as the v6.0 session below — the user asked "where is the favicon," which surfaced a real duplicate-fallback bug while answering.

### 1. Real bug — two disagreeing hardcoded favicon fallbacks
**How it surfaced:** answering "where is the favicon" required tracing all the code paths that touch it, which turned up an inconsistency: the `<head>` `<link rel="icon">` tag and `getClub().favicon` ([index.html:6348](index.html:6348)) both defaulted to `Images/ETCClogoWhiteBackground.png`, but `updateFavicon()` ([index.html:6263](index.html:6263), pre-fix) carried its own separate hardcoded fallback, `Images/ETCC-Logo.ico`. With no `clubFavicon` setting configured, the tab icon's actual value depended on which code path ran last — the `.png` on first paint from the static tag, then potentially the `.ico` once settings loaded and `applyBranding()`/`updateFavicon()` ran.

**Fix:** `updateFavicon()` no longer carries its own literal — it now reads `link.href = faviconUrl || getClub().favicon`, deferring to `getClub()` as the single source of truth. Also removed the `type="image/png"` attribute from the static `<head>` tag, since Settings → Club Branding → Club Favicon URL can point the href at any format (`.ico`/`.svg`/etc.) and a hardcoded png type would misdescribe those overrides.

**Where the favicon can be changed:** Settings → Club Branding → **Club Favicon URL** (`#inp-club-favicon` → `clubFavicon` setting, applied via `applyBranding()`/`updateFavicon()`).

### 2. `test.html` updated, confirmed green
New suite `'Favicon — unified default fallback (v6.1)'` (4 assertions) covering the root cause, the fix, the `<head>` tag's type-attribute removal, and that `getClub()` remains the sole place the default path is defined. Deployed via `.\deploy.ps1 test.html`, confirmed green by the user before the checkpoint.

### 3. Checkpoint v6.1 (minor version bump)
Straightforward minor bump from v6.0 via `.\bump-version.ps1` (no `-Major` requested).

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`be653c4`) | `updateFavicon()`'s duplicate literal removed, defers to `getClub().favicon`; `<head>` icon tag's `type="image/png"` dropped; version bump to v6.1 |
| `test.html` | committed (`be653c4`) | 1 new suite / 4 assertions. Confirmed green by the user before the checkpoint. |
| `PROJECT_STATUS.md` | this file, being committed now | continuity doc, not app code |

---

## What was accomplished this session (checkpoint v6.0)

Four independent threads, all driven by the user reviewing the live app and reporting what they saw. Two were new bid-sheet requirements; two were real UI bugs. Everything landed in one v6.0 checkpoint.

### 1. Real bug — Home Auctions panel empty until a hard refresh
**Symptom reported:** logging in at https://etccapps.com/apps/sam/ showed a splash screen with no data ("No auctions yet"), and only `Ctrl+Shift+R` followed by re-entering the password produced the real screen. The user noted their other apps don't behave this way. The console screenshot showed several `401` responses from `api.php` plus `get_all: Unauthorized`.

**Root cause (a render-ordering bug, not an auth bug):** the top-level `init()` IIFE in `index.html` calls `updateHomeAuctionPanel()` / `renderAuctionsList()` unconditionally at page load. At that moment the user is not yet logged in, and `get_all` is deliberately **not** in `api.php`'s `$publicActions` list, so it correctly returns 401 and the panel renders against empty data. On a successful password entry, `initializePasswordScreen()`'s `checkPassword()` *did* re-sync the real data via `syncFromKeyValueDB()` — but then only called `refreshHomeMetrics()`, which repaints the four small stat tiles and **nothing else**. The auctions panel/list was never re-rendered, so it stayed stuck on its pre-login empty render. A hard refresh "fixed" it only because by then the PHP session cookie was already valid, letting the *pre-login* boot fetch succeed on that second load. The 401s in the console were therefore expected/by-design, not the fault.

**Fix:** both login success paths now call `updateHomeAuctionPanel()` and `renderAuctionsList()` immediately after the post-login `syncFromKeyValueDB()` / `refreshHomeMetrics()` — `checkPassword()` (normal password screen) and the maintenance-screen `submit()` handler. Display layer only; no auth/session logic touched. Both functions are pure re-renders already called elsewhere (`archiveAuction()`, `openAuction()`), so calling them again is idempotent.

### 2. New feature — "Open Bids" category on bid sheets
**Request:** support two types of bid sheet based on the item's value *when no reserve is specified*. New setting **"Open Bids"** = the maximum declared value that counts as open-bid, default **$35.00**. Open-bid items get a $1 starting bid and no bid increments; every other item's sheet is unchanged.

**Design decision made by the user** (asked explicitly, since it changes a physical printout): of three options for the Bid Amount column, the user chose **"first row shows $1, rows 2-20 blank."** Not a blank column with a "Starting Bid: $1" header box, and not all 20 rows reading $1. Nothing else on the sheet changed — no extra info box was added.

**Implementation, all in `index.html`:**
- `DEFAULT_SETTINGS` gains `openBidMax: 35`, grouped with the other bid-sheet defaults.
- Settings → **Auction Setup** card gains `#inp-open-bid-max`, directly below Bid Count.
- Settings load reads `s.openBidMax ?? 35`; the save builder writes `openBidMax: parseFloat(...) || 0`. The `??` (not `||`) matters — it preserves an explicit `0`.
- `printBiddingSheets()`: `const isOpenBid = reserveRaw === 0 && itemValueRaw <= openBidMax;` → `startingBid = 1`, `incrementAmount = 0`, and the row renderer emits an empty `<td>` for `idx > 0`.

**Semantics worth knowing:**
- An item **with** a reserve is never open-bid, no matter how low its value.
- The threshold is **inclusive** ($35 exactly still qualifies at the default).
- **Setting Open Bids to 0 disables the category** for anything with a declared value. Blank/invalid input also saves as 0, matching how `squarePct`/`squareFee` already behave.
- An item with **neither value nor reserve** falls into the open-bid category. This is a strict improvement — previously such an item produced a sheet with 20 rows all reading `$0`.

### 3. `starting-bid-list.php` aligned with the new bid math
The standalone Starting Bid List computes its own starting bid in PHP and would have kept showing 30%-of-value for open-bid items, contradicting the printed sheet. On the user's go-ahead it now applies the identical rule:
```php
$isOpenBid = $reserve <= 0 && $value <= $openBidMax;
$startingBid = $isOpenBid ? 1 : ($reserve > 0 ? $reserve : ($value * $startingBidPct / 100));
```
- `$openBidMax` is read from `sam_settings` using `isset(...) && ... !== ''` — the strict `!==` lets an integer `0` through as "disabled", matching the JS `??` behavior, while a missing/blank value falls back to 35.
- Parsed via `(float)preg_replace('/[^0-9.]/', '', ...)`, mirroring the JS `parseMoney()` helper, so a setting stored as `"$35.00"` resolves to 35 rather than 0.
- **The nested ternary is deliberately parenthesized** — PHP 8 fatals on unparenthesized nested ternaries, and this file could not be linted locally (no `php` on PATH; see open item #7).
- A header comment now names `printBiddingSheets()` as the function this must stay in sync with. See open item #6 — this is now a two-implementation rule.

### 4. Real bug — preprinted bid rows could repeat the same amount
**Request:** "make sure every preprinted bid row is larger than the previous row."

**Root cause:** amounts were built as `Math.round(startingBid + i * incrementAmount)`. When the increment rounded to under $1, consecutive rows collapsed onto the same dollar figure — e.g. a **$2 reserve** steps by 10% = $0.20 and printed `2, 2, 2, 3, 3, 3…`. Only reachable for low-value reserved items (unreserved low-value items are now open-bid and print blank rows anyway).

**Fix:** a per-row guard — `if (prevAmt !== null && amt <= prevAmt) amt = prevAmt + 1;`. Chosen deliberately **over** rounding the increment up globally (`Math.max(1, Math.round(inc))`), because the guard leaves already-correct ladders byte-identical. Verified: `$40 → 12,16,20,24,28`, `$150 → 45,56,66,77,87,98` (keeps its uneven 11/10 spacing from the 7% rate), `$500 reserve → 500,535,570,605` — all unchanged. Only genuinely broken ladders shift (`$2 reserve → 2,3,4,5,6,7`).

### 5. Real bug — Developer nav row closed the drawer out from under its own submenu
**Request:** "when the developer password is validated, show the menu bar on the left."

**Root cause:** the off-canvas nav IIFE attached `closeNav` to **every** `.nav-item` — including `#nav-developer`. But that row doesn't navigate anywhere; `toggleDeveloperMenu()` expands `#nav-developer-submenu` *in place*. So clicking it removed `body.nav-open` and slid the drawer off-screen, while `submitAuthPassword()` dutifully expanded the submenu inside the now-hidden drawer. The menu was working the whole time — it was just off-screen.

**Fix:** exempt `#nav-developer` from that handler (`if (el.id === 'nav-developer') return;`). No ancestor of that element matches the `.nav-item, a` selector, so skipping the element itself fully suppresses the close. Submenu entries (Configuration / Settings / Change Log / API / Import Members) still close the drawer, since those *are* real navigation targets.

**Two deliberate scoping choices:** (a) this also fixes the **already-authenticated** path — within the 30-minute settings-auth window the drawer used to close with no password prompt to blame; (b) the fix lives in the nav click handler rather than forcing the drawer open inside `submitAuthPassword()`, because that function *also* gates deleting an auction and deep-links to developer screens, where popping the drawer open would cover the screen the user just asked for. Verified safe: `#auth-modal` is z-index 2000 vs `#nav` at 200 and `#nav-backdrop` at 150, so the modal renders cleanly above an open drawer.

### 6. `test.html` updated, confirmed green
Four new suites (24 assertions), plus the login-fix suite relabeled from v5.4 to v6.0 (a v5.4 checkpoint landed from a different session mid-stream, so the original label would have been wrong).

The bid-sheet suite is **genuinely executable**, not documentation-style: it carries a local `bidLadder()` mirror of `printBiddingSheets()`'s arithmetic (copied rather than imported, since the real function builds an entire print document via `openPrintWindow()`) and asserts against real computed output — open-bid detection, the $1 opening bid, strict monotonicity across 16 value/reserve combinations, the sub-$1 collapse fix, and a no-regression check pinning the $40/$150/$500 ladders to their exact prior amounts.

**That paid off immediately:** it caught a false assertion in the tests themselves. The claim "Open Bids = 0 disables the category entirely" is wrong — a $0/undeclared item still qualifies at 0, because `0 <= 0` holds. The assertion was corrected to "…for every item with a declared value" rather than the behavior being changed, since a $0 item landing in the open-bid category is the desirable outcome (it's what avoids the old all-`$0` sheet).

### 7. Checkpoint v6.0 (major bump, user-requested)
Invoked as `/ETCCSAMCheckpoint v6.0`. Current version was **v5.4** (not v5.3 — a "Donated Items table zoom" checkpoint had landed from a separate session in between), so `.\bump-version.ps1 -Major` reached exactly v6.0. All `deploy.ps1` calls succeeded first try this session, including the `.php` file.

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`7f31481`) | Login re-render fix (2 paths); Open Bids setting (`DEFAULT_SETTINGS` + Auction Setup UI + load/save); `printBiddingSheets()` open-bid branch and strictly-rising ladder guard; `#nav-developer` exempted from the drawer-close handler; version bump to v6.0 |
| `starting-bid-list.php` | committed (`7f31481`) | Open-bid rule mirrored from the JS; `$openBidMax` read from `sam_settings` with 0-disables semantics; header comment cross-referencing `printBiddingSheets()` |
| `test.html` | committed (`7f31481`) | 4 new suites / 24 assertions (executable bid-ladder tests + Open Bids settings, Starting Bid List alignment, nav drawer); login suite relabeled v5.4 → v6.0. Confirmed green by the user before the checkpoint. |
| `PROJECT_STATUS.md` | this file, being committed now | continuity doc, not app code |

---

## What was accomplished in the v5.2 / v5.3 sessions (Donated Items table layout)

These two checkpoints never got their own write-up (the `/ETCCSAMEnd` run that would have covered them didn't happen before the v5.4 session took over the doc). Recorded briefly here so the version history has no gap — all of it is layout-only work on the Step 1 Donated Items table (`#items-table` in `index.html`):

- **v5.2** — rebalanced column widths after long donor addresses from `add-item.php` made the table read badly: Description widened 360px → 660px, and Value / Reserve / Donor Name / Donor Email narrowed (90→70, 90→70, 260→180, 260→200). Table `min-width` tracked the changes.
- **v5.3** — increased the table's scroll container from `max-height:258px` to `600px` so roughly 15+ rows are visible before scrolling starts. Same checkpoint also carried a pending `starting-bid-list.php` fix that had been sitting uncommitted: `white-space:nowrap` on Category/Donor Name was letting long content push past their intended share and squeeze Description, so that table moved to a fixed `<colgroup>` (Item # 7%, Category 24%, Starting Bid 8%, Donor Name 14%, Description 47%) with wrapping, and the card widened 700px → 900px.

---

## What was accomplished this session (checkpoint v5.4)

Two threads: diagnosing a set of Home-screen metric questions the user raised (no code bugs found, one piece of user education plus confirming an existing tool covered the need), then a small new feature (table zoom).

### 1. Home-screen metrics investigation — no bugs found
The user asked three follow-up questions about the Home screen's metric tiles (`refreshHomeMetrics()` in `index.html`):

- **"Bidders: 17" vs. Registrations screen showing 25.** Traced both to the same source — `Bidders.getAll()` → `DB.getBidders()` → `localStorage['sam_{auctionId}_bidders']` — so they should never disagree. Likely explanations given to the user: the Home tile only recalculates when `navigate('home')` fires `refreshHomeMetrics()`, so it can go stale if you register more bidders without revisiting Home; or transient drift from the dual-layer localStorage+MySQL sync (see `[[project_data_sync_architecture]]`). User was advised to hard-refresh and compare again; no follow-up report came back in this session, so **this discrepancy is not confirmed resolved** — if it resurfaces, start from this explanation rather than re-diagnosing from scratch.
- **"Paid & Picked Up: 5" despite "Winners Recorded: 0" and the Pay & Pickup screen itself saying "No winners recorded yet."** Root cause identified: the tile counts raw entries in `sam_payments` (`Object.values(payments).filter(p => p.paid).length`) regardless of whether a winner currently exists for that bidder — so these were **orphaned payment records** left over from before winners got cleared/reset for this auction. No live "winners → clear their payments too" cascade exists.
- **User asked to add a "Clear Payments" Developer Tools action.** Checked `index.html`'s Developer Tools card first — a `btn-clear-payments` button labeled **"Clear Pickup & Pay"** already exists (line ~1859), wired to `clearScopedData('payments', 'pickup & pay records')` and respecting the "Clear scope" auction dropdown above it. **No code was added** — the user was pointed at the existing button/flow instead (Developer Tools → set Clear scope to the current auction → Clear Pickup & Pay).

No files changed for this thread.

### 2. New feature — Donated Items table zoom in/out
The user asked for the ability to zoom in/out on the Donated Items table (Step 1 screen, `#items-table`). No existing zoom mechanism existed anywhere in the app (confirmed via grep for "zoom").

Implementation in `index.html`:
- Added a zoom control group (− / percentage label / + / Reset) to `#items-card`'s card-header toolbar, right of the 🖨 Print button.
- Wrapped the table's scroll container with `id="items-table-wrap"` (previously an unlabeled `<div style="overflow:auto;max-height:600px;">`) as the zoom target.
- New functions: `applyItemsZoom(pct)` sets `#items-table-wrap.style.zoom = pct/100` and updates the `#items-zoom-label` text; `zoomItemsTable(delta)` reads/writes the current percentage from `localStorage['sam_items_zoom']` (default 100), steps by 10 per click, clamps to **60%–150%**, and `delta === 0` (the Reset button) forces exactly 100%.
- Zoom **persists across reloads**: the app-init block (same block that calls `TableKit.initAll()` / `fixAllStickyHeaders()` / `applyBranding()`) now also calls `applyItemsZoom(parseInt(localStorage.getItem('sam_items_zoom'), 10) || 100)` on load.
- Deliberately used the CSS `zoom` property directly on the wrapper `<div>`, not a TableKit option — `table.css`/`table.js` are untouched, per the project's "never modify TableKit files" rule. `zoom` is Chromium/Edge-native; this is an internal admin tool so that's an acceptable tradeoff, but it won't work in Firefox if that's ever a real requirement — worth flagging if a user reports the buttons doing nothing.

### 3. `test.html` updated, confirmed green
Added a new suite `'Donated Items table — zoom in/out controls (this session)'` (4 assertions covering the toolbar controls, the clamped step/reset logic, the CSS-zoom-not-TableKit approach, and reload persistence). Deployed via `.\deploy.ps1 test.html`, then **confirmed green by the user** at https://etccapps.com/apps/sam/test.html before the checkpoint.

### 4. Checkpoint v5.4 (minor version bump)
Straightforward minor bump via `.\bump-version.ps1` (no `-Major` requested).

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`57f1957`) | Zoom controls + `applyItemsZoom()`/`zoomItemsTable()`; version bump to v5.4. No Home-metrics code changes (investigation only). |
| `test.html` | committed (`57f1957`) | New zoom-feature suite added |
| `PROJECT_STATUS.md` | this update | continuity doc, not app code |

---

## What was accomplished this session (checkpoint v5.1)

Short session, two independent threads of work against `starting-bid-list.php` and a new (ultimately removed) form.

### 1. `starting-bid-list.php` — Member Name column replaced with Donor Name
A quick follow-up correction: the Starting Bid List's "Member Name" column (sourced from `etcc_member_name`, the ETCC member who submitted the item) was replaced with a **Donor Name** column (`donor_name`, the actual item donor) — the list is meant to credit donors, not track which club member did the data entry. Column order is now **Item # / Category / Starting Bid / Donor Name / Description**, same `white-space:nowrap` treatment as before, just on the renamed/re-sourced column. `test.html`'s `starting-bid-list.php` suite (originally written "v4.8 session," predating the actual v5.0 ship) had two assertions referencing "Member Name" — both corrected to describe the current Donor Name column, with a note that this was a deliberate correction, not a bug.

### 2. Built, then fully reverted — `silent-auction-form.php`, a public item-donation form with no member picker
The user asked for "a public silent auction form very similar to the item donation form." After a clarifying `AskUserQuestion` (they picked **"Duplicate/rename of `add-item.php`"**), this was first built as an exact file copy of `add-item.php` → `silent-auction-form.php`, deployed and working identically.

The user then asked to change its title to "Public Item Donation" and remove the ETCC Member Name/Email fields. A second `AskUserQuestion` (should this apply to `add-item.php` too, or just the new file?) confirmed **only `silent-auction-form.php`** — `add-item.php` stays as the internal, member-picker version; the new file was meant to be the fully public one. The following changes were made to `silent-auction-form.php` only:
- Subtitle changed to "Public Item Donation" (title tag and on-page `<div class="sub">`).
- Removed the `$members` SQL lookup/sort block entirely (no longer needed).
- Removed `etccMemberName`/`memberEmail` from `$values`, the POST-field read loop, the "required" validation, the `$newItem` write (`etcc_member_name` key dropped from the item record), the confirmation-email row list, and the email-To override logic (previously the selected member's email took priority as the confirmation recipient — with the field gone, `emailTo` now always uses the Settings-configured `donationEmailTo` address).
- Removed the ETCC Member Name `<select>`, its "— choose —" member-list `<option>`s, the read-only Member Email `<input>`, and the `samFillMemberEmail()` JS that synced them.
- Updated the file's top comment block to describe it as a public-audience duplicate of `add-item.php` with the member fields stripped out, rather than reusing `add-item.php`'s original comment verbatim.

**Then immediately reverted**: the user said "remove the new form." Verified via grep that nothing else in the codebase referenced `silent-auction-form.php` (it was never wired into `index.html` or any other page — always a standalone bookmarkable URL, same as `add-item.php`), then:
- Deleted it from the live server directly via an FTP `DELE` command (same approach used historically to remove `donate-item.php` — `deploy.ps1` has no built-in remote-delete helper, so this was a manual `curl ... -Q "DELE silent-auction-form.php"` against `ftp.etccapps.com`), confirmed with a follow-up `curl` HEAD-equivalent request that `https://etccapps.com/apps/sam/silent-auction-form.php` now 404s.
- Deleted the local file.
- Since the file was created and removed within the same session **before ever being committed**, `git status` shows no trace of it — nothing to revert or clean up in git history.

**Net effect on `add-item.php` and `test.html`**: none — `add-item.php` was never touched, and `silent-auction-form.php` never had regression-suite coverage added (it existed only briefly, mid-session), so no test assertions needed removing either.

### 3. `test.html` updated, confirmed green
Only the two stale "Member Name" assertions in the `starting-bid-list.php` suite needed correcting (see #1 above) — no new suite was needed since the `silent-auction-form.php` detour left no lasting code to cover. Deployed via `.\deploy.ps1 test.html`, then **confirmed green by the user** at https://etccapps.com/apps/sam/test.html before the v5.1 checkpoint.

### 4. Checkpoint v5.1 (minor version bump)
Straightforward minor bump via `.\bump-version.ps1` (no `-Major` flag requested this time, unlike the prior v5.0 session).

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `starting-bid-list.php` | committed (`214ef54`) | Member Name column → Donor Name column |
| `test.html` | committed (`214ef54`) | Two stale "Member Name" assertions corrected to Donor Name |
| `index.html` | committed (`214ef54`) | Version bump to v5.1 only |
| `silent-auction-form.php` | created, then deleted (local + live server) — never committed | Public item-donation form with no member picker; built, refined, then removed same-session at explicit request. See write-up above if a similar request comes in again. |
| `PROJECT_STATUS.md` | this update | continuity doc, not app code |

---

## What was accomplished this session (checkpoint v5.0)

Built entirely from a single fresh-start feature request that then went through many small rounds of live, iterative feedback (each a one-line follow-up). Summarized in final end-state order, not literal chat order.

### 1. New feature — `starting-bid-list.php`, a printable Starting Bid List
The user asked for "a page listing items donated" with Print and Done buttons, showing item number, category, description, and a starting bid (reserve, or Starting Bid % × value if no reserve).

**First attempt (superseded within the session):** built as an in-app JS function `printStartingBidList()` on the Donated Items screen (`index.html`), wired to a new "🖨 Starting Bid List" toolbar button — generated the report into a popup window via `document.write()`, the same pattern `printDonatedItemsList()` already uses.

**Final design (what's actually shipped):** the user then asked to remove that button and said they needed a **URL** for the list instead. Since the popup-window approach has no bookmarkable address, this was rebuilt as a real standalone PHP page — `starting-bid-list.php` — following the exact pattern `add-item.php` already established:
- No password gate, no login (same explicit convention as `add-item.php`) — public, reachable directly at **https://etccapps.com/apps/sam/starting-bid-list.php**.
- Reads live data **server-side from the SQL `sam_store` table**, not from localStorage: looks up `sam_current_auction` to pick the right `sam_{auctionId}_items` key (falling back to `sam_items`), decodes that JSON blob, and reads `sam_settings` for `startingBidPct`.
- The in-app popup version (`printStartingBidList()` JS function and its toolbar button) was fully deleted from `index.html` once the standalone page replaced it — no orphaned code left behind, since it was a same-session addition-then-replacement rather than a persisted feature being retired.

### 2. Iterative refinement of `starting-bid-list.php` (all same-session follow-ups)
In the order requested:
- **Column order**: started as Item # / Category / Description / Starting Bid, then Starting Bid was moved to directly after Category (Item # / Category / Starting Bid / Description).
- **Member Name column added**, sourced from `etcc_member_name` (the same field `add-item.php`'s "ETCC Member Name" dropdown writes), inserted between Starting Bid and Description. Final column order: **Item # / Category / Starting Bid / Member Name / Description**.
- **Print sizing**: "make print wider, make form narrower" — interpreted as: constrain the on-screen content to a narrower column (`max-width` on the content) while widening the printed page. First implementation switched print to landscape orientation; a later request ("make form modular" — user clarified via `AskUserQuestion` this meant **"not full page"**) reverted print back to **portrait**, keeping the printed table the same narrower width as the screen view rather than stretching it edge-to-edge.
- **Nowrap columns**: Item #, Category, and Member Name given `white-space:nowrap` so they never wrap onto a second line (Starting Bid and Description still wrap normally).
- **Header text**: changed to `<h2>Silent Auction - Donated Items</h2>` with an intro line "The following items have been donated by our members." A "Printed: `<date/time>`" line was added and then removed again per a direct follow-up ("remove printed date and time from form").
- **Done button behavior**: originally `window.close()` with a `setTimeout` fallback to `location.href='index.html'` (matching `add-item.php`'s Done button, for the case where the tab wasn't opened via `window.open()` and can't be closed by script). Simplified to **`window.close()` only** per explicit request ("done should closed form") — this page is always reached directly by URL, so the index.html fallback wasn't wanted.
- **Floating card layout**: "make form floating page" — clarified via `AskUserQuestion` (user picked **"Card with shadow"**) to mean a centered white card (rounded corners, `box-shadow`, `max-width:700px`) floating over a light-gray page background, matching a common modern-form aesthetic. `@media print` strips the background/shadow/border-radius and expands the card to full width so the printed page doesn't waste ink on decoration that only makes sense on screen.

### Gotcha for future sessions: two `AskUserQuestion` clarifications were needed this session
Two requests in a row ("make form modular", "make form floating page") were ambiguous enough on their own that guessing wrong would have meant redoing the work — both were disambiguated with `AskUserQuestion` before implementing, rather than guessing. If a short, vague styling request comes in for this page again, it's worth pattern-matching against this history before assuming what it means.

### 3. `test.html` updated to match, confirmed green
Added one new suite, **`starting-bid-list.php — standalone Starting Bid List page (v4.8 session)`** (9 assertions), covering: the standalone/no-login page itself, the server-side `sam_store` data source, final column order, the Starting Bid formula (reserve-or-percentage, matching the bid-sheet convention), the nowrap columns, the header text change, the floating-card layout, portrait print sizing, and the Done button's close-only behavior. (Suite name says "v4.8" — written before the checkpoint version number was decided; the actual shipped version is v5.0. Harmless, but if a future session is grepping `test.html` by version number, note the mismatch.)

No stale assertions needed fixing — the in-app popup button that was briefly added to `index.html` and then removed left no net trace requiring a test update.

Deployed via `.\deploy.ps1 test.html`, then **confirmed green by the user** at https://etccapps.com/apps/sam/test.html before the v5.0 checkpoint proceeded.

### 4. Checkpoint v5.0 (major version bump)
The user explicitly asked to bump to **5.0** (not a minor bump) — done via `.\bump-version.ps1 -Major` mid-session, ahead of the formal `/ETCCSAMCheckpoint` invocation. The checkpoint skill correctly detected the version was already bumped and did not double-bump.

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `starting-bid-list.php` | new, committed (`5245137`) | Standalone public "Starting Bid List" page — see above for full column/layout history |
| `index.html` | committed (`5245137`) | Net change is just the version bump to v5.0 — the `printStartingBidList()` function and its toolbar button were added and then fully removed within this same session, so there's no trace of the popup-window approach left in the file |
| `test.html` | committed (`5245137`) | One new suite added (9 assertions) for `starting-bid-list.php`; no stale assertions found |
| `PROJECT_STATUS.md` | this update | continuity doc, not app code |

---

## What was accomplished this session (checkpoint v4.7)

Short, incremental session driven by the user reviewing the live Donated Items screen after the v4.6 checkpoint and flagging two follow-on issues. Nothing here was requested up front — it was found live, in order:

### 1. Removed the orphaned Add Item modal (resolves prior open item #3)
The v4.6 session had switched "+ Add Item" to open `add-item.php` in a new tab, leaving the old in-app modal (`#add-item-modal`) and its three functions (`openAddItemModal()`, `closeAddItemModal()`, `saveAddItemModal()`) orphaned but not deleted, per the project's "flag, don't delete" convention. This session confirmed via grep that nothing else in `index.html` referenced them, then deleted the modal's `<div>` block and all three functions outright.

### 2. Real bug — Donor Name overflow bleeding into Donor Email column
**Symptom reported (via screenshot):** the Donor Email cell for a long-donor-name row ("Wilderness Trail Distillery, Attn. Grayson Yaden") showed visually garbled/overlapping text. First assumed to be a data problem (bad paste, hidden Unicode bidi characters) or a screenshot/tooltip artifact — the user then confirmed via Edit mode that the underlying data was completely clean (`Grayson.Yaden@campari.com`), which ruled that out.

**Root cause, found by comparing sibling `<td>` styling:** in `refreshItemsTable()` (`index.html`), the Description and Category `<td>`s explicitly set `white-space:normal;word-break:break-word;vertical-align:top`, but the Donor Name and Donor Email `<td>`s (originally two lines down) had no such style — so under `table-layout:fixed`, a long Donor Name overflowed past its column's fixed width and visually overlapped the Donor Email cell next to it. This wasn't a data bug or a screenshot artifact at all; it only became visible once a sufficiently long donor name/address was entered (the `add-item.php` workflow introduced in v4.6 made long addresses common for the first time).

**Fix:** added the same `white-space:normal;word-break:break-word;vertical-align:top` styling to the Donor Name and Donor Email `<td>`s in `refreshItemsTable()`. Also widened both columns in `#items-table`'s `<colgroup>` (Donor Name 140px→260px in two steps per user follow-up request; Donor Email 190px→260px), bumping the table's `min-width` from 1576px→1766px to match.

### 3. Real bug — Donor Name/Email edit-mode inputs clipped long text
Once the *display* mode wrapped correctly, the *edit* mode (triggered by clicking "Edit") still used single-line `<input type="text">` elements for Donor Name and Donor Email in `editItemByNumber()`, which clip/scroll long values instead of wrapping — inconsistent with Description, which already used a `<textarea>`. Changed both to `<textarea>`, matching Description's pattern. This required a follow-on fix in `saveItemEdit()`: it read the new values via `querySelector('input')`, which no longer matched anything once the elements became `<textarea>`s (would have silently kept stale values on save) — updated to `querySelector('textarea')` for both fields.

### 4. `test.html` updated to match, confirmed green
- Corrected the now-stale v4.6-session assertion that claimed `#add-item-modal`/`openAddItemModal()` "still exist in the DOM but are no longer wired to any button" — now notes they were fully removed in this session.
- Added a new suite, `Donated Items table — orphaned Add Item modal removed, columns widened, donor overflow fixed (v4.7 session)`, covering all three fixes above.
- Deployed via `.\deploy.ps1 test.html`, then **confirmed green by the user** at https://etccapps.com/apps/sam/test.html before the checkpoint proceeded.

### Files touched this session
| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`61f0345`) | Add Item modal removal; Donor Name/Email `<td>` wrap fix + column widening; Donor Name/Email edit-mode `<textarea>` fix + matching `saveItemEdit()` fix; version bumped to v4.7 |
| `test.html` | committed (`61f0345`) | One stale assertion corrected, one new suite added (4 assertions); confirmed green by the user |
| `PROJECT_STATUS.md` | committed separately (`9c09762`, then this update) | continuity doc, not app code |

---

## What was accomplished this session (checkpoint v4.6)

This was a long, iterative session driven entirely by incremental UI/UX requests against the Step 1 screen and `add-item.php`, plus two real bugs discovered and fixed along the way. Summarized in the order the underlying *design* ended up in, not the literal chat order (which zig-zagged through several false starts — see "Design detours" below).

### 1. `deploy.ps1` — cache-busting on every deploy
Added `Update-CacheBust()`: stamps a fresh `?v=<epoch-seconds>` query string onto the four static asset links in `index.html` (`css/table.css`, `css/toolbar.css`, `js/table.js`, `js/toolbar.js`), replacing any existing `?v=...` rather than stacking (idempotent, same pattern as `Update-Version`'s deploy-date stamp). Wired into both the single-file (`.\deploy.ps1 index.html`) and full-deploy code paths, alongside `Update-Version`. Purpose: force browsers to fetch fresh CSS/JS instead of a stale cached copy after every deploy.

### 2. Step 1 — "Item Load" → "Donated Items" screen overhaul
The single biggest change this session. Final end state:
- **Renamed everywhere**: page header, Home screen workflow card (title + subtitle "View donated items"), the `screenNames` map used by `navigate()`, and the in-app User Manual's Step 1 section all now say "Donated Items" instead of "Item Load"/"Load Item Emails".
- **Gmail email-scan workflow retired from view, not deleted.** The Gmail connection status strip, "no client ID" warning, and the Inbox Emails card (Scan Emails / View All / Delete All, `#email-table`) are now wrapped in a `display:none` container. They could not be removed outright: several `document.getElementById('btn-scan').addEventListener(...)`-style calls elsewhere have **no null-guard**, so deleting the elements would throw at script load and break the whole page. `#btn-load-items` ("Update Items") is hidden the same way, for the same reason.
- **The separate "Donated Items" modal (`#donated-items-modal`) was removed entirely** — it was a short-lived design from earlier this session (a full-screen overlay mirroring Loaded Items, with its own checkbox/bulk-delete UI) that got superseded once the user clarified they wanted the *existing* Loaded Items table itself to carry that behavior, not a separate view. `openDonatedItemsModal()`, `closeDonatedItemsModal()`, `renderDonatedItemsTable()`, `selectAllDonatedItemRows()`, `deleteCheckedDonatedItems()`, and the `ITEM_EDIT_COLS_DONATED` column map are all gone. The original `#items-table`/`#items-tbody` (card header now says "Donated Items", was "Loaded Items") carries the checkbox column and bulk delete directly.
- **Checkbox column + bulk delete on the one remaining table**: every row has a `.item-row-check` checkbox (`data-item-number="..."`); a header "check all" checkbox (`#items-check-all-th`) toggles all rows via `selectAllItemRows(checked)`. **Gotcha discovered and fixed**: `TableKit.init()` rebuilds every `<th>`'s contents on init, which wiped this checkbox out on every `refreshItemsTable()` call (same issue the View All modal already had to work around). Fixed by re-injecting the checkbox into the header cell immediately after `TableKit.init(document.getElementById('items-table'))` runs.
- **Per-row Delete button removed** — Actions column is now Edit-only (+ conditional View when a scanned-email match exists, a vestige of the old workflow, harmless). Deletion is now bulk-only via a **Delete Item** button (`deleteCheckedItems()`), which collects checked `data-item-number`s, confirms once, filters them out, saves, and cleans up any orphaned winner records — mirrors what `deleteItemByNumber()` already did per-row.
- **"Date Loaded" column removed** entirely — from the `<colgroup>`/`<thead>`, from `refreshItemsTable()`'s row template, and from `ITEM_EDIT_COLS_MAIN`'s column-index map (shifted left by one: `category:3, desc:4, value:5, reserve:6, donorName:7, donorEmail:8, donorPhone:9, actions:10`). Table is now 12 columns (was 13, including the checkbox).
- **"View Categories" and "View All" buttons removed** from the toolbar (functions still exist, just unused here — `showViewAll` is still called elsewhere for emails/bid-sheets).
- **"Delete All" removed, replaced with a "🖨 Print" button** (`printDonatedItemsList()`) — opens a print-friendly list of all donated items via the same `openPrintWindow()` pattern already used by `printBiddersList()`/`printPaymentTable()`/etc. (`deleteAllItems()` is still defined but now unused.)
- **"Check All" / "Uncheck All" toolbar buttons removed** — the header checkbox is now the only toggle-all control (added originally alongside the buttons, then the buttons were removed once the header checkbox worked correctly).
- **"+ Add Item" now opens `add-item.php` in a new tab** (`window.open('add-item.php', '_blank')`) instead of the in-app modal — see open item #3 above re: the now-orphaned modal.
- **`add-item.php`'s "Cancel" button relabeled "Done"**, and its behavior changed from "just reload the same blank form" to `window.close(); setTimeout(() => location.href='index.html', 150);` — tries to close the tab (it was opened via script, so this works), falling back to navigating to `index.html` if the browser refuses.

### 3. Real bug #1 — multi-tab data loss (add-item.php inserts silently erased)
**Symptom reported:** an item added via the `add-item.php` form didn't show up in the app, even after navigating away and back.

**Root cause, found by tracing the actual save/sync code** (not by guessing): `navigate()` always calls `persistItemLoadScreenToDB()` when leaving the item-load screen, which does a **full overwrite** (`DB.saveItems()` → `save_items` action → deletes and re-inserts every row for that auction, in both the SQL `items` table and the `sam_store` key-value blob) using whatever items array is currently in the browser's memory. If `add-item.php` (now opened in a separate tab) inserted an item while the original SAM tab still held an older in-memory copy, switching back to that tab and navigating *anywhere* would push the stale array back out — silently erasing the item `add-item.php` had just written. This risk was actually already flagged in `add-item.php`'s own header comment, written back when Add Item only had an in-app-modal path with no separate-tab conflict — switching Add Item to open in its own tab (this session) is what made the risk real.

**Fix:** the app now re-syncs from the database automatically whenever the tab regains focus, reusing the existing `PageVisibilityManager.init()` `visibilitychange` handler (previously only used for session-timeout detection). Its "page visible again, session still valid" branch now also calls `syncFromKeyValueDB()`, then `refreshItemsTable()`/`refreshMetrics()` if the Donated Items screen is currently active — so switching back from the `add-item.php` tab refreshes the in-memory copy *before* any subsequent navigation can push a stale version back out.

### 4. Real bug #2 — Reserve Amount silently hidden when it had a "$" prefix
**Symptom reported:** after adding an item via `add-item.php`, its Reserve field wasn't populating in the table.

**Root cause:** `add-item.php`'s client-side `formatCurrency()` prepends a `$` to the Reserve Amount before submission (e.g. `"$75"`). Four separate render sites decided whether to show the Reserve column using a bare `parseFloat(item.reserve_amount) > 0` — and `parseFloat("$75")` returns `NaN` in JavaScript (it does not skip a leading `$`), so any reserve value carrying that prefix was silently treated as blank/zero. Items loaded the old way (Gmail scan, plain numeric reserve) never had a `$` prefix, which is exactly why this bug went unnoticed until `add-item.php` became the primary entry point this session.

**Fix:** switched all four sites — `refreshItemsTable()` (Donated Items table), `printDonatedItemsList()`, the Announce Winners table, and the View All-equivalent render path — plus the bid-sheet's `hasReserve` flag (governs whether the Reserve info box/column appears on printed bid sheets) to use the existing `parseMoney()` helper, which already strips `$`/`,` before parsing.

### 5. Total Value metric — reserve-or-value fallback
Per explicit user request: `refreshMetrics()`'s Total Value calculation now sums, per item, the **Reserve** amount if it's set and non-zero, otherwise the **Value** amount (previously always summed Value regardless of Reserve).

### 6. Settings screen — Email Field Mapping card and Clear Emails button removed
- **Email Field Mapping card removed entirely**: the card, `renderFieldMapTable()`/`editFieldMapRow()`/`saveFieldMapRow()`/`removeFieldMapRow()`, the `LOADED_ITEMS_COL`/`SELECT_BY_OPTIONS` constants, its `#field-map-table` CSS, and its User Manual mention are all gone. `DB.getFieldMap()`/`saveFieldMap()` (the data-layer functions) were left alone, since the still-present (orphaned) Gmail-scan email parser calls `DB.getFieldMap()`.
- **Gotcha caught before it shipped**: `renderFieldMapTable()` was called unconditionally on every Settings-screen load — leaving that call in place after removing its target table would have thrown (`tbody.innerHTML` on `null`) and broken the rest of Settings' load sequence (auction dropdown, favicon, settings-password field, etc.). Removed the call.
- **"Clear Emails" button removed** from Developer Tools, along with its `document.getElementById('btn-clear-emails').addEventListener(...)` call (same unguarded-null-ref risk, same fix).
- **Gmail OAuth card explicitly kept** — user was asked directly and confirmed keeping it, since it's still load-bearing for Announce Winners → Email Winners (see open item #4 above).

### Design detours worth knowing about (in case they look like unfinished work)
- Early in the session, "replace the Item Load form with the donated items form" went through **three rounds of clarification** before landing on the final design — the user first meant the Donated Items screen's manual-entry fields (not `add-item.php`, not the old Gmail-parsed fields), which is why the very first version of this change made the Add Item modal (already existing but previously unwired) the primary entry point, *before* a later request switched it to open `add-item.php` in a new tab instead.
- A short-lived intermediate design added a **separate** "Donated Items" modal (mirroring Loaded Items with its own checkbox/bulk-delete UI) before the user clarified they wanted that behavior folded directly into the existing Loaded Items table instead, with no separate modal. If a future session finds this confusing in git history, that's why — it was corrected within the same session, not left half-done.

---

## Checkpoint procedure (unchanged, still the standing convention)

1. Update `test.html` for whatever changed (skip if nothing test-relevant changed).
2. `.\deploy.ps1 test.html` if it changed.
3. **Ask the user** to manually run https://etccapps.com/apps/sam/test.html and report pass/fail (automated running is broken — see "Known issues" below). Do not proceed until they say it's green.
4. Once green: `.\bump-version.ps1` (minor bump by default; `-Major` flag for major bumps) **if not already bumped earlier in the session** — check the footer span first, don't double-bump. Then `.\deploy.ps1 index.html` (and any other changed files individually).
5. `git add` the changed files (never `git add -A`), commit with a `Checkpoint vX.Y: <short description>` message, `git push`. Commit and push **without asking** once tests are confirmed green.
6. Report the commit hash, version, and live URL back to the user.

Deploying individual files (`.\deploy.ps1 <file>`) happens continuously after every code change, **without being asked** — separate from the commit/checkpoint step. Never commit on every deploy — only at an explicit "checkpoint". Bare "test" (no other words) means **update** the regression suite only — never run it yourself.

**A bare "commit, and push"** (or invoking the separate, lighter-weight `ETCCCheckpoint` skill — a global agent skill, not part of this repo, shared with the CarShow project) skips the version bump and the test-green gate entirely. Use judgment on which the user actually means.

**Known issue #1 (still open):** automated regression test running from a Claude Code session is blocked — a bot-check/403 page intercepts any CDP-automated browser hitting the live site (Hostinger-hosted; earlier write-ups of this doc misattributed this to "Cloudflare" — this project has no Cloudflare in front of it, correct that if you see it elsewhere). Workaround: the user runs the suite manually and reports pass/fail verbally.

**Known issue #2 (RESOLVED as of 2026-08-31, v6.7/v6.8 session):** `deploy.ps1`'s FTP upload used to run via `curl.exe` and would intermittently fail (`curl: (56) response reading failed` or `curl: (18) ... got 450`) — with the file sometimes not actually updating on the server despite (or alongside) the reported failure, or despite a reported *success*. Root cause identified this session: `curl.exe` on this machine uses the Windows Schannel TLS backend, which has a bug against this Hostinger FTPS server — the transfer completes fully but curl can't read the server's final control-channel response. **`deploy.ps1` no longer uses curl at all** — `Deploy-File` now uses `System.Net.FtpWebRequest`, verified working across single-file and full-deploy modes with real `Last-Modified`-header checks. See open item #14 above for full detail. If deploy failures resurface, they are a *different* issue now — don't reach for the old curl/Hostinger-File-Manager workaround by reflex.

---

## Architecture notes not yet in CLAUDE.md

- **`rowCheckboxOffset(tr)`** (`index.html`, module-scope, near `ITEM_EDIT_COLS_MAIN`): returns `1` if a row's first `<td>` contains any `<input type="checkbox">`, else `0`. Used by `editItemByNumber()`/`saveItemEdit()` so cell-index lookups stay correct regardless of which table (Loaded/Donated Items' now-permanent checkbox, or View All's optional one) is being edited. Since Donated Items' checkbox is now permanent (not conditional), `ITEM_EDIT_COLS_MAIN`'s indices are consistently "un-shifted" positions with `off` always adding the checkbox offset on top for that table.
- **`VIEW_ALL_SELECTABLE.items.stripLeadingCol`** (`index.html`, `showViewAll()`): the View All modal clones `#items-table`'s rows and normally adds its *own* selection checkbox. Since Loaded/Donated Items now has a permanent leading checkbox of its own, this flag strips the source table's own checkbox cell/header from the clone first (guarded to skip the single-cell empty-state row) so the two don't stack into a doubled, misaligned column.
- **`PageVisibilityManager`** (`index.html`): originally only handled session-timeout-on-return-from-hidden. Its "page visible again" branch now also re-syncs from the database (`syncFromKeyValueDB()`) and refreshes the Donated Items screen if active — see "Real bug #1" above. Any future feature that opens app-adjacent pages in a separate tab (like `add-item.php`) benefits from this automatically; no per-feature wiring needed.
- **`deploy.ps1`'s `Update-CacheBust()`** (new this session): stamps `?v=<epoch-seconds>` onto `css/table.css`, `css/toolbar.css`, `js/table.js`, `js/toolbar.js` in `index.html` at deploy time. Idempotent — re-running replaces the existing `?v=...` rather than appending a duplicate.
- **`add-item.php`'s "Done" button** now does `window.close()` first, falling back to `location.href='index.html'` after 150ms if the tab wasn't closable (e.g. reached directly rather than via `window.open()` from the app).

---

## Files touched this session

| File | Status | Notes |
|---|---|---|
| `index.html` | committed (`8b32733`) | Donated Items screen overhaul (see above), multi-tab sync fix (`PageVisibilityManager`), Reserve Amount display fix (4 sites + bid-sheet `hasReserve`), Total Value reserve-or-value fallback, Settings Field Mapping/Clear Emails removal |
| `add-item.php` | committed (`8b32733`); also manually uploaded twice mid-session due to FTP failures | "Cancel" → "Done" button relabel + `window.close()`-then-fallback behavior |
| `deploy.ps1` | committed (`8b32733`) | New `Update-CacheBust()` function, wired into both deploy paths |
| `test.html` | committed (`8b32733`) | Substantially rewritten via `/ETCCSAMTest`: 3 fully-stale suites rewritten (old Donated Items modal design, Step 1 button positioning, item-editing cell indices), 6 new suites added (add-item.php Done button, multi-tab sync fix, Reserve Amount bug fix, Total Value fallback, Settings removals, deploy.ps1 cache-busting). Confirmed green by the user before the v4.6 checkpoint. |
| `PROJECT_STATUS.md` | this file, being committed now | continuity doc, not app code |
