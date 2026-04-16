<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

if ($method === 'GET') {
    if ($id) {
        $stmt = $pdo->prepare('SELECT * FROM categories WHERE id = ?');
        $stmt->execute([$id]);
        $cat = $stmt->fetch();
        if (!$cat) jsonResponse(['error' => 'Zuordnung nicht gefunden'], 404);
        jsonResponse($cat);
    }
    $stmt = $pdo->query('SELECT * FROM categories WHERE active = 1 ORDER BY sort_order, name');
    jsonResponse($stmt->fetchAll());
}

if ($method === 'POST') {
    $data = getJsonBody();
    $stmt = $pdo->prepare('INSERT INTO categories (name, sort_order) VALUES (?, ?)');
    $stmt->execute([$data['name'] ?? '', $data['sort_order'] ?? 0]);
    jsonResponse(['id' => (int)$pdo->lastInsertId()], 201);
}

if ($method === 'PUT' && $id) {
    $data = getJsonBody();
    $fields = [];
    $params = [];
    $allowed = ['name', 'active', 'sort_order'];

    foreach ($allowed as $field) {
        if (array_key_exists($field, $data)) {
            $fields[] = "`$field` = ?";
            $params[] = $data[$field];
        }
    }

    if (empty($fields)) jsonResponse(['error' => 'Keine Felder zum Aktualisieren'], 400);

    $params[] = $id;
    $stmt = $pdo->prepare('UPDATE categories SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);
    jsonResponse(['success' => true]);
}

if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM categories WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
