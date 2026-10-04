<?php
require_once __DIR__ . '/config.php';

$pdo = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];
$input = getJsonInput();
$action = $_GET['action'] ?? $input['action'] ?? '';

// ─── LOGIN ─────────────────────────────────────────────────────────────
if ($method === 'POST' && ($action === 'login' || empty($action) && isset($input['password']))) {
    $email = trim($input['email'] ?? '');
    $password = $input['password'] ?? '';

    if (empty($email) || empty($password)) {
        sendResponse(false, null, 'Email and password are required', 400);
    }

    // Client IP Detection (Supports Cloudflare, Proxy, Direct)
    $ip = $_SERVER['HTTP_CF_CONNECTING_IP'] 
        ?? (explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'] ?? ''))[0] 
        ?? $_SERVER['REMOTE_ADDR'] 
        ?? '0.0.0.0';
    $ip = trim($ip);

    // ── Ensure Rate Limit Table Exists ──
    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS login_attempts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            ip_address VARCHAR(45) NOT NULL,
            email VARCHAR(191) NOT NULL,
            attempts INT DEFAULT 1,
            last_attempt DATETIME NOT NULL,
            INDEX idx_ip_attempt (ip_address, last_attempt),
            INDEX idx_email_attempt (email, last_attempt)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    } catch (Exception $e) {
        // Continue if table exists or cannot create
    }

    // ── Check Failed Attempts in Last 15 Minutes ──
    $lockoutWindow = 15; // minutes
    $maxAttempts = 5;

    $stmt = $pdo->prepare("SELECT attempts, last_attempt, TIMESTAMPDIFF(SECOND, last_attempt, NOW()) as seconds_since 
                           FROM login_attempts 
                           WHERE (ip_address = ? OR email = ?) AND last_attempt > DATE_SUB(NOW(), INTERVAL ? MINUTE)
                           ORDER BY attempts DESC LIMIT 1");
    $stmt->execute([$ip, $email, $lockoutWindow]);
    $attemptRecord = $stmt->fetch();

    if ($attemptRecord && (int)$attemptRecord['attempts'] >= $maxAttempts) {
        $remainingSeconds = ($lockoutWindow * 60) - (int)$attemptRecord['seconds_since'];
        $remainingMinutes = ceil(max(1, $remainingSeconds) / 60);
        sendResponse(false, null, "Too many failed login attempts. Access is locked for {$remainingMinutes} minute(s) for security.", 429);
    }

    // ── Verify User Credentials ──
    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
        // Record failed attempt
        if ($attemptRecord) {
            $newAttempts = (int)$attemptRecord['attempts'] + 1;
            $pdo->prepare("UPDATE login_attempts SET attempts = ?, last_attempt = NOW() WHERE ip_address = ? OR email = ?")
                ->execute([$newAttempts, $ip, $email]);
        } else {
            $newAttempts = 1;
            $pdo->prepare("INSERT INTO login_attempts (ip_address, email, attempts, last_attempt) VALUES (?, ?, 1, NOW())")
                ->execute([$ip, $email]);
        }

        $remaining = max(0, $maxAttempts - $newAttempts);
        $warnMsg = $remaining > 0 
            ? "Invalid email or password. ($remaining attempt(s) remaining before account lockout)."
            : "Invalid email or password. Maximum attempts exceeded. Account locked for 15 minutes.";

        sendResponse(false, null, $warnMsg, 401);
    }

    // ── Check if Account is Active ──
    if (isset($user['is_active']) && (int)$user['is_active'] === 0) {
        sendResponse(false, null, 'User account has been deactivated. Please contact an administrator.', 403);
    }

    // ── Login Successful: Clear Failed Attempts ──
    try {
        $pdo->prepare("DELETE FROM login_attempts WHERE ip_address = ? OR email = ?")->execute([$ip, $email]);
    } catch (Exception $e) {}

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

// ─── FORGOT PASSWORD (TIMING-ATTACK RESISTANT) ─────────────────────────
if ($method === 'POST' && ($action === 'forgot_password' || $action === 'forgot' || $action === 'reset_password')) {
    $startTime = microtime(true);
    $email = trim($input['email'] ?? '');

    if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        sendResponse(false, null, 'Please provide a valid email address', 400);
    }

    $ip = $_SERVER['HTTP_CF_CONNECTING_IP'] 
        ?? (explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'] ?? ''))[0] 
        ?? $_SERVER['REMOTE_ADDR'] 
        ?? '0.0.0.0';
    $ip = trim($ip);

    // Rate Limiting: Max 3 requests per 15 minutes per IP
    $lockoutWindow = 15;
    $maxForgotAttempts = 3;

    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS forgot_attempts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            ip_address VARCHAR(45) NOT NULL,
            email VARCHAR(191) NOT NULL,
            attempt_time DATETIME NOT NULL,
            INDEX idx_ip_forgot (ip_address, attempt_time)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM forgot_attempts 
                               WHERE ip_address = ? AND attempt_time > DATE_SUB(NOW(), INTERVAL ? MINUTE)");
        $stmt->execute([$ip, $lockoutWindow]);
        $rate = $stmt->fetch();
        if ($rate && (int)$rate['count'] >= $maxForgotAttempts) {
            sendResponse(false, null, 'Too many password reset requests. Please try again after 15 minutes.', 429);
        }

        $pdo->prepare("INSERT INTO forgot_attempts (ip_address, email, attempt_time) VALUES (?, ?, NOW())")->execute([$ip, $email]);
    } catch (Exception $e) {}

    // Check if user exists and is active
    $stmt = $pdo->prepare("SELECT id, uid, name, email, is_active FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if ($user && (!isset($user['is_active']) || (int)$user['is_active'] === 1)) {
        // Generate secure 8-character temporary password
        $tempPassword = 'Rm#' . strtoupper(bin2hex(random_bytes(3)));
        $newHash = password_hash($tempPassword, PASSWORD_BCRYPT);

        // Update in database
        $updateStmt = $pdo->prepare("UPDATE users SET password_hash = ? WHERE id = ?");
        $updateStmt->execute([$newHash, $user['id']]);

        // Send Email via Hostinger Mail
        $userName = htmlspecialchars($user['name'] ?? 'User');
        $subject = "Your Temporary Login Password - RituMita Boutique";
        $to = $user['email'];

        $headers  = "MIME-Version: 1.0\r\n";
        $headers .= "Content-Type: text/html; charset=UTF-8\r\n";
        $headers .= "From: RituMita Boutique <noreply@ritumitasrentaljewels.com>\r\n";
        $headers .= "Reply-To: support@ritumitasrentaljewels.com\r\n";
        $headers .= "X-Mailer: PHP/" . phpversion();

        $message = "
        <html>
        <body style='font-family: Arial, sans-serif; background-color: #F7F3EA; padding: 20px;'>
            <div style='max-width: 500px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 8px; border: 1px solid #D8CFC0;'>
                <h2 style='color: #262220; text-align: center; margin-bottom: 20px;'>RituMita Boutique</h2>
                <p>Hello <strong>{$userName}</strong>,</p>
                <p>A temporary password request was received for your account.</p>
                <div style='background-color: #FAF6F0; padding: 15px; border-left: 4px solid #8A8078; margin: 20px 0; text-align: center;'>
                    <span style='font-size: 13px; color: #666;'>Your Temporary Password:</span><br/>
                    <strong style='font-size: 22px; letter-spacing: 2px; color: #9A2143;'>{$tempPassword}</strong>
                </div>
                <p style='font-size: 13px; color: #666;'>Please login using this temporary password and update your password immediately in Settings / User Profile.</p>
                <p style='font-size: 12px; color: #999; margin-top: 25px; border-top: 1px solid #eee; padding-top: 10px;'>If you did not request this, please contact your administrator immediately.</p>
            </div>
        </body>
        </html>
        ";

        @mail($to, $subject, $message, $headers);
    } else {
        // Run dummy hash to equalize processing time and prevent timing attacks
        password_hash('DummyPassword123!', PASSWORD_BCRYPT);
    }

    // Timing attack mitigation: ensure execution time is uniform (at least 600ms)
    $elapsed = (microtime(true) - $startTime) * 1000000;
    if ($elapsed < 600000) {
        usleep(600000 - (int)$elapsed);
    }

    // Always return the exact same generic message (User Enumeration Protection)
    sendResponse(true, null, 'If this email is registered in our system, a temporary password has been sent to your inbox.');
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
    if (isset($input['email'])) { $fields[] = "email = ?"; $params[] = $input['email']; }
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
