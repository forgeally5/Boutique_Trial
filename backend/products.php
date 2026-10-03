<?php
require_once __DIR__ . '/config.php';

$pdo = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

// ─── 1. GET PRODUCTS ───────────────────────────────────────────────────
if ($method === 'GET') {
    // Single product by tagId
    if (!empty($_GET['tagId'])) {
        $stmt = $pdo->prepare("SELECT * FROM products WHERE tag_id = ? LIMIT 1");
        $stmt->execute([$_GET['tagId']]);
        $row = $stmt->fetch();
        if ($row) {
            $row['images'] = json_decode($row['images'] ?? '[]', true);
            $row['raw_json'] = json_decode($row['raw_json'] ?? '{}', true);
            sendResponse(true, $row);
        } else {
            sendResponse(false, null, 'Product not found', 404);
        }
    }

    $where = [];
    $params = [];

    if (!empty($_GET['category']) && $_GET['category'] !== 'All Categories') {
        $where[] = "category = ?";
        $params[] = $_GET['category'];
    }

    if (!empty($_GET['status']) && $_GET['status'] !== 'All Statuses') {
        $where[] = "status = ?";
        $params[] = $_GET['status'];
    }

    if (!empty($_GET['search'])) {
        $searchTerm = '%' . $_GET['search'] . '%';
        $where[] = "(tag_id LIKE ? OR name LIKE ? OR deity LIKE ? OR material LIKE ?)";
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $params[] = $searchTerm;
    }

    $sql = "SELECT * FROM products";
    if (!empty($where)) {
        $sql .= " WHERE " . implode(" AND ", $where);
    }
    $sql .= " ORDER BY LENGTH(tag_id) ASC, tag_id ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    foreach ($rows as &$r) {
        $r['images'] = json_decode($r['images'] ?? '[]', true);
        $r['raw_json'] = json_decode($r['raw_json'] ?? '{}', true);
    }

    sendResponse(true, $rows);
}

// ─── 2. CREATE PRODUCT ─────────────────────────────────────────────────
if ($method === 'POST' && ($action === '' || $action === 'create')) {
    $input = getJsonInput();
    $tagId = trim($input['tagId'] ?? $input['tag_id'] ?? '');
    $name = trim($input['name'] ?? '');

    if (empty($tagId) || empty($name)) {
        sendResponse(false, null, 'tagId and name are required', 400);
    }

    $sql = "INSERT INTO products (
        tag_id, name, category, deity, material, size, status, vendor, notes,
        pricing_type, gross_weight, net_weight, weight_unit, rate_per_gram,
        making_charges, quantity, issue_quantity, reserved_quantity, unit,
        mrp, selling_price, discount_value, discount_type, final_price,
        gst_rate, is_festival_stock, is_reserved, reserved_for, image_url,
        images, raw_json, added_date
    ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?
    ) ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        category = VALUES(category),
        status = VALUES(status),
        quantity = VALUES(quantity),
        selling_price = VALUES(selling_price),
        final_price = VALUES(final_price),
        image_url = VALUES(image_url),
        updated_at = NOW()";

    $stmt = $pdo->prepare($sql);
    try {
        $stmt->execute([
            $tagId,
            $name,
            $input['category'] ?? '',
            $input['deity'] ?? '',
            $input['material'] ?? '',
            $input['size'] ?? '',
            $input['status'] ?? 'In Stock',
            $input['vendor'] ?? '',
            $input['notes'] ?? '',
            $input['pricingType'] ?? $input['pricing_type'] ?? 'Quantity-Based',
            (float)($input['grossWeight'] ?? $input['gross_weight'] ?? 0),
            (float)($input['netWeight'] ?? $input['net_weight'] ?? 0),
            $input['weightUnit'] ?? $input['weight_unit'] ?? 'g',
            (float)($input['ratePerGram'] ?? $input['rate_per_gram'] ?? 0),
            (float)($input['makingCharges'] ?? $input['making_charges'] ?? 0),
            (int)($input['quantity'] ?? 0),
            (int)($input['issueQuantity'] ?? $input['issue_quantity'] ?? 0),
            (int)($input['reservedQuantity'] ?? $input['reserved_quantity'] ?? 0),
            $input['unit'] ?? 'piece',
            (float)($input['mrp'] ?? 0),
            (float)($input['sellingPrice'] ?? $input['selling_price'] ?? 0),
            (float)($input['discountValue'] ?? $input['discount_value'] ?? 0),
            $input['discountType'] ?? $input['discount_type'] ?? '%',
            (float)($input['finalPrice'] ?? $input['final_price'] ?? 0),
            (float)($input['gstRate'] ?? $input['gst_rate'] ?? 0),
            !empty($input['isFestivalStock'] ?? $input['is_festival_stock']) ? 1 : 0,
            !empty($input['isReserved'] ?? $input['is_reserved']) ? 1 : 0,
            $input['reservedFor'] ?? $input['reserved_for'] ?? '',
            $input['imageUrl'] ?? $input['image_url'] ?? '',
            json_encode($input['images'] ?? []),
            json_encode($input['rawJson'] ?? $input['raw_json'] ?? $input),
            !empty($input['addedDate']) ? date('Y-m-d H:i:s', strtotime($input['addedDate'])) : date('Y-m-d H:i:s')
        ]);

        sendResponse(true, ['tagId' => $tagId], 'Product saved successfully', 201);
    } catch (PDOException $e) {
        sendResponse(false, null, 'Failed to save product: ' . $e->getMessage(), 500);
    }
}

// ─── 3. UPDATE PRODUCT ─────────────────────────────────────────────────
if ($method === 'PUT' || ($method === 'POST' && $action === 'update')) {
    $input = getJsonInput();
    $tagId = trim($input['tagId'] ?? $input['tag_id'] ?? '');
    if (empty($tagId)) {
        sendResponse(false, null, 'tagId is required', 400);
    }

    $fields = [];
    $params = [];

    $map = [
        'name' => 'name',
        'category' => 'category',
        'deity' => 'deity',
        'material' => 'material',
        'size' => 'size',
        'status' => 'status',
        'vendor' => 'vendor',
        'notes' => 'notes',
        'pricingType' => 'pricing_type',
        'grossWeight' => 'gross_weight',
        'netWeight' => 'net_weight',
        'weightUnit' => 'weight_unit',
        'ratePerGram' => 'rate_per_gram',
        'makingCharges' => 'making_charges',
        'quantity' => 'quantity',
        'issueQuantity' => 'issue_quantity',
        'reservedQuantity' => 'reserved_quantity',
        'unit' => 'unit',
        'mrp' => 'mrp',
        'sellingPrice' => 'selling_price',
        'discountValue' => 'discount_value',
        'discountType' => 'discount_type',
        'finalPrice' => 'final_price',
        'gstRate' => 'gst_rate',
        'isFestivalStock' => 'is_festival_stock',
        'isReserved' => 'is_reserved',
        'reservedFor' => 'reserved_for',
        'imageUrl' => 'image_url',
    ];

    foreach ($map as $jsonKey => $dbCol) {
        if (array_key_exists($jsonKey, $input)) {
            $fields[] = "$dbCol = ?";
            $val = $input[$jsonKey];
            if (is_bool($val)) $val = $val ? 1 : 0;
            $params[] = $val;
        }
    }

    if (isset($input['images'])) {
        $fields[] = "images = ?";
        $params[] = json_encode($input['images']);
    }

    if (empty($fields)) {
        sendResponse(false, null, 'No fields to update', 400);
    }

    $params[] = $tagId;
    $sql = "UPDATE products SET " . implode(', ', $fields) . ", updated_at = NOW() WHERE tag_id = ?";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    sendResponse(true, ['tagId' => $tagId], 'Product updated successfully');
}

// ─── 4. BATCH STOCK DEDUCTION (Post-Billing) ───────────────────────────
if ($method === 'POST' && $action === 'deduct_stock') {
    $input = getJsonInput();
    $deductions = $input['deductions'] ?? []; // [{tagId, qty, isReserved}]

    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare("UPDATE products SET 
            quantity = GREATEST(0, quantity - ?),
            reserved_quantity = GREATEST(0, reserved_quantity - ?),
            status = IF(quantity - ? <= 0, 'Sold Out', status),
            updated_at = NOW()
            WHERE tag_id = ?");

        foreach ($deductions as $d) {
            $tagId = $d['tagId'] ?? '';
            $qty = (int)($d['qty'] ?? 0);
            $resQty = !empty($d['isReserved']) ? $qty : 0;
            if (!empty($tagId) && $qty > 0) {
                $stmt->execute([$qty, $resQty, $qty, $tagId]);
            }
        }
        $pdo->commit();
        sendResponse(true, null, 'Stock updated successfully');
    } catch (Exception $e) {
        $pdo->rollBack();
        sendResponse(false, null, 'Failed to deduct stock: ' . $e->getMessage(), 500);
    }
}

// ─── 5. DELETE PRODUCT ─────────────────────────────────────────────────
if ($method === 'DELETE' || ($method === 'POST' && $action === 'delete')) {
    $tagId = $_GET['tagId'] ?? (getJsonInput()['tagId'] ?? '');
    if (empty($tagId)) {
        sendResponse(false, null, 'tagId is required', 400);
    }

    $stmt = $pdo->prepare("DELETE FROM products WHERE tag_id = ?");
    $stmt->execute([$tagId]);

    sendResponse(true, null, 'Product deleted successfully');
}

sendResponse(false, null, 'Invalid request', 400);
