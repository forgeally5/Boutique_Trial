<?php
require_once __DIR__ . '/config.php';

$pdo = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

// ─── LOGIN ─────────────────────────────────────────────────────────────
if ($method === 'POST' && $action === 'login') {
    $input = getJsonInput();
    $email = trim($input['email'] ?? '');
    $password = $input['password'] ?? '';

    if (empty($email) || empty($password)) {
        sendResponse(false, null, 'Email and password are required', 400);
    }

    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
        sendResponse(false, null, 'Invalid email or password', 401);
    }


    if (isset($user['is_active']) && (int)$user['is_active'] === 0) {
        sendResponse(false, null, 'User account is deactivated', 403);
    }

    $token = generateToken([
        'id'    => $user['id'] ?? 1,
        'uid'   => $user['uid'] ?? 'admin_root',
        'email' => $user['email'] ?? $email,
        'role'  => $user['role'] ?? 'Admin',
        'name'  => $user['name'] ?? 'Super Admin'
    ]);

    unset($user['password_hash']);
    sendResponse(true, [
        'token' => $token,
        'user'  => $user
    ], 'Login successful');
}

// ─── GET CURRENT USER INFO OR ALL USERS ────────────────────────────────
if ($method === 'GET') {
    if ($action === 'all') {
        $stmt = $pdo->query("SELECT id, uid, name, email, phone, role, is_active, permissions, created_at FROM users ORDER BY id ASC");
        $users = $stmt->fetchAll();
        sendResponse(true, $users);
    }

    $userPayload = validateToken();
    if (!$userPayload) {
        sendResponse(false, null, 'Unauthorized', 401);
    }

    $stmt = $pdo->prepare("SELECT id, uid, name, email, phone, role, is_active, permissions, created_at FROM users WHERE id = ?");
    $stmt->execute([$userPayload['id']]);
    $user = $stmt->fetch();

    sendResponse(true, $user);
}

// ─── CREATE / REGISTER USER ────────────────────────────────────────────
if ($method === 'POST' && ($action === 'register' || $action === 'create')) {
    $input = getJsonInput();
    $name = trim($input['name'] ?? '');
    $email = trim($input['email'] ?? '');
    $password = $input['password'] ?? 'Boutique@123';
    $role = $input['role'] ?? 'Staff';
    $phone = $input['phone'] ?? '';
    $uid = $input['uid'] ?? ('user_' . time() . '_' . rand(100, 999));
    $permissions = isset($input['permissions']) ? json_encode($input['permissions']) : null;

    if (empty($name) || empty($email)) {
        sendResponse(false, null, 'Name and email are required', 400);
    }

    $hash = password_hash($password, PASSWORD_BCRYPT);

    $stmt = $pdo->prepare("INSERT INTO users (uid, name, email, phone, role, password_hash, permissions) VALUES (?, ?, ?, ?, ?, ?, ?)");
    try {
        $stmt->execute([$uid, $name, $email, $phone, $role, $hash, $permissions]);
        $newId = $pdo->lastInsertId();
        sendResponse(true, ['id' => $newId, 'uid' => $uid], 'User created successfully', 201);
    } catch (PDOException $e) {
        sendResponse(false, null, 'User creation failed: ' . $e->getMessage(), 400);
    }
}

// ─── UPDATE USER ───────────────────────────────────────────────────────
if ($method === 'PUT' || ($method === 'POST' && $action === 'update')) {
    $input = getJsonInput();
    $uid = $input['uid'] ?? '';
    if (empty($uid)) {
        sendResponse(false, null, 'User UID required', 400);
    }

    $fields = [];
    $params = [];

    if (isset($input['name'])) { $fields[] = "name = ?"; $params[] = $input['name']; }
    if (isset($input['phone'])) { $fields[] = "phone = ?"; $params[] = $input['phone']; }
    if (isset($input['role'])) { $fields[] = "role = ?"; $params[] = $input['role']; }
    if (isset($input['is_active'])) { $fields[] = "is_active = ?"; $params[] = (int)$input['is_active']; }
    if (isset($input['permissions'])) { $fields[] = "permissions = ?"; $params[] = json_encode($input['permissions']); }
    if (!empty($input['password'])) {
        $fields[] = "password_hash = ?";
        $params[] = password_hash($input['password'], PASSWORD_BCRYPT);
    }

    if (empty($fields)) {
        sendResponse(false, null, 'No fields to update', 400);
    }

    $params[] = $uid;
    $sql = "UPDATE users SET " . implode(', ', $fields) . " WHERE uid = ?";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    sendResponse(true, null, 'User updated successfully');
}

// ─── DELETE USER ───────────────────────────────────────────────────────
if ($method === 'DELETE' || ($method === 'POST' && $action === 'delete')) {
    $input = getJsonInput();
    $uid = $_GET['uid'] ?? $input['uid'] ?? '';
    if (empty($uid)) {
        sendResponse(false, null, 'UID required', 400);
    }

    $stmt = $pdo->prepare("DELETE FROM users WHERE uid = ?");
    $stmt->execute([$uid]);

    sendResponse(true, null, 'User deleted');
}

sendResponse(false, null, 'Invalid request', 400);
