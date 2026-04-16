<?php
require_once __DIR__ . '/config.php';

$method = getMethod();
$action = getParam('action');

// GET: Check session
if ($method === 'GET' && $action === 'check') {
    if (!empty($_SESSION['user_id'])) {
        jsonResponse(['authenticated' => true, 'username' => $_SESSION['username']]);
    } else {
        jsonResponse(['authenticated' => false]);
    }
}

// POST: Login
if ($method === 'POST' && $action === null) {
    $data = getJsonBody();
    $username = trim($data['username'] ?? '');
    $password = $data['password'] ?? '';

    if ($username === '' || $password === '') {
        jsonResponse(['error' => 'Benutzername und Passwort erforderlich'], 400);
    }

    $stmt = $pdo->prepare('SELECT id, username, password_hash FROM app_users WHERE username = ?');
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
        jsonResponse(['error' => 'Ungültige Anmeldedaten'], 401);
    }

    $_SESSION['user_id'] = $user['id'];
    $_SESSION['username'] = $user['username'];
    jsonResponse(['authenticated' => true, 'username' => $user['username']]);
}

// POST: Logout
if ($method === 'POST' && $action === 'logout') {
    session_destroy();
    jsonResponse(['authenticated' => false]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
