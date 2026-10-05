<?php
require_once __DIR__ . '/config.php';

$pdo = getDbConnection();
$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

// ─── 1. GET BILLS ──────────────────────────────────────────────────────
if ($method === 'GET') {
    // Single bill by doc_id or bill_no
    if (!empty($_GET['docId']) || !empty($_GET['billNo'])) {
        $key = !empty($_GET['docId']) ? 'doc_id' : 'bill_no';
        $val = !empty($_GET['docId']) ? $_GET['docId'] : $_GET['billNo'];

        $stmt = $pdo->prepare("SELECT * FROM bills WHERE $key = ? LIMIT 1");
        $stmt->execute([$val]);
        $bill = $stmt->fetch();
        if ($bill) {
            $bill['items'] = json_decode($bill['items'] ?? '[]', true);
            $bill['payments'] = json_decode($bill['payments'] ?? '[]', true);
            $bill['paymentHistory'] = json_decode($bill['payment_history'] ?? '[]', true);
            $bill['customCustomerDetails'] = json_decode($bill['custom_customer_details'] ?? '{}', true);
            sendResponse(true, $bill);
        } else {
            sendResponse(false, null, 'Bill not found', 404);
        }
    }

    $where = [];
    $params = [];

    // Filter by customer mobile / name
    if (!empty($_GET['customer'])) {
        $where[] = "(customer_name LIKE ? OR customer_mobile LIKE ?)";
        $c = '%' . $_GET['customer'] . '%';
        $params[] = $c;
        $params[] = $c;
    }

    // Filter pending balance
    if (!empty($_GET['pendingOnly']) && $_GET['pendingOnly'] === 'true') {
        $where[] = "pending_balance > 0.01";
    }

    // Filter by date range
    if (!empty($_GET['startDate'])) {
        $where[] = "bill_date >= ?";
        $params[] = $_GET['startDate'] . ' 00:00:00';
    }
    if (!empty($_GET['endDate'])) {
        $where[] = "bill_date <= ?";
        $params[] = $_GET['endDate'] . ' 23:59:59';
    }

    $sql = "SELECT * FROM bills";
    if (!empty($where)) {
        $sql .= " WHERE " . implode(" AND ", $where);
    }
    $sql .= " ORDER BY bill_date DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    foreach ($rows as &$b) {
        $b['items'] = json_decode($b['items'] ?? '[]', true);
        $b['payments'] = json_decode($b['payments'] ?? '[]', true);
        $b['paymentHistory'] = json_decode($b['payment_history'] ?? '[]', true);
        $b['customCustomerDetails'] = json_decode($b['custom_customer_details'] ?? '{}', true);
    }

    sendResponse(true, $rows);
}

// ─── 2. CREATE NEW BILL ────────────────────────────────────────────────
if ($method === 'POST' && ($action === '' || $action === 'create')) {
    $input = getJsonInput();
    $billNo = trim($input['billNo'] ?? $input['bill_no'] ?? '');
    $docId = $input['docId'] ?? $input['doc_id'] ?? ('bill_' . time() . '_' . rand(1000, 9999));

    if (empty($billNo)) {
        sendResponse(false, null, 'billNo is required', 400);
    }

    $billDate = !empty($input['billDate']) 
        ? date('Y-m-d H:i:s', is_numeric($input['billDate']) ? $input['billDate'] / 1000 : strtotime($input['billDate']))
        : date('Y-m-d H:i:s');

    $sql = "INSERT INTO bills (
        doc_id, bill_no, bill_type, narration, bill_date, customer_name,
        customer_mobile, customer_address, custom_customer_details, items,
        subtotal, extra_discount_type, extra_discount_value, extra_discount_amount,
        gst_percent, tax_amount, adjustment_amount, total_payable, payment_mode,
        payments, payment_history, amount_received, pending_balance,
        is_fully_paid, payment_status, balance_returned
    ) VALUES (
        ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?
    )";

    $stmt = $pdo->prepare($sql);
    try {
        $stmt->execute([
            $docId,
            $billNo,
            $input['billType'] ?? $input['bill_type'] ?? 'Retail',
            $input['narration'] ?? '',
            $billDate,
            $input['customerName'] ?? $input['customer_name'] ?? '',
            $input['customerMobile'] ?? $input['customer_mobile'] ?? '',
            $input['customerAddress'] ?? $input['customer_address'] ?? '',
            json_encode($input['customCustomerDetails'] ?? $input['custom_customer_details'] ?? []),
            json_encode($input['items'] ?? []),
            (float)($input['subtotal'] ?? 0),
            $input['extraDiscountType'] ?? $input['extra_discount_type'] ?? '%',
            (float)($input['extraDiscountValue'] ?? $input['extra_discount_value'] ?? 0),
            (float)($input['extraDiscountAmount'] ?? $input['extra_discount_amount'] ?? 0),
            (float)($input['gstPercent'] ?? $input['gst_percent'] ?? 0),
            (float)($input['taxAmount'] ?? $input['tax_amount'] ?? 0),
            (float)($input['adjustmentAmount'] ?? $input['adjustment_amount'] ?? 0),
            (float)($input['totalPayable'] ?? $input['total_payable'] ?? 0),
            $input['paymentMode'] ?? $input['payment_mode'] ?? 'Cash',
            json_encode($input['payments'] ?? []),
            json_encode($input['paymentHistory'] ?? $input['payment_history'] ?? []),
            (float)($input['amountReceived'] ?? $input['amount_received'] ?? 0),
            (float)($input['pendingBalance'] ?? $input['pending_balance'] ?? 0),
            !empty($input['isFullyPaid']) || ((float)($input['pendingBalance'] ?? 0) <= 0) ? 1 : 0,
            $input['paymentStatus'] ?? $input['payment_status'] ?? 'Paid',
            (float)($input['balanceReturned'] ?? $input['balance_returned'] ?? 0)
        ]);

        sendResponse(true, ['docId' => $docId, 'billNo' => $billNo], 'Bill saved successfully', 201);
    } catch (PDOException $e) {
        sendResponse(false, null, 'Failed to save bill: ' . $e->getMessage(), 500);
    }
}

// ─── 3. UPDATE BILL / RECORD PAYMENT / RETURN ──────────────────────────
if ($method === 'PUT' || ($method === 'POST' && $action === 'update')) {
    $input = getJsonInput();
    $docId = $input['docId'] ?? $input['doc_id'] ?? '';
    if (empty($docId)) {
        sendResponse(false, null, 'docId is required', 400);
    }

    $fields = [];
    $params = [];

    $fieldsToUpdate = [
        'amountReceived' => 'amount_received',
        'pendingBalance' => 'pending_balance',
        'isFullyPaid'    => 'is_fully_paid',
        'paymentStatus'  => 'payment_status',
        'balanceReturned'=> 'balance_returned',
        'narration'      => 'narration',
        'customerName'   => 'customer_name',
        'customerMobile' => 'customer_mobile',
        'customerAddress'=> 'customer_address',
        'paymentMode'    => 'payment_mode',
        'lastPaymentDate'=> 'last_payment_date',
        'lastPaymentMode'=> 'last_payment_mode'
    ];

    foreach ($fieldsToUpdate as $jsonKey => $dbCol) {
        if (array_key_exists($jsonKey, $input)) {
            $fields[] = "$dbCol = ?";
            $val = $input[$jsonKey];
            if (is_bool($val)) $val = $val ? 1 : 0;
            $params[] = $val;
        }
    }

    if (isset($input['paymentHistory'])) {
        $fields[] = "payment_history = ?";
        $params[] = json_encode($input['paymentHistory']);
    }
    if (isset($input['items'])) {
        $fields[] = "items = ?";
        $params[] = json_encode($input['items']);
    }

    if (empty($fields)) {
        sendResponse(false, null, 'No fields to update', 400);
    }

    $params[] = $docId;
    $sql = "UPDATE bills SET " . implode(', ', $fields) . ", updated_at = NOW() WHERE doc_id = ?";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    sendResponse(true, ['docId' => $docId], 'Bill updated successfully');
}

// ─── 4. DELETE BILL ────────────────────────────────────────────────────
if ($method === 'DELETE' || ($method === 'POST' && $action === 'delete')) {
    $docId = $_GET['docId'] ?? (getJsonInput()['docId'] ?? '');
    if (empty($docId)) {
        sendResponse(false, null, 'docId is required', 400);
    }

    $stmt = $pdo->prepare("DELETE FROM bills WHERE doc_id = ?");
    $stmt->execute([$docId]);

    sendResponse(true, null, 'Bill deleted successfully');
}

sendResponse(false, null, 'Invalid request', 400);
