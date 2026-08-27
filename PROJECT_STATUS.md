# SAM Project Status

**Last updated:** 2026-08-27 — **checkpoint v6.0** (major bump, user-requested): added an **Open Bids** category (low-value items with no reserve get a $1 opening bid and no preprinted increments), guaranteed every preprinted bid row is **strictly larger than the previous one**, aligned `starting-bid-list.php` with the new bid math, and fixed two real UI bugs (Home Auctions panel needing a hard refresh after login; the Developer nav row closing the drawer out from under its own submenu). `test.html` updated, confirmed green by the user, checkpointed.

This file exists so a brand-new Claude Code session can resume this work with zero prior conversation context. Read this alongside `CLAUDE.md` (architecture/rules) before touching code.

---

## Current state (as of this doc)

- **Deployed version:** **v6.0** (`index.html` footer `#app-version`) — deployed code matches the latest checkpoint commit, no drift. Major bump was explicitly requested by the user (`/ETCCSAMCheckpoint v6.0`), reached via `.\bump-version.ps1 -Major` from v5.4.
- **Git:** `main` branch, last commit `7f31481` ("Checkpoint v6.0: Open Bids category, rising bid ladder, login and nav fixes"), pushed to `origin` (https://github.com/ETCCRepo/ETCCSAM.git). Working tree is clean.
- **Regression suite (`test.html`) was updated this session and confirmed green by the user** before the v6.0 checkpoint.
- **No uncommitted app-code work** as of this doc.

### ⚠️ Open items carried into the next session

1. **The settings-password "corrupted again" investigation from several sessions ago is still not conclusively closed.** The working theory (a transcription/autofill issue at the password prompt, not a code bug) was never confirmed — the user was given a console snippet to bypass manual typing and confirm it, but no result was ever reported. If it resurfaces, start by asking whether that bypass test was ever tried, rather than re-diagnosing from scratch.
2. **`api.php`/`add-item.php` deploys via `deploy.ps1` have been intermittently unreliable in past sessions** (`curl: (56)`/`curl: (18) ... got 450`) — manual upload via Hostinger File Manager is the fallback that has worked. This session's `deploy.ps1` calls all reported success with no retries needed, but keep verifying with a diff/marker check if a deploy ever looks suspicious.
3. **The Gmail-scan workflow's UI is hidden (`display:none`), not deleted**, and a large amount of supporting JS (OAuth token handling, inbox scanning, `parseEmailBody()`/`DEFAULT_FIELD_MAP`-driven parsing) remains in `index.html`, unreferenced by any visible UI. It couldn't be fully removed because the **Gmail OAuth Settings card is still load-bearing** — it configures the same Gmail API connection used by the currently-working **Announce Winners → Email Winners** feature (`sendWinnerEmails()` → `sendEmailsViaGmail()`). A future session could cleanly split "Gmail auth for sending" from "Gmail scanning for inbox import" if the scanning code is ever confirmed permanently dead.
4. **`donate-item.php` remains fully removed** (unchanged from prior sessions) — `add-item.php` is the only item-donation entry point. Its old SQL-side backend (`donated_items_pending` table, `get_pending_donations`/`mark_donations_imported` in `api.php`) is still there, unused, per the same convention.
5. **`starting-bid-list.php` has no password gate**, matching `add-item.php`'s convention — anyone with the URL can view the full donated-items list with donor names and starting bids. This was not explicitly discussed as a security tradeoff; flag it if the club raises privacy concerns about donor names being publicly listable.
6. **⚠️ The starting-bid calculation now exists in TWO places that must be kept in sync** (new in v6.0): `printBiddingSheets()` in `index.html` (JS) and `starting-bid-list.php` (PHP). Both implement the same three-branch rule — open-bid → $1, else reserve if set, else value × Starting Bid %. A comment at the top of the PHP file cross-references the JS function. **If you change the bid math, change both**, or the printed sheet will silently contradict the Starting Bid List — which is exactly the drift the v6.0 session had to correct.
7. **PHP files cannot be syntax-checked locally** — `php` is not on PATH in this environment (`php -l` fails with "command not found"). Edits to `starting-bid-list.php` / `add-item.php` / `api.php` are verified by inspection only, then confirmed by loading the live page. Be especially careful with PHP 8 rules that older PHP tolerated — e.g. **nested ternaries must be explicitly parenthesized** or the file fatals on load.
8. **A near-duplicate of `add-item.php` was created and fully removed in the v5.1 session** (`silent-auction-form.php` — see that session's write-up below). If a future request sounds like "make a public version of the item donation form without the member picker," check this history first rather than rebuilding from scratch, since the exact diff needed (remove `etccMemberName`/`memberEmail` from validation, DB write, confirmation email, and the HTML form/JS) is already documented below.
9. **The "Bidders: 17 vs. 25" Home/Registrations mismatch (v5.4 session) was explained but not confirmed fixed.** The user was asked to hard-refresh and re-compare Home vs. the Registrations screen; no confirmation came back before that session ended. If raised again, check whether it's simply the "Home tile only refreshes on `navigate('home')`" staleness, or genuine sync drift between localStorage and the MySQL backend (`[[project_data_sync_architecture]]`) — don't assume it's resolved. See the v5.4 write-up below for the full diagnosis.

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

**Known issue #1 (still open):** automated regression test running from a Claude Code session is blocked — Cloudflare challenges any CDP-automated browser with a 403 bot-check page. Workaround: the user runs the suite manually and reports pass/fail verbally.

**Known issue #2 (intermittent, not fully resolved — now confirmed to affect more than `api.php`):** `deploy.ps1`'s curl-based FTP upload sometimes fails (`curl: (56) response reading failed` or `curl: (18) ... got 450`), and the file doesn't actually update on the server despite (or alongside) the reported failure. This session hit it **repeatedly on `add-item.php`** (two separate rounds, 3 and 4 consecutive failures respectively) in addition to the previously-documented `api.php` occurrences. Verify with a diff/marker check when it matters — don't trust a reported failure OR success at face value. Manual upload via Hostinger File Manager is the fallback that has worked every time so far.

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
