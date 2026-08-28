<?php
// Standalone "Starting Bid List" page — bookmarkable URL, no login required
// (same pattern as add-item.php). Read-only: lists every donated item with
// its starting bid, computed the same way as the app's bid sheets:
//   - Open-bid item (reserve if set, else value, is <= Settings > Open Bids):
//     Reserve Amount if set, else $1
//   - Otherwise Reserve Amount if set and non-zero
//   - Otherwise Item Value x Starting Bid % (Settings > Auction Setup)
// Keep this in sync with printBiddingSheets() in index.html — the two must
// agree or the printed sheet will contradict this list.

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
date_default_timezone_set('America/New_York');

$CATEGORIES = [
    '100' => 'General Auto Repair / Car Items',
    '200' => 'Corvette Items',
    '300' => "Men's Items",
    '400' => "Women's Items",
    '500' => 'General Household',
    '600' => 'Framed Artwork or other Artwork to be Hung',
    '700' => 'Baskets / Gift Sets',
    '800' => 'Gift Certificates',
    '900' => 'Miscellaneous / Other',
];

function sbl_load_env($envFile) {
    $env = [];
    if (file_exists($envFile)) {
        foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            $line = trim($line);
            if ($line === '' || $line[0] === '#' || strpos($line, '=') === false) continue;
            [$k, $v] = explode('=', $line, 2);
            $env[trim($k)] = trim($v);
        }
    }
    return $env;
}
$env = sbl_load_env(__DIR__ . '/.env');

try {
    $pdo = new PDO(
        "mysql:host={$env['DB_HOST']};dbname={$env['DB_NAME']};charset=utf8mb4",
        $env['DB_USER'], $env['DB_PASS'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 5, PDO::ATTR_EMULATE_PREPARES => false]
    );
} catch (Exception $e) {
    error_log('[starting-bid-list] DB connect failed: ' . $e->getMessage());
    http_response_code(500);
    die('Database connection error.');
}

$auctionId = (string)($pdo->query("SELECT `value` FROM sam_store WHERE `key` = 'sam_current_auction' LIMIT 1")->fetchColumn() ?: '');
$itemsKey = $auctionId !== '' ? "sam_{$auctionId}_items" : 'sam_items';

$rawItems = $pdo->prepare("SELECT `value` FROM sam_store WHERE `key` = ?");
$rawItems->execute([$itemsKey]);
$items = json_decode((string)$rawItems->fetchColumn(), true) ?: [];

$rawSettings = $pdo->query("SELECT `value` FROM sam_store WHERE `key` = 'sam_settings' LIMIT 1")->fetchColumn();
$settings = $rawSettings ? (json_decode($rawSettings, true) ?: []) : [];
$startingBidPct = isset($settings['startingBidPct']) && $settings['startingBidPct'] !== '' ? (float)$settings['startingBidPct'] : 30;
// Max declared value (reserve unset) that still counts as an open-bid item.
// An explicit 0 disables the category, matching the app; only a missing/blank
// setting falls back to the $35 default.
$openBidMax = isset($settings['openBidMax']) && $settings['openBidMax'] !== ''
    ? (float)preg_replace('/[^0-9.]/', '', (string)$settings['openBidMax'])
    : 35;

function sbl_money($n) {
    return '$' . number_format((float)$n, 0);
}

usort($items, fn($a, $b) => strnatcasecmp((string)($a['item_number'] ?? ''), (string)($b['item_number'] ?? '')));
?>
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Starting Bid List</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 0; color: #1d1d1f; background: #e5e5ea; min-height: 100vh; padding: 32px 16px; box-sizing: border-box; }
  .card { max-width: 900px; margin: 0 auto; background: #fff; border-radius: 12px; box-shadow: 0 4px 24px rgba(0,0,0,0.12); padding: 28px 32px; }
  h2 { margin: 0 0 4px; }
  .sub { font-size: 13px; color: #555; margin-bottom: 16px; }
  table { width: 100%; border-collapse: collapse; font-size: 12px; table-layout: fixed; }
  th { background: #dbeafe; padding: 6px 8px; text-align: left; border: 1px solid #000; font-weight: 600; }
  td { padding: 4px 8px; border: 1px solid #ccc; word-break: break-word; }
  tr:nth-child(even) td { background: #f0f7ff; }
  @media print {
    button { display: none; }
    body { background: #fff; padding: 0; }
    .card { box-shadow: none; border-radius: 0; padding: 0; max-width: none; }
    @page { size: portrait; margin: 0.4in; }
  }
</style>
</head>
<body>
<div class="card">
  <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px;">
    <div>
      <h2>Silent Auction - Donated Items</h2>
      <div class="sub">The following items have been donated by our members.</div>
    </div>
    <div style="display:flex;gap:8px;">
      <button onclick="window.print()" style="padding:6px 16px;background:#0071e3;color:#fff;border:none;border-radius:6px;cursor:pointer;font-size:13px;">🖨 Print</button>
      <button onclick="window.close();" style="padding:6px 16px;background:#e0e0e0;color:#1d1d1f;border:none;border-radius:6px;cursor:pointer;font-size:13px;">Done</button>
    </div>
  </div>
  <table>
    <colgroup>
      <col style="width:7%;">
      <col style="width:24%;">
      <col style="width:8%;">
      <col style="width:14%;">
      <col style="width:47%;">
    </colgroup>
    <thead><tr><th style="white-space:nowrap;">Item #</th><th>Category</th><th>Starting Bid</th><th>Donor Name</th><th>Description</th></tr></thead>
    <tbody>
<?php foreach ($items as $item):
    $reserve = (float)preg_replace('/[^0-9.]/', '', (string)($item['reserve_amount'] ?? '0'));
    $value   = (float)preg_replace('/[^0-9.]/', '', (string)($item['item_value'] ?? ($item['value'] ?? '0')));
    // Open-bid item: the amount that would otherwise be its starting bid
    // (reserve if set, else declared value) is at or below the Open Bids
    // threshold — a reserve counts toward this now, not just an unreserved
    // low-value item. Starting bid is then the reserve amount if set, else
    // $1. See the header comment above.
    $openBidCheckAmt = $reserve > 0 ? $reserve : $value;
    $isOpenBid = $openBidCheckAmt <= $openBidMax;
    $startingBid = $reserve > 0 ? $reserve : ($isOpenBid ? 1 : ($value * $startingBidPct / 100));
    $catCode = (string)($item['category_code'] ?? '');
    $catName = $item['category_name'] ?? ($CATEGORIES[$catCode] ?? '');
?>
    <tr>
      <td style="white-space:nowrap;"><?= htmlspecialchars((string)($item['item_number'] ?? '')) ?></td>
      <td><?= htmlspecialchars($catCode) ?> — <?= htmlspecialchars((string)$catName) ?></td>
      <td><?= sbl_money($startingBid) ?></td>
      <td><?= htmlspecialchars((string)($item['donor_name'] ?? '')) ?></td>
      <td><?= htmlspecialchars((string)($item['description'] ?? '')) ?></td>
    </tr>
<?php endforeach; ?>
    </tbody>
  </table>
</div>
</body>
</html>
