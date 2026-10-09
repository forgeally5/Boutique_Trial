<?php
require_once __DIR__ . '/config.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'POST') {
    $user = validateToken();
    if (!$user) {
        sendResponse(false, null, 'Unauthorized. Please login.', 401);
    }

    if (!isset($_FILES['file']) && !isset($_FILES['image'])) {
        sendResponse(false, null, 'No file uploaded', 400);
    }

    $file = $_FILES['file'] ?? $_FILES['image'];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        sendResponse(false, null, 'Upload error code: ' . $file['error'], 400);
    }

    $allowedExts = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf'];
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));

    if (!in_array($ext, $allowedExts)) {
        sendResponse(false, null, 'Invalid file type. Allowed: ' . implode(', ', $allowedExts), 400);
    }

    $subDir = !empty($_POST['folder']) ? preg_replace('/[^a-zA-Z0-9_-]/', '', $_POST['folder']) : 'products';
    $targetDir = __DIR__ . '/uploads/' . $subDir;

    if (!is_dir($targetDir)) {
        mkdir($targetDir, 0755, true);
    }

    $fileName = time() . '_' . bin2hex(random_bytes(6)) . '.' . $ext;
    $targetPath = $targetDir . '/' . $fileName;

    if (move_uploaded_file($file['tmp_name'], $targetPath)) {
        // Construct full URL
        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
        $host = $_SERVER['HTTP_HOST'];
        $publicUrl = $protocol . $host . '/uploads/' . $subDir . '/' . $fileName;

        sendResponse(true, [
            'url'      => $publicUrl,
            'fileName' => $fileName,
            'size'     => $file['size']
        ], 'File uploaded successfully', 201);
    } else {
        sendResponse(false, null, 'Failed to save uploaded file', 500);
    }
}

sendResponse(false, null, 'POST request with multipart/form-data required', 400);
