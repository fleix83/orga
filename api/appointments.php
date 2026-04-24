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
    $allowed = ['status', 'notes'];

    foreach ($allowed as $field) {
        if (array_key_exists($field, $data)) {
            $fields[] = "`$field` = ?";
            $params[] = $data[$field];
        }
    }

    if (empty($fields)) jsonResponse(['error' => 'Keine Felder zum Aktualisieren'], 400);

    $params[] = $id;
    $stmt = $pdo->prepare('UPDATE events SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);
    jsonResponse(['success' => true]);
}

// POST: Create manual appointment
if ($method === 'POST') {
    $data = getJsonBody();

    // Use "Termine Kunden Bewerbungen & Mehr" event type (id=1)
    $eventTypeId = 1;

    $stmt = $pdo->prepare('
        INSERT INTO events (user_id, event_type_id, event_date, start_slot, end_slot, customer_id, title, notes, status)
        VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)
    ');
    $stmt->execute([
        $eventTypeId,
        $data['event_date'],
        $data['start_slot'] ?? 9,
        $data['end_slot'] ?? 10,
        $data['customer_id'] ?: null,
        $data['title'] ?? null,
        $data['notes'] ?? null,
        $data['status'] ?? 'confirmed',
    ]);
    jsonResponse(['id' => (int)$pdo->lastInsertId()], 201);
}

// DELETE: Delete appointment
if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM events WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
