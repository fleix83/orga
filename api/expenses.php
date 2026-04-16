<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

if ($method === 'GET') {
    if ($id) {
        $stmt = $pdo->prepare('
            SELECT e.*, c.name AS category_name
            FROM expenses e
            JOIN categories c ON e.category_id = c.id
            WHERE e.id = ?
        ');
        $stmt->execute([$id]);
        $expense = $stmt->fetch();
        if (!$expense) jsonResponse(['error' => 'Aufwand nicht gefunden'], 404);
        jsonResponse($expense);
    }
    $stmt = $pdo->query('
        SELECT e.*, c.name AS category_name
        FROM expenses e
        JOIN categories c ON e.category_id = c.id
        ORDER BY e.expense_date DESC
    ');
    jsonResponse($stmt->fetchAll());
}

if ($method === 'POST') {
    $data = getJsonBody();
    $stmt = $pdo->prepare('INSERT INTO expenses (expense_date, description, amount, category_id) VALUES (?, ?, ?, ?)');
    $stmt->execute([
        $data['expense_date'] ?? date('Y-m-d'),
        $data['description'] ?? '',
        $data['amount'] ?? 0,
        $data['category_id'] ?? 1,
    ]);
    jsonResponse(['id' => (int)$pdo->lastInsertId()], 201);
}

if ($method === 'PUT' && $id) {
    $data = getJsonBody();
    $fields = [];
    $params = [];
    $allowed = ['expense_date', 'description', 'amount', 'category_id'];

    foreach ($allowed as $field) {
        if (array_key_exists($field, $data)) {
            $fields[] = "`$field` = ?";
            $params[] = $data[$field];
        }
    }

    if (empty($fields)) jsonResponse(['error' => 'Keine Felder zum Aktualisieren'], 400);

    $params[] = $id;
    $stmt = $pdo->prepare('UPDATE expenses SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);
    jsonResponse(['success' => true]);
}

if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM expenses WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
