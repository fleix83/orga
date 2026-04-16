<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

if ($method === 'GET') {
    if ($id) {
        $stmt = $pdo->prepare('SELECT * FROM services WHERE id = ?');
        $stmt->execute([$id]);
        $service = $stmt->fetch();
        if (!$service) jsonResponse(['error' => 'Dienstleistung nicht gefunden'], 404);
        jsonResponse($service);
    }
    $stmt = $pdo->query('SELECT * FROM services ORDER BY sort_order, name');
    jsonResponse($stmt->fetchAll());
}

if ($method === 'POST') {
    $data = getJsonBody();
    $stmt = $pdo->prepare('INSERT INTO services (name, price, description, active, sort_order, duration_slots) VALUES (?, ?, ?, ?, ?, ?)');
    $stmt->execute([
        $data['name'] ?? '',
        $data['price'] ?? 0,
        $data['description'] ?? null,
        $data['active'] ?? 1,
        $data['sort_order'] ?? 0,
        $data['duration_slots'] ?? 1,
    ]);
    jsonResponse(['id' => (int)$pdo->lastInsertId()], 201);
}

if ($method === 'PUT' && $id) {
    $data = getJsonBody();
    $fields = [];
    $params = [];
    $allowed = ['name', 'price', 'description', 'active', 'sort_order', 'duration_slots'];

    foreach ($allowed as $field) {
        if (array_key_exists($field, $data)) {
            $fields[] = "`$field` = ?";
            $params[] = $data[$field];
        }
    }

    if (empty($fields)) jsonResponse(['error' => 'Keine Felder zum Aktualisieren'], 400);

    $params[] = $id;
    $stmt = $pdo->prepare('UPDATE services SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);
    jsonResponse(['success' => true]);
}

if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM services WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
