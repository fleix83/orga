<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

// Lightweight count of appointments created since a given timestamp.
// Used by the sidebar to show a red-dot notification for new appointments.
// Returns the server's current time so the client can use it as a TZ-safe baseline.
if ($method === 'GET' && getParam('new_count')) {
    $since = getParam('since');
    if ($since) {
        $stmt = $pdo->prepare('SELECT COUNT(*) AS c, NOW() AS server_time FROM events WHERE user_id = 1 AND created_at > ?');
        $stmt->execute([$since]);
    } else {
        $stmt = $pdo->query('SELECT COUNT(*) AS c, NOW() AS server_time FROM events WHERE user_id = 1');
    }
    $row = $stmt->fetch();
    jsonResponse(['count' => (int)$row['c'], 'server_time' => $row['server_time']]);
}

if ($method === 'GET') {
    $stmt = $pdo->query('
        SELECT
            e.id,
            e.event_date,
            e.start_slot,
            e.end_slot,
            CONCAT(LPAD(e.start_slot, 2, "0"), ":00 - ", LPAD(e.end_slot, 2, "0"), ":00") AS time_display,
            e.title,
            e.notes,
            e.status,
            et.name AS event_type,
            et.color,
            c.id AS customer_id,
            c.customer_number,
            c.first_name AS customer_first_name,
            c.last_name AS customer_last_name,
            c.email AS customer_email,
            c.phone AS customer_phone,
            GROUP_CONCAT(s.name SEPARATOR ", ") AS service_names,
            SUM(b.price_at_booking) AS total_price
        FROM events e
        JOIN event_types et ON e.event_type_id = et.id
        LEFT JOIN customers c ON e.customer_id = c.id
        LEFT JOIN bookings b ON b.event_id = e.id
        LEFT JOIN services s ON b.service_id = s.id
        WHERE e.user_id = 1
        GROUP BY e.id
        ORDER BY e.event_date DESC, e.start_slot ASC
    ');
    jsonResponse($stmt->fetchAll());
}

if ($method === 'PUT' && $id) {
    $data = getJsonBody();
    $fields = [];
    $params = [];
    $allowed = ['status', 'notes', 'event_date', 'start_slot', 'end_slot', 'customer_id', 'title'];

    foreach ($allowed as $field) {
        if (array_key_exists($field, $data)) {
            $fields[] = "`$field` = ?";
            $params[] = $data[$field] === '' ? null : $data[$field];
        }
    }

    if (empty($fields)) jsonResponse(['error' => 'Keine Felder zum Aktualisieren'], 400);

    $params[] = $id;
    $stmt = $pdo->prepare('UPDATE events SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);
    jsonResponse(['success' => true]);
}

// POST: Create manual appointment (and a matching Auftrag if a customer is set)
if ($method === 'POST') {
    $data = getJsonBody();

    // Use "Termine Kunden Bewerbungen & Mehr" event type (id=1)
    $eventTypeId = 1;
    $startSlot = (int)($data['start_slot'] ?? 9);
    $endSlot = (int)($data['end_slot'] ?? 10);
    $customerId = !empty($data['customer_id']) ? (int)$data['customer_id'] : null;

    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare('
            INSERT INTO events (user_id, event_type_id, event_date, start_slot, end_slot, customer_id, title, notes, status)
            VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)
        ');
        $stmt->execute([
            $eventTypeId,
            $data['event_date'],
            $startSlot,
            $endSlot,
            $customerId,
            $data['title'] ?? null,
            $data['notes'] ?? null,
            $data['status'] ?? 'confirmed',
        ]);
        $eventId = (int)$pdo->lastInsertId();

        // Auto-generate a matching Auftrag. Skipped if no customer is selected,
        // since orders.customer_id is NOT NULL.
        $orderId = null;
        if ($customerId) {
            $catStmt = $pdo->query('SELECT id FROM categories WHERE active = 1 ORDER BY sort_order, id LIMIT 1');
            $cat = $catStmt->fetch();
            $categoryId = $cat ? (int)$cat['id'] : 1;

            $numStmt = $pdo->query("SELECT MAX(CAST(order_number AS UNSIGNED)) AS max_num FROM orders WHERE order_number REGEXP '^[0-9]+$'");
            $row = $numStmt->fetch();
            $orderNumber = str_pad((string)(((int)($row['max_num'] ?? 0)) + 1), 2, '0', STR_PAD_LEFT);

            $duration = max(0, ($endSlot - $startSlot) * 60);
            $title = $data['title'] ?? null;
            $notes = $data['notes'] ?? null;
            $combined = trim(($title ?? '') . ($title && $notes ? "\n" : '') . ($notes ?? ''));
            if ($combined === '') $combined = null;

            $orderStmt = $pdo->prepare('
                INSERT INTO orders (order_number, order_date, customer_id, category_id, location_type, amount, duration_minutes, notes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ');
            $orderStmt->execute([
                $orderNumber,
                $data['event_date'],
                $customerId,
                $categoryId,
                'vor_ort',
                0,
                $duration,
                $combined,
            ]);
            $orderId = (int)$pdo->lastInsertId();
        }

        $pdo->commit();
        jsonResponse(['id' => $eventId, 'order_id' => $orderId], 201);
    } catch (Exception $e) {
        $pdo->rollBack();
        jsonResponse(['error' => 'Fehler beim Erstellen: ' . $e->getMessage()], 500);
    }
}

// DELETE: Delete appointment
if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM events WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
