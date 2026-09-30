<?php
// =====================================================================
// RituMita Boutique Backend Configuration Template
// Copy this file to config.php and update with your actual credentials.
// =====================================================================

// Allow Cross-Origin Requests
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Database Credentials (Set these in your private config.php)
define('DB_HOST', getenv('DB_HOST') ?: 'localhost');
define('DB_NAME', getenv('DB_NAME') ?: 'u519811289_boutique');
define('DB_USER', getenv('DB_USER') ?: 'u519811289_ritumita');
define('DB_PASS', getenv('DB_PASS') ?: 'YOUR_SECURE_DB_PASSWORD');
define('JWT_SECRET', getenv('JWT_SECRET') ?: 'YOUR_SECURE_JWT_SECRET');

// Establish PDO Connection
function getDbConnection() {
    static $pdo = null;
    if ($pdo === null) {
        try {
            $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4";
            $options = [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ];
            $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            http_response_code(500);
            echo json_encode([
                'success' => false,
                'message' => 'Database connection failed: ' . $e->getMessage()
            ]);
            exit();
        }
    }
    return $pdo;
}

// Standard JSON Response Helper
function sendResponse($success, $data = null, $message = '', $statusCode = 200) {
    http_response_code($statusCode);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data'    => $data
    ]);
    exit();
}

// Helper to get JSON input from request body
function getJsonInput() {
    $raw = file_get_contents('php://input');
    return json_decode($raw, true) ?? [];
}

// Simple Base64URL-encoded JWT Generator
function generateToken($payload) {
    $header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));

    $payload['exp'] = time() + (86400 * 30); // 30 days expiry
    $payload['iat'] = time();
    $base64UrlPayload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode(json_encode($payload)));

    $signature = hash_hmac('sha256', $base64UrlHeader . "." . $base64UrlPayload, JWT_SECRET, true);
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

    return $base64UrlHeader . "." . $base64UrlPayload . "." . $base64UrlSignature;
}

// Validate JWT Token from Authorization Header
function validateToken() {
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if (empty($authHeader) || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
        return null;
    }

    $jwt = $matches[1];
    $tokenParts = explode('.', $jwt);
    if (count($tokenParts) !== 3) {
        return null;
    }

    list($header64, $payload64, $sig64) = $tokenParts;

    $expectedSig = str_replace(['+', '/', '='], ['-', '_', ''], hash_hmac('sha256', $header64 . "." . $payload64, JWT_SECRET, true));

    if (!hash_equals($expectedSig, $sig64)) {
        return null;
    }

    $payload = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $payload64)), true);
    if (isset($payload['exp']) && $payload['exp'] < time()) {
        return null; // Expired
    }

    return $payload;
}
