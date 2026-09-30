<?php
require_once __DIR__ . '/config.php';

// Health Check Endpoint
try {
    $pdo = getDbConnection();
    sendResponse(true, [
        'app'       => 'RituMita Boutique REST API',
        'status'    => 'running',
        'database'  => 'connected',
        'timestamp' => date('Y-m-d H:i:s'),
        'version'   => '1.0.0'
    ], 'API server is healthy and connected');
} catch (Exception $e) {
    sendResponse(false, [
        'status' => 'error',
        'error'  => $e->getMessage()
    ], 'Database connection error', 500);
}
