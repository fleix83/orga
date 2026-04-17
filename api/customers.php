<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

// GET: List all or single customer
if ($method === 'GET') {
    if ($id) {
        $stmt = $pdo->prepare('
            SELECT c.*,
                COALESCE(SUM(o.amount), 0) AS total,
                COALESCE(SUM(o.duration_minutes), 0) AS total_duration,
                COALESCE(c.order_count_override, COUNT(DISTINCT o.id)) AS order_count
            FROM customers c
            LEFT JOIN orders o ON o.customer_id = c.id
            WHERE c.id = ?
            GROUP BY c.id
        ');
        $stmt->execute([$id]);
        $customer = $stmt->fetch();
        if (!$customer) {
            jsonResponse(['error' => 'Kunde nicht gefunden'], 404);
        }
        jsonResponse($customer);
    }

    $search = getParam('search', '');
    $query = '
        SELECT c.*,
            COALESCE(SUM(o.amount), 0) AS total,
            COALESCE(c.order_count_override, COUNT(DISTINCT o.id)) AS order_count
        FROM customers c
        LEFT JOIN orders o ON o.customer_id = c.id
    ';
    $params = [];

    if ($search !== '') {
        $query .= ' WHERE c.first_name LIKE ? OR c.last_name LIKE ? OR c.email LIKE ? OR c.phone LIKE ? OR c.city LIKE ?';
        $like = "%$search%";
        $params = [$like, $like, $like, $like, $like];
    }

    $query .= ' GROUP BY c.id ORDER BY c.last_name, c.first_name';

    $stmt = $pdo->prepare($query);
    $stmt->execute($params);
    jsonResponse($stmt->fetchAll());
}

// POST: Create customer
if ($method === 'POST') {
    $data = getJsonBody();

    // Generate next sequential customer number (01, 02, 03, ...)
    $number = $data['customer_number'] ?? null;
    if (!$number) {
        $stmt = $pdo->query("SELECT MAX(CAST(customer_number AS UNSIGNED)) AS max_num FROM customers WHERE customer_number REGEXP '^[0-9]+$'");
        $row = $stmt->fetch();
        $next = ((int)($row['max_num'] ?? 0)) + 1;
        $number = str_pad((string)$next, 2, '0', STR_PAD_LEFT);
    }

    $stmt = $pdo->prepare('
        INSERT INTO customers (customer_number, salutation, first_name, last_name, email, phone, street, zip, city, nationality, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');
    $stmt->execute([
        $number,
        $data['salutation'] ?? null,
        $data['first_name'] ?? '',
        $data['last_name'] ?? '',
        $data['email'] ?? null,
        $data['phone'] ?? null,
        $data['street'] ?? null,
        $data['zip'] ?? null,
        $data['city'] ?? null,
        $data['nationality'] ?? null,
        $data['notes'] ?? null,
    ]);
    jsonResponse(['id' => (int)$pdo->lastInsertId()], 201);
}

// PUT: Update customer
if ($method === 'PUT' && $id) {
    $data = getJsonBody();
    $fields = [];
    $params = [];
    $allowed = ['customer_number', 'salutation', 'first_name', 'last_name', 'email', 'phone', 'street', 'zip', 'city', 'nationality', 'notes', 'order_count_override'];

    foreach ($allowed as $field) {
        if (array_key_exists($field, $data)) {
            $fields[] = "`$field` = ?";
            $params[] = $data[$field];
        }
    }

    if (empty($fields)) {
        jsonResponse(['error' => 'Keine Felder zum Aktualisieren'], 400);
    }

    $params[] = $id;
    $stmt = $pdo->prepare('UPDATE customers SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);
    jsonResponse(['success' => true]);
}

// DELETE: Delete customer
if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM customers WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
