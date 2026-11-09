<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');
$action = getParam('action');

const TASK_STATUSES = ['todo', 'doing', 'done'];

// Loads tasks (all, or the given ids) with their linked customers/bookings.
function fetchTasks(PDO $pdo, ?int $id = null): array {
    if ($id) {
        $stmt = $pdo->prepare('SELECT * FROM tasks WHERE id = ?');
        $stmt->execute([$id]);
    } else {
        $stmt = $pdo->query('SELECT * FROM tasks ORDER BY FIELD(status, \'todo\', \'doing\', \'done\'), position, id');
    }
    $tasks = $stmt->fetchAll();
    if (!$tasks) return [];

    $ids = array_column($tasks, 'id');
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare("
        SELECT tl.id, tl.task_id, tl.customer_id, tl.order_id,
            c.first_name AS customer_first_name,
            c.last_name AS customer_last_name,
            o.order_number, o.order_date,
            oc.first_name AS order_customer_first_name,
            oc.last_name AS order_customer_last_name
        FROM task_links tl
        LEFT JOIN customers c ON tl.customer_id = c.id
        LEFT JOIN orders o ON tl.order_id = o.id
        LEFT JOIN customers oc ON o.customer_id = oc.id
        WHERE tl.task_id IN ($placeholders)
        ORDER BY tl.id
    ");
    $stmt->execute($ids);

    $linksByTask = [];
    foreach ($stmt->fetchAll() as $link) {
        $linksByTask[$link['task_id']][] = $link;
    }
    foreach ($tasks as &$task) {
        $task['links'] = $linksByTask[$task['id']] ?? [];
    }
    return $tasks;
}

// Replaces a task's links; duplicates and malformed entries are dropped.
function saveLinks(PDO $pdo, int $taskId, array $links): void {
    $pdo->prepare('DELETE FROM task_links WHERE task_id = ?')->execute([$taskId]);
    addLinks($pdo, $taskId, $links);
}

// Adds links that the task does not have yet.
function addLinks(PDO $pdo, int $taskId, array $links): void {
    $stmt = $pdo->prepare('SELECT customer_id, order_id FROM task_links WHERE task_id = ?');
    $stmt->execute([$taskId]);
    $seen = [];
    foreach ($stmt->fetchAll() as $row) {
        $seen[$row['customer_id'] ? 'c' . $row['customer_id'] : 'o' . $row['order_id']] = true;
    }

    $insert = $pdo->prepare('INSERT INTO task_links (task_id, customer_id, order_id) VALUES (?, ?, ?)');
    foreach ($links as $link) {
        $customerId = !empty($link['customer_id']) ? (int)$link['customer_id'] : null;
        $orderId = !empty($link['order_id']) ? (int)$link['order_id'] : null;
        if (!$customerId === !$orderId) continue; // exactly one must be set
        $key = $customerId ? "c$customerId" : "o$orderId";
        if (isset($seen[$key])) continue;
        $seen[$key] = true;
        $insert->execute([$taskId, $customerId, $orderId]);
    }
}

function nextPosition(PDO $pdo, string $status): int {
    $stmt = $pdo->prepare('SELECT COALESCE(MAX(position), -1) + 1 FROM tasks WHERE status = ?');
    $stmt->execute([$status]);
    return (int)$stmt->fetchColumn();
}

if ($method === 'GET') {
    if ($id) {
        $tasks = fetchTasks($pdo, (int)$id);
        if (!$tasks) jsonResponse(['error' => 'Aufgabe nicht gefunden'], 404);
        jsonResponse($tasks[0]);
    }
    jsonResponse(fetchTasks($pdo));
}

// Booking → task: appends the booking summary (built by the booking modal) to
// a new or existing task and links the booking and its customer.
if ($method === 'POST' && $action === 'attach_order') {
    $data = getJsonBody();
    $orderId = (int)($data['order_id'] ?? 0);
    $text = trim((string)($data['text'] ?? ''));

    $stmt = $pdo->prepare('SELECT customer_id FROM orders WHERE id = ?');
    $stmt->execute([$orderId]);
    $customerId = $stmt->fetchColumn();
    if ($customerId === false) jsonResponse(['error' => 'Buchung nicht gefunden'], 404);

    $pdo->beginTransaction();
    try {
        if (!empty($data['task_id'])) {
            $taskId = (int)$data['task_id'];
            $stmt = $pdo->prepare('SELECT notes FROM tasks WHERE id = ?');
            $stmt->execute([$taskId]);
            $notes = $stmt->fetchColumn();
            if ($notes === false) {
                $pdo->rollBack();
                jsonResponse(['error' => 'Aufgabe nicht gefunden'], 404);
            }
            $notes = trim((string)$notes);
            $notes = $notes === '' ? $text : "$notes\n\n$text";
            $pdo->prepare('UPDATE tasks SET notes = ? WHERE id = ?')->execute([$notes, $taskId]);
        } else {
            $title = trim((string)($data['title'] ?? ''));
            if ($title === '') {
                $pdo->rollBack();
                jsonResponse(['error' => 'Titel fehlt'], 400);
            }
            $stmt = $pdo->prepare('INSERT INTO tasks (title, notes, status, position) VALUES (?, ?, \'todo\', ?)');
            $stmt->execute([$title, $text, nextPosition($pdo, 'todo')]);
            $taskId = (int)$pdo->lastInsertId();
        }

        addLinks($pdo, $taskId, [['order_id' => $orderId], ['customer_id' => $customerId]]);
        $pdo->commit();
        jsonResponse(['id' => $taskId], 201);
    } catch (Exception $e) {
        $pdo->rollBack();
        jsonResponse(['error' => 'Fehler beim Verknüpfen: ' . $e->getMessage()], 500);
    }
}

if ($method === 'POST') {
    $data = getJsonBody();
    $title = trim((string)($data['title'] ?? ''));
    if ($title === '') jsonResponse(['error' => 'Titel fehlt'], 400);
    $status = in_array($data['status'] ?? '', TASK_STATUSES, true) ? $data['status'] : 'todo';

    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare('INSERT INTO tasks (title, notes, status, position, due_date) VALUES (?, ?, ?, ?, ?)');
        $stmt->execute([
            $title,
            $data['notes'] ?? null,
            $status,
            nextPosition($pdo, $status),
            !empty($data['due_date']) ? $data['due_date'] : null,
        ]);
        $taskId = (int)$pdo->lastInsertId();
        addLinks($pdo, $taskId, $data['links'] ?? []);
        $pdo->commit();
        jsonResponse(['id' => $taskId], 201);
    } catch (Exception $e) {
        $pdo->rollBack();
        jsonResponse(['error' => 'Fehler beim Erstellen: ' . $e->getMessage()], 500);
    }
}

// Drag & drop: stores the complete card order of one column.
if ($method === 'PUT' && $action === 'reorder') {
    $data = getJsonBody();
    $status = $data['status'] ?? '';
    if (!in_array($status, TASK_STATUSES, true)) jsonResponse(['error' => 'Ungültige Spalte'], 400);

    $stmt = $pdo->prepare('UPDATE tasks SET status = ?, position = ? WHERE id = ?');
    $pdo->beginTransaction();
    foreach (array_values($data['ids'] ?? []) as $position => $taskId) {
        $stmt->execute([$status, $position, (int)$taskId]);
    }
    $pdo->commit();
    jsonResponse(['success' => true]);
}

if ($method === 'PUT' && $id) {
    $data = getJsonBody();
    $fields = [];
    $params = [];

    if (array_key_exists('title', $data)) {
        $title = trim((string)$data['title']);
        if ($title === '') jsonResponse(['error' => 'Titel fehlt'], 400);
        $fields[] = '`title` = ?';
        $params[] = $title;
    }
    if (array_key_exists('notes', $data)) {
        $fields[] = '`notes` = ?';
        $params[] = $data['notes'];
    }
    if (array_key_exists('due_date', $data)) {
        $fields[] = '`due_date` = ?';
        $params[] = !empty($data['due_date']) ? $data['due_date'] : null;
    }
    // A status change moves the card to the end of the target column.
    if (array_key_exists('status', $data)) {
        if (!in_array($data['status'], TASK_STATUSES, true)) jsonResponse(['error' => 'Ungültiger Status'], 400);
        $stmt = $pdo->prepare('SELECT status FROM tasks WHERE id = ?');
        $stmt->execute([$id]);
        if ($stmt->fetchColumn() !== $data['status']) {
            $fields[] = '`status` = ?';
            $params[] = $data['status'];
            $fields[] = '`position` = ?';
            $params[] = nextPosition($pdo, $data['status']);
        }
    }

    $pdo->beginTransaction();
    try {
        if ($fields) {
            $params[] = $id;
            $pdo->prepare('UPDATE tasks SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
        }
        if (array_key_exists('links', $data)) {
            saveLinks($pdo, (int)$id, $data['links'] ?? []);
        }
        $pdo->commit();
        jsonResponse(['success' => true]);
    } catch (Exception $e) {
        $pdo->rollBack();
        jsonResponse(['error' => 'Fehler beim Aktualisieren: ' . $e->getMessage()], 500);
    }
}

if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM tasks WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
