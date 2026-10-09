<?php
require_once __DIR__ . '/config.php';

$pdo = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];
$key = $_GET['key'] ?? '';

// ─── GET SETTING ───────────────────────────────────────────────────────
if ($method === 'GET') {
    if (!empty($key)) {
        $stmt = $pdo->prepare("SELECT setting_value FROM settings WHERE setting_key = ?");
        $stmt->execute([$key]);
        $val = $stmt->fetchColumn();
        if ($val !== false) {
            sendResponse(true, json_decode($val, true));
        } else {
            sendResponse(false, null, 'Setting not found', 404);
        }
    } else {
        $stmt = $pdo->query("SELECT setting_key, setting_value FROM settings");
        $all = [];
        while ($row = $stmt->fetch()) {
            $all[$row['setting_key']] = json_decode($row['setting_value'], true);
        }
        sendResponse(true, $all);
    }
}

// ─── SAVE / UPDATE SETTING ─────────────────────────────────────────────
if ($method === 'POST' || $method === 'PUT') {
    $user = validateToken();
    if (!$user) {
        sendResponse(false, null, 'Unauthorized. Please login.', 401);
    }

    $input = getJsonInput();
    $key = $input['key'] ?? $key;
    $value = $input['value'] ?? $input;

    if (empty($key)) {
        sendResponse(false, null, 'Setting key is required', 400);
    }

    $stmt = $pdo->prepare("INSERT INTO settings (setting_key, setting_value) VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = NOW()");
    $stmt->execute([$key, json_encode($value)]);

    sendResponse(true, null, 'Setting saved successfully');
}

sendResponse(false, null, 'Invalid request', 400);
