<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

if ($method === 'GET') {
    if ($id) {
        $stmt = $pdo->prepare('
            SELECT o.*,
                c.first_name AS customer_first_name,
                c.last_name AS customer_last_name,
                cat.name AS category_name
            FROM orders o
            JOIN customers c ON o.customer_id = c.id
            JOIN categories cat ON o.category_id = cat.id
            WHERE o.id = ?
        ');
        $stmt->execute([$id]);
        $order = $stmt->fetch();
        if (!$order) jsonResponse(['error' => 'Auftrag nicht gefunden'], 404);

        $stmt2 = $pdo->prepare('
            SELECT os.*, s.name AS service_name
            FROM order_services os
            LEFT JOIN services s ON os.service_id = s.id
            WHERE os.order_id = ?
        ');
        $stmt2->execute([$id]);
        $order['services'] = $stmt2->fetchAll();

        jsonResponse($order);
    }

    $stmt = $pdo->query('
        SELECT o.*,
            c.first_name AS customer_first_name,
            c.last_name AS customer_last_name,
            cat.name AS category_name,
            GROUP_CONCAT(COALESCE(s.name, os.custom_name) SEPARATOR \', \') AS service_names
        FROM orders o
        JOIN customers c ON o.customer_id = c.id
        JOIN categories cat ON o.category_id = cat.id
        LEFT JOIN order_services os ON os.order_id = o.id
        LEFT JOIN services s ON os.service_id = s.id
        GROUP BY o.id
        ORDER BY o.order_date DESC, o.created_at DESC
    ');
    jsonResponse($stmt->fetchAll());
}

if ($method === 'POST') {
    $data = getJsonBody();
    $pdo->beginTransaction();

    try {
        $stmt = $pdo->prepare('
            INSERT INTO orders (order_date, customer_id, category_id, location_type, amount, notes)
            VALUES (?, ?, ?, ?, ?, ?)
        ');
        $stmt->execute([
            $data['order_date'],
            $data['customer_id'],
            $data['category_id'],
            $data['location_type'] ?? 'vor_ort',
            $data['amount'] ?? 0,
            $data['notes'] ?? null,
        ]);
        $orderId = (int)$pdo->lastInsertId();

        if (!empty($data['services'])) {
            $stmt2 = $pdo->prepare('INSERT INTO order_services (order_id, service_id, custom_name, price) VALUES (?, ?, ?, ?)');
            foreach ($data['services'] as $svc) {
                $stmt2->execute([
                    $orderId,
                    $svc['service_id'] ?? null,
                    $svc['custom_name'] ?? null,
                    $svc['price'] ?? 0,
                ]);
            }
        }

        $pdo->commit();
        jsonResponse(['id' => $orderId], 201);
    } catch (Exception $e) {
        $pdo->rollBack();
        jsonResponse(['error' => 'Fehler beim Erstellen: ' . $e->getMessage()], 500);
    }
}

if ($method === 'PUT' && $id) {
    $data = getJsonBody();
    $pdo->beginTransaction();

    try {
        $fields = [];
        $params = [];
        $allowed = ['order_date', 'customer_id', 'category_id', 'location_type', 'amount', 'notes'];

        foreach ($allowed as $field) {
            if (array_key_exists($field, $data)) {
                $fields[] = "`$field` = ?";
                $params[] = $data[$field];
            }
        }

        if (!empty($fields)) {
            $params[] = $id;
            $stmt = $pdo->prepare('UPDATE orders SET ' . implode(', ', $fields) . ' WHERE id = ?');
            $stmt->execute($params);
        }

        if (array_key_exists('services', $data)) {
            $pdo->prepare('DELETE FROM order_services WHERE order_id = ?')->execute([$id]);
            $stmt2 = $pdo->prepare('INSERT INTO order_services (order_id, service_id, custom_name, price) VALUES (?, ?, ?, ?)');
            foreach ($data['services'] as $svc) {
                $stmt2->execute([
                    $id,
                    $svc['service_id'] ?? null,
                    $svc['custom_name'] ?? null,
                    $svc['price'] ?? 0,
                ]);
            }
        }

        $pdo->commit();
        jsonResponse(['success' => true]);
    } catch (Exception $e) {
        $pdo->rollBack();
        jsonResponse(['error' => 'Fehler beim Aktualisieren: ' . $e->getMessage()], 500);
    }
}

if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM orders WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
