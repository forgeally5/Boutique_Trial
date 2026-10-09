<?php
require_once __DIR__ . '/config.php';

$pdo = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

// ─── GET VENDOR ISSUES ─────────────────────────────────────────────────
if ($method === 'GET') {
    $stmt = $pdo->query("SELECT * FROM vendor_issues ORDER BY issue_date DESC");
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['items'] = json_decode($r['items'] ?? '[]', true);
    }
    sendResponse(true, $rows);
}

// ─── CREATE VENDOR ISSUE ───────────────────────────────────────────────
if ($method === 'POST' && ($action === '' || $action === 'create')) {
    $user = validateToken();
    if (!$user) {
        sendResponse(false, null, 'Unauthorized. Please login.', 401);
    }

    $input = getJsonInput();
    $docId = $input['docId'] ?? $input['doc_id'] ?? ('issue_' . time() . '_' . rand(100, 999));
    $vendorName = trim($input['vendorName'] ?? $input['vendor_name'] ?? '');

    if (empty($vendorName)) {
        sendResponse(false, null, 'vendorName is required', 400);
    }

    $issueDate = !empty($input['issueDate']) 
        ? date('Y-m-d H:i:s', is_numeric($input['issueDate']) ? $input['issueDate'] / 1000 : strtotime($input['issueDate']))
        : date('Y-m-d H:i:s');

    $stmt = $pdo->prepare("INSERT INTO vendor_issues (doc_id, vendor_name, issue_date, status, items, total_amount, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([
        $docId,
        $vendorName,
        $issueDate,
        $input['status'] ?? 'Pending',
        json_encode($input['items'] ?? []),
        (float)($input['totalAmount'] ?? $input['total_amount'] ?? 0),
        $input['notes'] ?? ''
    ]);

    sendResponse(true, ['docId' => $docId], 'Vendor issue recorded', 201);
}

// ─── UPDATE VENDOR ISSUE ───────────────────────────────────────────────
if ($method === 'PUT' || ($method === 'POST' && $action === 'update')) {
    $user = validateToken();
    if (!$user) {
        sendResponse(false, null, 'Unauthorized. Please login.', 401);
    }

    $input = getJsonInput();
    $docId = $input['docId'] ?? $input['doc_id'] ?? '';
    if (empty($docId)) {
        sendResponse(false, null, 'docId is required', 400);
    }

    $fields = [];
    $params = [];

    if (isset($input['status'])) { $fields[] = "status = ?"; $params[] = $input['status']; }
    if (isset($input['notes'])) { $fields[] = "notes = ?"; $params[] = $input['notes']; }
    if (isset($input['items'])) { $fields[] = "items = ?"; $params[] = json_encode($input['items']); }
    if (isset($input['totalAmount'])) { $fields[] = "total_amount = ?"; $params[] = (float)$input['totalAmount']; }

    if (empty($fields)) {
        sendResponse(false, null, 'No fields to update', 400);
    }

    $params[] = $docId;
    $stmt = $pdo->prepare("UPDATE vendor_issues SET " . implode(', ', $fields) . ", updated_at = NOW() WHERE doc_id = ?");
    $stmt->execute($params);

    sendResponse(true, null, 'Vendor issue updated');
}

// ─── DELETE VENDOR ISSUE ───────────────────────────────────────────────
if ($method === 'DELETE' || ($method === 'POST' && $action === 'delete')) {
    $user = validateToken();
    if (!$user) {
        sendResponse(false, null, 'Unauthorized. Please login.', 401);
    }

    $docId = $_GET['docId'] ?? (getJsonInput()['docId'] ?? '');
    if (empty($docId)) {
        sendResponse(false, null, 'docId is required', 400);
    }

    $stmt = $pdo->prepare("DELETE FROM vendor_issues WHERE doc_id = ?");
    $stmt->execute([$docId]);

    sendResponse(true, null, 'Vendor issue deleted');
}

sendResponse(false, null, 'Invalid request', 400);
