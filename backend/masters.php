<?php
require_once __DIR__ . '/config.php';

$pdo = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];
$type = $_GET['type'] ?? '';

// ─── GET MASTER ITEMS ──────────────────────────────────────────────────
if ($method === 'GET') {
    if (!empty($type)) {
        $stmt = $pdo->prepare("SELECT name FROM master_items WHERE type = ? ORDER BY name ASC");
        $stmt->execute([$type]);
        $items = $stmt->fetchAll(PDO::FETCH_COLUMN);
        sendResponse(true, $items);
    } else {
        // Return all grouped by type
        $stmt = $pdo->query("SELECT type, name FROM master_items ORDER BY type, name ASC");
        $all = $stmt->fetchAll();
        $grouped = [];
        foreach ($all as $row) {
            $grouped[$row['type']][] = $row['name'];
        }
        sendResponse(true, $grouped);
    }
}

// ─── ADD MASTER ITEM ───────────────────────────────────────────────────
if ($method === 'POST') {
    $input = getJsonInput();
    $type = $input['type'] ?? $type;
    $name = trim($input['name'] ?? '');

    if (empty($type) || empty($name)) {
        sendResponse(false, null, 'Type and name required', 400);
    }

    $stmt = $pdo->prepare("INSERT IGNORE INTO master_items (type, name) VALUES (?, ?)");
    $stmt->execute([$type, $name]);

    sendResponse(true, ['type' => $type, 'name' => $name], 'Item added');
}

// ─── RENAME MASTER ITEM ────────────────────────────────────────────────
if ($method === 'PUT') {
    $input = getJsonInput();
    $type = $input['type'] ?? $type;
    $oldName = trim($input['oldName'] ?? '');
    $newName = trim($input['newName'] ?? '');

    if (empty($type) || empty($oldName) || empty($newName)) {
        sendResponse(false, null, 'Type, oldName, and newName required', 400);
    }

    $stmt = $pdo->prepare("UPDATE master_items SET name = ? WHERE type = ? AND name = ?");
    $stmt->execute([$newName, $type, $oldName]);

    sendResponse(true, null, 'Item renamed');
}

// ─── DELETE MASTER ITEM ────────────────────────────────────────────────
$action = $_GET['action'] ?? '';
if ($method === 'DELETE' || ($method === 'POST' && $action === 'delete')) {
    $type = $_GET['type'] ?? (getJsonInput()['type'] ?? '');
    $name = $_GET['name'] ?? (getJsonInput()['name'] ?? '');

    if (empty($type) || empty($name)) {
        sendResponse(false, null, 'Type and name required', 400);
    }

    $stmt = $pdo->prepare("DELETE FROM master_items WHERE type = ? AND name = ?");
    $stmt->execute([$type, $name]);

    sendResponse(true, null, 'Item deleted');
}

sendResponse(false, null, 'Invalid request', 400);
