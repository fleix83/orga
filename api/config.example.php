<?php
// Copy this file to config.php and update credentials

// Log out after 120 minutes without a request
const SESSION_LIFETIME = 7200;

// Set session cookie params for iOS Safari / mobile compatibility
$isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
    || (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https');

$cookieParams = [
    'lifetime' => SESSION_LIFETIME,
    'path' => '/',
    'domain' => '',
    'secure' => $isHttps,
    'httponly' => true,
    'samesite' => 'Lax',
];

ini_set('session.gc_maxlifetime', (string)SESSION_LIFETIME);
session_set_cookie_params($cookieParams);

session_start();

// Server-side idle timeout — gc_maxlifetime alone is unreliable when other apps
// share the session save path and garbage-collect with a shorter lifetime.
if (!empty($_SESSION['last_activity']) && time() - $_SESSION['last_activity'] > SESSION_LIFETIME) {
    $_SESSION = [];
}
$_SESSION['last_activity'] = time();

// Slide the cookie expiry forward so an active user is not logged out mid-session.
if (!empty($_SESSION['user_id'])) {
    $refresh = $cookieParams;
    unset($refresh['lifetime']);
    $refresh['expires'] = time() + SESSION_LIFETIME;
    setcookie(session_name(), session_id(), $refresh);
}

// DB connection
$host = 'localhost';
$port = 3306;
$dbname = 'luftgaessli';
$dbuser = 'YOUR_DB_USER';
$dbpass = 'YOUR_DB_PASSWORD';

try {
    $pdo = new PDO(
        "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4",
        $dbuser,
        $dbpass,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed']);
    exit;
}

// CORS headers for dev (Vite dev server on :5173)
header('Content-Type: application/json; charset=utf-8');
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array($origin, ['http://localhost:5173', 'http://localhost:8080'])) {
    header("Access-Control-Allow-Origin: $origin");
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
}

// Handle preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Auth check — call this in every endpoint except auth.php
function requireAuth() {
    if (empty($_SESSION['user_id'])) {
        http_response_code(401);
        echo json_encode(['error' => 'Nicht eingeloggt']);
        exit;
    }
}

// Read JSON body
function getJsonBody(): array {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

// Send JSON response
function jsonResponse(mixed $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

// Get request method
function getMethod(): string {
    return $_SERVER['REQUEST_METHOD'];
}

// Get query param
function getParam(string $name, mixed $default = null): mixed {
    return $_GET[$name] ?? $default;
}
