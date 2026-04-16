# Orga-Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a custom business organization tool (Kunden, Aufträge, Dienstleistungen, Inventar, Aufwand, Geschäftszahlen, Termine) as a Vue 3 SPA with a plain PHP REST-API on MariaDB.

**Architecture:** Vue 3 SPA (Composition API, Vite) communicates with plain PHP REST endpoints via fetch. PHP uses PDO for the existing MariaDB `luftgaessli` database, extended with new tables. Session-based auth. Apache serves `dist/` (Vue build) and `api/` (PHP).

**Tech Stack:** Vue 3, Vue Router, Vite, PHP 8.4, PDO, MariaDB 10.6, TCPDF, Apache (XAMPP)

**Spec:** `docs/superpowers/specs/2026-04-16-orga-tool-design.md`

---

## File Structure

```
/htdocs/orga/
├── .htaccess                         # URL rewriting for SPA
├── migration.sql                     # DB migration
├── api/
│   ├── config.php                    # DB connection + auth check + JSON helpers
│   ├── auth.php                      # Login/Logout/Session check
│   ├── customers.php                 # CRUD customers
│   ├── services.php                  # CRUD services
│   ├── categories.php                # CRUD categories (Zuordnungen)
│   ├── orders.php                    # CRUD orders + order_services
│   ├── inventory.php                 # CRUD inventory
│   ├── expenses.php                  # CRUD expenses
│   ├── appointments.php              # Read/update events from luftgaessli
│   ├── reports.php                   # Monthly/yearly business reports
│   └── export.php                    # CSV + PDF export
├── frontend/
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   └── src/
│       ├── main.js                   # Vue app entry
│       ├── App.vue                   # Layout: sidebar + router-view
│       ├── router.js                 # Vue Router config
│       ├── api.js                    # Fetch wrapper for all API calls
│       ├── style.css                 # Global styles (design system)
│       ├── components/
│       │   ├── Sidebar.vue           # Fixed left sidebar navigation
│       │   ├── InlineEdit.vue        # Reusable inline-edit cell
│       │   ├── DataTable.vue         # Reusable table with inline editing
│       │   ├── OrderModal.vue        # Order creation/edit modal
│       │   └── ConfirmDialog.vue     # Delete confirmation dialog
│       └── views/
│           ├── Login.vue             # Login screen
│           ├── Kunden.vue            # Customers screen
│           ├── Auftraege.vue         # Orders screen
│           ├── Dienstleistungen.vue  # Services screen
│           ├── Inventar.vue          # Inventory screen
│           ├── Aufwand.vue           # Expenses screen
│           ├── Geschaeftszahlen.vue  # Business reports screen
│           └── Termine.vue           # Appointments screen
└── dist/                             # Build output (generated)
```

---

## Task 1: Project Setup & Git Init

**Files:**
- Create: `.gitignore`
- Create: `frontend/package.json`
- Create: `frontend/vite.config.js`
- Create: `frontend/index.html`
- Create: `frontend/src/main.js`
- Create: `frontend/src/App.vue`

- [ ] **Step 1: Initialize git repository**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git init
```

- [ ] **Step 2: Create .gitignore**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/.gitignore`:

```
node_modules/
frontend/node_modules/
.DS_Store
.env
```

- [ ] **Step 3: Scaffold Vue 3 + Vite project**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
npm create vite@latest frontend -- --template vue
```

If the interactive prompt doesn't work, create the files manually:

Create `frontend/package.json`:

```json
{
  "name": "orga-frontend",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.5.0",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.2.0",
    "vite": "^6.2.0"
  }
}
```

- [ ] **Step 4: Configure Vite to build into dist/**

Create `frontend/vite.config.js`:

```js
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: '../dist',
    emptyOutDir: true
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '/orga/api')
      }
    }
  }
})
```

- [ ] **Step 5: Create minimal Vue entry files**

Create `frontend/index.html`:

```html
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Orga-Tool</title>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/src/main.js"></script>
</body>
</html>
```

Create `frontend/src/main.js`:

```js
import { createApp } from 'vue'
import App from './App.vue'

const app = createApp(App)
app.mount('#app')
```

Create `frontend/src/App.vue`:

```vue
<template>
  <div>
    <h1>Orga-Tool</h1>
    <p>Setup complete.</p>
  </div>
</template>
```

- [ ] **Step 6: Install dependencies and verify**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga/frontend
npm install
npm run dev
```

Expected: Vite dev server starts, browser shows "Orga-Tool / Setup complete." at localhost:5173.

Stop the dev server after verifying.

- [ ] **Step 7: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add .gitignore frontend/package.json frontend/vite.config.js frontend/index.html frontend/src/main.js frontend/src/App.vue
git commit -m "feat: scaffold Vue 3 + Vite project"
```

---

## Task 2: Database Migration

**Files:**
- Create: `migration.sql`

- [ ] **Step 1: Write migration SQL**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/migration.sql`:

```sql
-- Orga-Tool Migration
-- Erweitert die bestehende luftgaessli-DB um Tabellen fuer das Orga-Tool

-- 1. Customers erweitern
ALTER TABLE `customers`
  ADD COLUMN `salutation` VARCHAR(20) DEFAULT NULL AFTER `customer_number`,
  ADD COLUMN `street` VARCHAR(200) DEFAULT NULL AFTER `phone`,
  ADD COLUMN `zip` VARCHAR(10) DEFAULT NULL AFTER `street`,
  ADD COLUMN `city` VARCHAR(100) DEFAULT NULL AFTER `zip`,
  ADD COLUMN `nationality` VARCHAR(100) DEFAULT NULL AFTER `city`;

-- 2. Categories (Zuordnungen)
CREATE TABLE `categories` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `sort_order` INT(11) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `categories` (`name`, `sort_order`) VALUES
('Bewerbungen & Mehr', 1),
('Studio LUMINELLI', 2),
('Araceli', 3);

-- 3. Orders (Auftraege)
CREATE TABLE `orders` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `order_date` DATE NOT NULL,
  `customer_id` INT(11) NOT NULL,
  `category_id` INT(11) NOT NULL,
  `location_type` ENUM('vor_ort', 'remote') NOT NULL DEFAULT 'vor_ort',
  `amount` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `notes` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `customer_id` (`customer_id`),
  KEY `category_id` (`category_id`),
  KEY `idx_order_date` (`order_date`),
  CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE,
  CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Order Services (Dienstleistungen pro Auftrag)
CREATE TABLE `order_services` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `order_id` INT(11) NOT NULL,
  `service_id` INT(11) DEFAULT NULL,
  `custom_name` VARCHAR(200) DEFAULT NULL,
  `price` DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `order_id` (`order_id`),
  KEY `service_id` (`service_id`),
  CONSTRAINT `order_services_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `order_services_ibfk_2` FOREIGN KEY (`service_id`) REFERENCES `services` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Inventory (Inventar)
CREATE TABLE `inventory` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(200) NOT NULL,
  `value` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `purchase_date` DATE DEFAULT NULL,
  `owner` ENUM('felix', 'araceli') NOT NULL DEFAULT 'felix',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Expenses (Aufwaende)
CREATE TABLE `expenses` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `expense_date` DATE NOT NULL,
  `description` VARCHAR(300) NOT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `category_id` INT(11) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `category_id` (`category_id`),
  KEY `idx_expense_date` (`expense_date`),
  CONSTRAINT `expenses_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. App Users (Auth)
CREATE TABLE `app_users` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(50) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed admin user (password: changeme)
-- Generate hash with: php -r "echo password_hash('changeme', PASSWORD_BCRYPT);"
INSERT INTO `app_users` (`username`, `password_hash`) VALUES
('felix', '$2y$10$dummyhashreplacethiswithactualgenerated000000000000000');
```

- [ ] **Step 2: Generate the real bcrypt hash and update migration**

```bash
php -r "echo password_hash('changeme', PASSWORD_BCRYPT) . PHP_EOL;"
```

Copy the output and replace the `$2y$10$dummyhash...` placeholder in migration.sql with the real hash.

- [ ] **Step 3: Run migration against local DB**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
/Applications/XAMPP/xamppfiles/bin/mysql -u root -p luftgaessli < migration.sql
```

Expected: No errors. Verify:

```bash
/Applications/XAMPP/xamppfiles/bin/mysql -u root -p luftgaessli -e "SHOW TABLES; DESCRIBE customers; SELECT * FROM categories; SELECT * FROM app_users;"
```

Expected: New tables exist, customers has new columns, categories has 3 rows, app_users has felix.

- [ ] **Step 4: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add migration.sql
git commit -m "feat: add database migration for orga-tool tables"
```

---

## Task 3: PHP API Foundation (config.php)

**Files:**
- Create: `api/config.php`
- Create: `.htaccess`

- [ ] **Step 1: Create API config with DB connection and helpers**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/config.php`:

```php
<?php
session_start();

// DB connection
$host = 'localhost';
$port = 3306;
$dbname = 'luftgaessli';
$dbuser = 'root';
$dbpass = '';

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
```

- [ ] **Step 2: Create .htaccess for SPA routing**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/.htaccess`:

```apache
RewriteEngine On
RewriteBase /orga/

# Don't rewrite API requests
RewriteRule ^api/ - [L]

# Don't rewrite existing files (dist assets)
RewriteCond %{REQUEST_FILENAME} -f
RewriteRule ^ - [L]

# Don't rewrite existing directories
RewriteCond %{REQUEST_FILENAME} -d
RewriteRule ^ - [L]

# Rewrite everything else to dist/index.html (Vue SPA)
RewriteRule ^ dist/index.html [L]
```

- [ ] **Step 3: Test DB connection**

```bash
curl -s http://localhost:8080/orga/api/config.php | head -20
```

Expected: Should return empty or error (config.php doesn't output anything on its own — that's correct). No PHP fatal errors.

- [ ] **Step 4: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/config.php .htaccess
git commit -m "feat: add PHP API config with DB connection and helpers"
```

---

## Task 4: Auth API

**Files:**
- Create: `api/auth.php`

- [ ] **Step 1: Create auth endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/auth.php`:

```php
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
```

- [ ] **Step 2: Test login flow**

```bash
# Test check (not logged in)
curl -s -c cookies.txt http://localhost:8080/orga/api/auth.php?action=check
# Expected: {"authenticated":false}

# Test login
curl -s -b cookies.txt -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php
# Expected: {"authenticated":true,"username":"felix"}

# Test check (logged in)
curl -s -b cookies.txt http://localhost:8080/orga/api/auth.php?action=check
# Expected: {"authenticated":true,"username":"felix"}

# Test logout
curl -s -b cookies.txt -X POST http://localhost:8080/orga/api/auth.php?action=logout
# Expected: {"authenticated":false}

rm cookies.txt
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/auth.php
git commit -m "feat: add auth API with login/logout/session check"
```

---

## Task 5: Customers API

**Files:**
- Create: `api/customers.php`

- [ ] **Step 1: Create customers CRUD endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/customers.php`:

```php
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
                COUNT(DISTINCT o.id) AS order_count
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
            COUNT(DISTINCT o.id) AS order_count
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
    $stmt = $pdo->prepare('
        INSERT INTO customers (customer_number, salutation, first_name, last_name, email, phone, street, zip, city, nationality, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');
    $number = 'CUST' . date('Ymd') . rand(1000, 9999);
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
    $allowed = ['salutation', 'first_name', 'last_name', 'email', 'phone', 'street', 'zip', 'city', 'nationality', 'notes'];

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
```

- [ ] **Step 2: Test customers API**

```bash
# Login first
curl -s -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php

# List customers
curl -s -b cookies.txt http://localhost:8080/orga/api/customers.php
# Expected: JSON array with existing customers + total + order_count fields

# Create customer
curl -s -b cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"salutation":"Herr","first_name":"Test","last_name":"Kunde","email":"test@test.ch","city":"Basel"}' \
  http://localhost:8080/orga/api/customers.php
# Expected: {"id": <number>}

rm cookies.txt
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/customers.php
git commit -m "feat: add customers CRUD API"
```

---

## Task 6: Services API

**Files:**
- Create: `api/services.php`

- [ ] **Step 1: Create services CRUD endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/services.php`:

```php
<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

// GET: List all services
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

// POST: Create service
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

// PUT: Update service
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

// DELETE: Delete service
if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM services WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
```

- [ ] **Step 2: Test services API**

```bash
curl -s -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php

curl -s -b cookies.txt http://localhost:8080/orga/api/services.php
# Expected: JSON array with Lebenslauf, Bewerbungsschreiben, Etwas anderes

rm cookies.txt
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/services.php
git commit -m "feat: add services CRUD API"
```

---

## Task 7: Categories API

**Files:**
- Create: `api/categories.php`

- [ ] **Step 1: Create categories CRUD endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/categories.php`:

```php
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
```

- [ ] **Step 2: Test categories API**

```bash
curl -s -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php

curl -s -b cookies.txt http://localhost:8080/orga/api/categories.php
# Expected: ["Bewerbungen & Mehr", "Studio LUMINELLI", "Araceli"] with ids

rm cookies.txt
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/categories.php
git commit -m "feat: add categories CRUD API"
```

---

## Task 8: Orders API

**Files:**
- Create: `api/orders.php`

- [ ] **Step 1: Create orders CRUD endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/orders.php`:

```php
<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

// GET: List all orders (with customer + services) or single
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

        // Load order services
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

// POST: Create order with services
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

        // Insert order services
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

// PUT: Update order
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

        // Replace services if provided
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

// DELETE: Delete order (cascades to order_services)
if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM orders WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
```

- [ ] **Step 2: Test orders API**

```bash
curl -s -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php

# Create order (use existing customer id=2, category id=1)
curl -s -b cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"order_date":"2026-04-16","customer_id":2,"category_id":1,"location_type":"vor_ort","amount":60.00,"services":[{"service_id":1,"price":30.00},{"service_id":2,"price":30.00}]}' \
  http://localhost:8080/orga/api/orders.php
# Expected: {"id": <number>}

# List orders
curl -s -b cookies.txt http://localhost:8080/orga/api/orders.php
# Expected: JSON array with the created order, service_names populated

rm cookies.txt
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/orders.php
git commit -m "feat: add orders CRUD API with order_services"
```

---

## Task 9: Inventory API

**Files:**
- Create: `api/inventory.php`

- [ ] **Step 1: Create inventory CRUD endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/inventory.php`:

```php
<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

if ($method === 'GET') {
    if ($id) {
        $stmt = $pdo->prepare('SELECT * FROM inventory WHERE id = ?');
        $stmt->execute([$id]);
        $item = $stmt->fetch();
        if (!$item) jsonResponse(['error' => 'Inventar nicht gefunden'], 404);
        jsonResponse($item);
    }
    $stmt = $pdo->query('SELECT * FROM inventory ORDER BY name');
    jsonResponse($stmt->fetchAll());
}

if ($method === 'POST') {
    $data = getJsonBody();
    $stmt = $pdo->prepare('INSERT INTO inventory (name, value, purchase_date, owner) VALUES (?, ?, ?, ?)');
    $stmt->execute([
        $data['name'] ?? '',
        $data['value'] ?? 0,
        $data['purchase_date'] ?? null,
        $data['owner'] ?? 'felix',
    ]);
    jsonResponse(['id' => (int)$pdo->lastInsertId()], 201);
}

if ($method === 'PUT' && $id) {
    $data = getJsonBody();
    $fields = [];
    $params = [];
    $allowed = ['name', 'value', 'purchase_date', 'owner'];

    foreach ($allowed as $field) {
        if (array_key_exists($field, $data)) {
            $fields[] = "`$field` = ?";
            $params[] = $data[$field];
        }
    }

    if (empty($fields)) jsonResponse(['error' => 'Keine Felder zum Aktualisieren'], 400);

    $params[] = $id;
    $stmt = $pdo->prepare('UPDATE inventory SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);
    jsonResponse(['success' => true]);
}

if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('DELETE FROM inventory WHERE id = ?');
    $stmt->execute([$id]);
    jsonResponse(['success' => true]);
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
```

- [ ] **Step 2: Test inventory API**

```bash
curl -s -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php

curl -s -b cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"name":"Schreibtisch","value":450.00,"purchase_date":"2025-06-01","owner":"felix"}' \
  http://localhost:8080/orga/api/inventory.php
# Expected: {"id": <number>}

curl -s -b cookies.txt http://localhost:8080/orga/api/inventory.php
# Expected: JSON array with the created item

rm cookies.txt
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/inventory.php
git commit -m "feat: add inventory CRUD API"
```

---

## Task 10: Expenses API

**Files:**
- Create: `api/expenses.php`

- [ ] **Step 1: Create expenses CRUD endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/expenses.php`:

```php
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
```

- [ ] **Step 2: Test expenses API**

```bash
curl -s -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php

curl -s -b cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"expense_date":"2026-04-01","description":"Druckerpapier","amount":25.50,"category_id":1}' \
  http://localhost:8080/orga/api/expenses.php
# Expected: {"id": <number>}

rm cookies.txt
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/expenses.php
git commit -m "feat: add expenses CRUD API"
```

---

## Task 11: Appointments API

**Files:**
- Create: `api/appointments.php`

- [ ] **Step 1: Create appointments read/update endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/appointments.php`:

```php
<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
$id = getParam('id');

// GET: List appointments from existing events/bookings
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

// PUT: Update event status and notes only
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

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
```

- [ ] **Step 2: Test appointments API**

```bash
curl -s -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php

curl -s -b cookies.txt http://localhost:8080/orga/api/appointments.php
# Expected: JSON array with event id=28 and its details

rm cookies.txt
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/appointments.php
git commit -m "feat: add appointments read/update API"
```

---

## Task 12: Reports & Export API

**Files:**
- Create: `api/reports.php`
- Create: `api/export.php`

- [ ] **Step 1: Create reports endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/reports.php`:

```php
<?php
require_once __DIR__ . '/config.php';
requireAuth();

$method = getMethod();
if ($method !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$month = getParam('month');
$year = getParam('year', date('Y'));

// Monthly report
if ($month) {
    $startDate = "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-01";
    $endDate = date('Y-m-t', strtotime($startDate));

    // Orders for month
    $stmt = $pdo->prepare('
        SELECT o.*,
            c.first_name AS customer_first_name,
            c.last_name AS customer_last_name,
            cat.name AS category_name,
            GROUP_CONCAT(COALESCE(s.name, os.custom_name) SEPARATOR ", ") AS service_names
        FROM orders o
        JOIN customers c ON o.customer_id = c.id
        JOIN categories cat ON o.category_id = cat.id
        LEFT JOIN order_services os ON os.order_id = o.id
        LEFT JOIN services s ON os.service_id = s.id
        WHERE o.order_date BETWEEN ? AND ?
        GROUP BY o.id
        ORDER BY o.order_date
    ');
    $stmt->execute([$startDate, $endDate]);
    $orders = $stmt->fetchAll();

    // Expenses for month
    $stmt2 = $pdo->prepare('
        SELECT e.*, c.name AS category_name
        FROM expenses e
        JOIN categories c ON e.category_id = c.id
        WHERE e.expense_date BETWEEN ? AND ?
        ORDER BY e.expense_date
    ');
    $stmt2->execute([$startDate, $endDate]);
    $expenses = $stmt2->fetchAll();

    $totalIncome = array_sum(array_column($orders, 'amount'));
    $totalExpenses = array_sum(array_column($expenses, 'amount'));

    jsonResponse([
        'period' => ['year' => (int)$year, 'month' => (int)$month],
        'orders' => $orders,
        'expenses' => $expenses,
        'total_income' => $totalIncome,
        'total_expenses' => $totalExpenses,
        'balance' => $totalIncome - $totalExpenses,
    ]);
}

// Yearly report (aggregated per month)
$stmt = $pdo->prepare('
    SELECT
        MONTH(o.order_date) AS month,
        COUNT(*) AS order_count,
        SUM(o.amount) AS income
    FROM orders o
    WHERE YEAR(o.order_date) = ?
    GROUP BY MONTH(o.order_date)
    ORDER BY month
');
$stmt->execute([$year]);
$monthlyOrders = $stmt->fetchAll();

$stmt2 = $pdo->prepare('
    SELECT
        MONTH(e.expense_date) AS month,
        COUNT(*) AS expense_count,
        SUM(e.amount) AS expenses
    FROM expenses e
    WHERE YEAR(e.expense_date) = ?
    GROUP BY MONTH(e.expense_date)
    ORDER BY month
');
$stmt2->execute([$year]);
$monthlyExpenses = $stmt2->fetchAll();

// Merge into 12-month array
$months = [];
for ($m = 1; $m <= 12; $m++) {
    $income = 0;
    $expenseTotal = 0;
    $orderCount = 0;
    $expenseCount = 0;

    foreach ($monthlyOrders as $row) {
        if ((int)$row['month'] === $m) {
            $income = (float)$row['income'];
            $orderCount = (int)$row['order_count'];
            break;
        }
    }
    foreach ($monthlyExpenses as $row) {
        if ((int)$row['month'] === $m) {
            $expenseTotal = (float)$row['expenses'];
            $expenseCount = (int)$row['expense_count'];
            break;
        }
    }

    $months[] = [
        'month' => $m,
        'income' => $income,
        'expenses' => $expenseTotal,
        'balance' => $income - $expenseTotal,
        'order_count' => $orderCount,
        'expense_count' => $expenseCount,
    ];
}

$totalIncome = array_sum(array_column($months, 'income'));
$totalExpenses = array_sum(array_column($months, 'expenses'));

jsonResponse([
    'period' => ['year' => (int)$year],
    'months' => $months,
    'total_income' => $totalIncome,
    'total_expenses' => $totalExpenses,
    'balance' => $totalIncome - $totalExpenses,
]);
```

- [ ] **Step 2: Create export endpoint**

Create `/Applications/XAMPP/xamppfiles/htdocs/orga/api/export.php`:

```php
<?php
require_once __DIR__ . '/config.php';
requireAuth();

$type = getParam('type', 'csv');
$month = getParam('month');
$year = getParam('year', date('Y'));

// Fetch report data (same logic as reports.php for month)
$startDate = $month
    ? "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-01"
    : "$year-01-01";
$endDate = $month
    ? date('Y-m-t', strtotime($startDate))
    : "$year-12-31";

$periodLabel = $month
    ? str_pad($month, 2, '0', STR_PAD_LEFT) . "/$year"
    : "Jahr $year";

// Orders
$stmt = $pdo->prepare('
    SELECT o.order_date, o.amount, o.location_type,
        CONCAT(c.first_name, " ", c.last_name) AS customer_name,
        cat.name AS category_name,
        GROUP_CONCAT(COALESCE(s.name, os.custom_name) SEPARATOR ", ") AS service_names
    FROM orders o
    JOIN customers c ON o.customer_id = c.id
    JOIN categories cat ON o.category_id = cat.id
    LEFT JOIN order_services os ON os.order_id = o.id
    LEFT JOIN services s ON os.service_id = s.id
    WHERE o.order_date BETWEEN ? AND ?
    GROUP BY o.id
    ORDER BY o.order_date
');
$stmt->execute([$startDate, $endDate]);
$orders = $stmt->fetchAll();

// Expenses
$stmt2 = $pdo->prepare('
    SELECT e.expense_date, e.description, e.amount, c.name AS category_name
    FROM expenses e
    JOIN categories c ON e.category_id = c.id
    WHERE e.expense_date BETWEEN ? AND ?
    ORDER BY e.expense_date
');
$stmt2->execute([$startDate, $endDate]);
$expenses = $stmt2->fetchAll();

$totalIncome = array_sum(array_column($orders, 'amount'));
$totalExpenses = array_sum(array_column($expenses, 'amount'));

// CSV Export
if ($type === 'csv') {
    header('Content-Type: text/csv; charset=utf-8');
    header("Content-Disposition: attachment; filename=\"geschaeftszahlen-$periodLabel.csv\"");

    // Remove JSON content type from config.php
    header_remove('Content-Type');
    header('Content-Type: text/csv; charset=utf-8');

    $out = fopen('php://output', 'w');
    fprintf($out, chr(0xEF) . chr(0xBB) . chr(0xBF)); // UTF-8 BOM for Excel

    fputcsv($out, ['Felix Weissheimer - Geschaeftszahlen ' . $periodLabel], ';');
    fputcsv($out, [], ';');

    // Orders
    fputcsv($out, ['EINNAHMEN'], ';');
    fputcsv($out, ['Datum', 'Kunde', 'Dienstleistung', 'Zuordnung', 'Betrag CHF'], ';');
    foreach ($orders as $o) {
        fputcsv($out, [$o['order_date'], $o['customer_name'], $o['service_names'], $o['category_name'], number_format($o['amount'], 2, '.', '')], ';');
    }
    fputcsv($out, ['', '', '', 'Total Einnahmen', number_format($totalIncome, 2, '.', '')], ';');
    fputcsv($out, [], ';');

    // Expenses
    fputcsv($out, ['AUFWAENDE'], ';');
    fputcsv($out, ['Datum', 'Bezeichnung', 'Zuordnung', 'Betrag CHF'], ';');
    foreach ($expenses as $e) {
        fputcsv($out, [$e['expense_date'], $e['description'], $e['category_name'], number_format($e['amount'], 2, '.', '')], ';');
    }
    fputcsv($out, ['', '', 'Total Aufwaende', number_format($totalExpenses, 2, '.', '')], ';');
    fputcsv($out, [], ';');

    fputcsv($out, ['', '', 'BILANZ', number_format($totalIncome - $totalExpenses, 2, '.', '')], ';');
    fclose($out);
    exit;
}

// PDF Export using TCPDF
if ($type === 'pdf') {
    // Check if TCPDF is available
    $tcpdfPath = '/Applications/XAMPP/xamppfiles/htdocs/orga/vendor/tcpdf/tcpdf.php';
    if (!file_exists($tcpdfPath)) {
        // Fallback: try composer autoload
        $autoload = '/Applications/XAMPP/xamppfiles/htdocs/orga/vendor/autoload.php';
        if (file_exists($autoload)) {
            require_once $autoload;
        } else {
            http_response_code(500);
            echo json_encode(['error' => 'TCPDF nicht installiert. Bitte "composer require tecnickcom/tcpdf" ausfuehren.']);
            exit;
        }
    } else {
        require_once $tcpdfPath;
    }

    $pdf = new TCPDF('P', 'mm', 'A4', true, 'UTF-8');
    $pdf->SetCreator('Orga-Tool');
    $pdf->SetAuthor('Felix Weissheimer');
    $pdf->SetTitle("Geschaeftszahlen $periodLabel");
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetMargins(15, 15, 15);
    $pdf->AddPage();

    // Header
    $pdf->SetFont('helvetica', 'B', 16);
    $pdf->Cell(0, 10, 'Felix Weissheimer', 0, 1, 'L');
    $pdf->SetFont('helvetica', '', 11);
    $pdf->Cell(0, 6, "Geschaeftszahlen $periodLabel", 0, 1, 'L');
    $pdf->Ln(8);

    // Orders table
    $pdf->SetFont('helvetica', 'B', 12);
    $pdf->Cell(0, 8, 'Einnahmen', 0, 1);
    $pdf->SetFont('helvetica', 'B', 9);
    $pdf->Cell(25, 7, 'Datum', 1);
    $pdf->Cell(45, 7, 'Kunde', 1);
    $pdf->Cell(55, 7, 'Dienstleistung', 1);
    $pdf->Cell(35, 7, 'Zuordnung', 1);
    $pdf->Cell(20, 7, 'CHF', 1, 1, 'R');

    $pdf->SetFont('helvetica', '', 9);
    foreach ($orders as $o) {
        $pdf->Cell(25, 6, $o['order_date'], 1);
        $pdf->Cell(45, 6, $o['customer_name'], 1);
        $pdf->Cell(55, 6, $o['service_names'], 1);
        $pdf->Cell(35, 6, $o['category_name'], 1);
        $pdf->Cell(20, 6, number_format($o['amount'], 2, '.', ''), 1, 1, 'R');
    }
    $pdf->SetFont('helvetica', 'B', 9);
    $pdf->Cell(160, 7, 'Total Einnahmen', 1);
    $pdf->Cell(20, 7, number_format($totalIncome, 2, '.', ''), 1, 1, 'R');
    $pdf->Ln(6);

    // Expenses table
    $pdf->SetFont('helvetica', 'B', 12);
    $pdf->Cell(0, 8, 'Aufwaende', 0, 1);
    $pdf->SetFont('helvetica', 'B', 9);
    $pdf->Cell(25, 7, 'Datum', 1);
    $pdf->Cell(75, 7, 'Bezeichnung', 1);
    $pdf->Cell(50, 7, 'Zuordnung', 1);
    $pdf->Cell(30, 7, 'CHF', 1, 1, 'R');

    $pdf->SetFont('helvetica', '', 9);
    foreach ($expenses as $e) {
        $pdf->Cell(25, 6, $e['expense_date'], 1);
        $pdf->Cell(75, 6, $e['description'], 1);
        $pdf->Cell(50, 6, $e['category_name'], 1);
        $pdf->Cell(30, 6, number_format($e['amount'], 2, '.', ''), 1, 1, 'R');
    }
    $pdf->SetFont('helvetica', 'B', 9);
    $pdf->Cell(150, 7, 'Total Aufwaende', 1);
    $pdf->Cell(30, 7, number_format($totalExpenses, 2, '.', ''), 1, 1, 'R');
    $pdf->Ln(8);

    // Balance
    $pdf->SetFont('helvetica', 'B', 12);
    $pdf->Cell(150, 8, 'Bilanz');
    $pdf->Cell(30, 8, 'CHF ' . number_format($totalIncome - $totalExpenses, 2, '.', ''), 0, 1, 'R');

    header_remove('Content-Type');
    $pdf->Output("geschaeftszahlen-$periodLabel.pdf", 'D');
    exit;
}

jsonResponse(['error' => 'Unbekannter Export-Typ. Verwende type=csv oder type=pdf'], 400);
```

- [ ] **Step 3: Install TCPDF**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
composer require tecnickcom/tcpdf
```

Add `vendor/` to `.gitignore`:

Append to `/Applications/XAMPP/xamppfiles/htdocs/orga/.gitignore`:
```
vendor/
composer.lock
```

Create `composer.json` if it doesn't exist:

```json
{
    "require": {
        "tecnickcom/tcpdf": "^6.7"
    }
}
```

- [ ] **Step 4: Test reports and export**

```bash
curl -s -c cookies.txt -X POST -H "Content-Type: application/json" \
  -d '{"username":"felix","password":"changeme"}' \
  http://localhost:8080/orga/api/auth.php

# Monthly report
curl -s -b cookies.txt "http://localhost:8080/orga/api/reports.php?month=4&year=2026"
# Expected: JSON with orders, expenses, totals for April 2026

# Yearly report
curl -s -b cookies.txt "http://localhost:8080/orga/api/reports.php?year=2026"
# Expected: JSON with 12 months array

# CSV export
curl -s -b cookies.txt -o test.csv "http://localhost:8080/orga/api/export.php?type=csv&month=4&year=2026"
# Expected: CSV file created

# PDF export
curl -s -b cookies.txt -o test.pdf "http://localhost:8080/orga/api/export.php?type=pdf&month=4&year=2026"
# Expected: PDF file created

rm cookies.txt test.csv test.pdf
```

- [ ] **Step 5: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add api/reports.php api/export.php composer.json .gitignore
git commit -m "feat: add reports and export API (CSV + PDF)"
```

---

## Task 13: Vue App Shell — Router, Layout, Sidebar, Auth Guard

**Files:**
- Create: `frontend/src/router.js`
- Create: `frontend/src/api.js`
- Create: `frontend/src/style.css`
- Create: `frontend/src/components/Sidebar.vue`
- Modify: `frontend/src/main.js`
- Modify: `frontend/src/App.vue`

- [ ] **Step 1: Create API client**

Create `frontend/src/api.js`:

```js
const BASE = import.meta.env.DEV ? '/api' : '/orga/api'

async function request(endpoint, options = {}) {
  const url = `${BASE}/${endpoint}`
  const res = await fetch(url, {
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })

  if (res.status === 401) {
    window.location.hash = '#/login'
    throw new Error('Nicht eingeloggt')
  }

  const contentType = res.headers.get('content-type')
  if (contentType && contentType.includes('application/json')) {
    const data = await res.json()
    if (!res.ok) throw new Error(data.error || 'Fehler')
    return data
  }

  if (!res.ok) throw new Error('Fehler')
  return res
}

export const api = {
  get: (endpoint) => request(endpoint),
  post: (endpoint, data) => request(endpoint, { method: 'POST', body: JSON.stringify(data) }),
  put: (endpoint, data) => request(endpoint, { method: 'PUT', body: JSON.stringify(data) }),
  del: (endpoint) => request(endpoint, { method: 'DELETE' }),
}
```

- [ ] **Step 2: Create router**

Create `frontend/src/router.js`:

```js
import { createRouter, createWebHashHistory } from 'vue-router'
import Login from './views/Login.vue'
import Kunden from './views/Kunden.vue'
import Auftraege from './views/Auftraege.vue'
import Dienstleistungen from './views/Dienstleistungen.vue'
import Inventar from './views/Inventar.vue'
import Aufwand from './views/Aufwand.vue'
import Geschaeftszahlen from './views/Geschaeftszahlen.vue'
import Termine from './views/Termine.vue'

const routes = [
  { path: '/login', component: Login, meta: { noAuth: true } },
  { path: '/', redirect: '/kunden' },
  { path: '/kunden', component: Kunden },
  { path: '/auftraege', component: Auftraege },
  { path: '/dienstleistungen', component: Dienstleistungen },
  { path: '/inventar', component: Inventar },
  { path: '/aufwand', component: Aufwand },
  { path: '/geschaeftszahlen', component: Geschaeftszahlen },
  { path: '/termine', component: Termine },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

export default router
```

- [ ] **Step 3: Create global styles**

Create `frontend/src/style.css`:

```css
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  color: #1a1a1a;
  background: #fff;
  font-size: 14px;
  line-height: 1.5;
}

.app-layout {
  display: flex;
  min-height: 100vh;
}

.main-content {
  flex: 1;
  padding: 24px 32px;
  margin-left: 220px;
}

/* Tables */
table {
  width: 100%;
  border-collapse: collapse;
}

th, td {
  padding: 8px 12px;
  text-align: left;
  border-bottom: 1px solid #e5e7eb;
}

th {
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #6b7280;
  border-bottom: 2px solid #e5e7eb;
}

tr:hover {
  background: #f9fafb;
}

/* Buttons */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background: #fff;
  color: #1a1a1a;
  font-size: 14px;
  cursor: pointer;
}

.btn:hover {
  background: #f9fafb;
}

.btn-primary {
  background: #2563eb;
  color: #fff;
  border-color: #2563eb;
}

.btn-primary:hover {
  background: #1d4ed8;
}

.btn-danger {
  color: #dc2626;
  border-color: #fecaca;
}

.btn-danger:hover {
  background: #fef2f2;
}

.btn-sm {
  padding: 4px 10px;
  font-size: 13px;
}

/* Inputs */
input, select, textarea {
  padding: 8px 12px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  font-size: 14px;
  font-family: inherit;
  width: 100%;
}

input:focus, select:focus, textarea:focus {
  outline: none;
  border-color: #2563eb;
}

/* Page header */
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.page-header h1 {
  font-size: 20px;
  font-weight: 600;
}

/* Modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
}

.modal {
  background: #fff;
  border-radius: 8px;
  padding: 24px;
  width: 90%;
  max-width: 600px;
  max-height: 90vh;
  overflow-y: auto;
}

.modal h2 {
  font-size: 18px;
  margin-bottom: 16px;
}

.form-group {
  margin-bottom: 14px;
}

.form-group label {
  display: block;
  font-size: 13px;
  font-weight: 500;
  color: #374151;
  margin-bottom: 4px;
}

.form-actions {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
  margin-top: 20px;
}

/* Inline edit */
.inline-edit {
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 4px;
}

.inline-edit:hover {
  background: #f3f4f6;
}

.inline-edit input {
  padding: 2px 6px;
  font-size: 14px;
  width: auto;
  min-width: 60px;
}

/* Totals row */
.totals-row td {
  font-weight: 600;
  border-top: 2px solid #e5e7eb;
}

/* Search */
.search-input {
  max-width: 300px;
}

/* Toggle */
.toggle {
  cursor: pointer;
  color: #6b7280;
}

.toggle.active {
  color: #16a34a;
}

/* Expandable row */
.expand-row td {
  padding: 12px 24px;
  background: #f9fafb;
}

/* Tab bar */
.tab-bar {
  display: flex;
  gap: 0;
  border-bottom: 2px solid #e5e7eb;
  margin-bottom: 20px;
}

.tab {
  padding: 8px 20px;
  cursor: pointer;
  font-size: 14px;
  color: #6b7280;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
}

.tab.active {
  color: #2563eb;
  border-bottom-color: #2563eb;
}

/* Status badge */
.badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 500;
}

.badge-pending { background: #fef3c7; color: #92400e; }
.badge-confirmed { background: #d1fae5; color: #065f46; }
.badge-completed { background: #dbeafe; color: #1e40af; }
.badge-cancelled { background: #fee2e2; color: #991b1b; }
```

- [ ] **Step 4: Create Sidebar component**

Create `frontend/src/components/Sidebar.vue`:

```vue
<template>
  <nav class="sidebar">
    <div class="sidebar-title">Orga</div>
    <router-link v-for="item in items" :key="item.path" :to="item.path" class="sidebar-link">
      {{ item.label }}
    </router-link>
    <button class="sidebar-logout" @click="logout">Abmelden</button>
  </nav>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { api } from '../api.js'

const router = useRouter()

const items = [
  { path: '/kunden', label: 'Kunden' },
  { path: '/auftraege', label: 'Aufträge' },
  { path: '/dienstleistungen', label: 'Dienstleistungen' },
  { path: '/inventar', label: 'Inventar' },
  { path: '/aufwand', label: 'Aufwand' },
  { path: '/geschaeftszahlen', label: 'Geschäftszahlen' },
  { path: '/termine', label: 'Termine' },
]

async function logout() {
  await api.post('auth.php?action=logout')
  router.push('/login')
}
</script>

<style scoped>
.sidebar {
  position: fixed;
  left: 0;
  top: 0;
  bottom: 0;
  width: 220px;
  background: #f9fafb;
  border-right: 1px solid #e5e7eb;
  padding: 20px 0;
  display: flex;
  flex-direction: column;
}

.sidebar-title {
  font-size: 18px;
  font-weight: 700;
  padding: 0 20px 20px;
  border-bottom: 1px solid #e5e7eb;
  margin-bottom: 8px;
}

.sidebar-link {
  display: block;
  padding: 10px 20px;
  text-decoration: none;
  color: #374151;
  font-size: 14px;
}

.sidebar-link:hover {
  background: #f3f4f6;
}

.sidebar-link.router-link-active {
  color: #2563eb;
  background: #eff6ff;
  font-weight: 500;
}

.sidebar-logout {
  margin-top: auto;
  padding: 10px 20px;
  border: none;
  background: none;
  color: #6b7280;
  cursor: pointer;
  text-align: left;
  font-size: 14px;
}

.sidebar-logout:hover {
  color: #dc2626;
}
</style>
```

- [ ] **Step 5: Create placeholder view files**

Create each view file as a placeholder. These will be fully implemented in later tasks.

Create `frontend/src/views/Login.vue`:

```vue
<template>
  <div class="login-page">
    <form class="login-form" @submit.prevent="login">
      <h1>Orga-Tool</h1>
      <div class="form-group">
        <label>Benutzername</label>
        <input v-model="username" type="text" required autofocus>
      </div>
      <div class="form-group">
        <label>Passwort</label>
        <input v-model="password" type="password" required>
      </div>
      <p v-if="error" class="error">{{ error }}</p>
      <button class="btn btn-primary" type="submit" style="width:100%">Anmelden</button>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { api } from '../api.js'

const router = useRouter()
const username = ref('')
const password = ref('')
const error = ref('')

async function login() {
  error.value = ''
  try {
    await api.post('auth.php', { username: username.value, password: password.value })
    router.push('/')
  } catch (e) {
    error.value = e.message
  }
}
</script>

<style scoped>
.login-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
}

.login-form {
  width: 320px;
}

.login-form h1 {
  font-size: 22px;
  margin-bottom: 24px;
}

.error {
  color: #dc2626;
  font-size: 13px;
  margin-bottom: 12px;
}
</style>
```

Create `frontend/src/views/Kunden.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Kunden</h1>
    </div>
    <p>Wird implementiert...</p>
  </div>
</template>
```

Create `frontend/src/views/Auftraege.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Aufträge</h1>
    </div>
    <p>Wird implementiert...</p>
  </div>
</template>
```

Create `frontend/src/views/Dienstleistungen.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Dienstleistungen</h1>
    </div>
    <p>Wird implementiert...</p>
  </div>
</template>
```

Create `frontend/src/views/Inventar.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Inventar</h1>
    </div>
    <p>Wird implementiert...</p>
  </div>
</template>
```

Create `frontend/src/views/Aufwand.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Aufwand</h1>
    </div>
    <p>Wird implementiert...</p>
  </div>
</template>
```

Create `frontend/src/views/Geschaeftszahlen.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Geschäftszahlen</h1>
    </div>
    <p>Wird implementiert...</p>
  </div>
</template>
```

Create `frontend/src/views/Termine.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Termine</h1>
    </div>
    <p>Wird implementiert...</p>
  </div>
</template>
```

- [ ] **Step 6: Wire up App.vue with router and auth guard**

Replace `frontend/src/App.vue`:

```vue
<template>
  <div v-if="loading" />
  <div v-else-if="isLoginPage">
    <router-view />
  </div>
  <div v-else class="app-layout">
    <Sidebar />
    <main class="main-content">
      <router-view />
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { api } from './api.js'
import Sidebar from './components/Sidebar.vue'

const router = useRouter()
const route = useRoute()
const loading = ref(true)
const authenticated = ref(false)

const isLoginPage = computed(() => route.path === '/login')

onMounted(async () => {
  try {
    const res = await api.get('auth.php?action=check')
    authenticated.value = res.authenticated
  } catch {
    authenticated.value = false
  }

  if (!authenticated.value && route.path !== '/login') {
    router.push('/login')
  }
  loading.value = false
})

router.beforeEach((to) => {
  if (!to.meta.noAuth && !authenticated.value && !loading.value) {
    return '/login'
  }
})

watch(() => route.path, (path) => {
  if (path !== '/login') {
    authenticated.value = true
  }
})
</script>
```

- [ ] **Step 7: Update main.js to use router and styles**

Replace `frontend/src/main.js`:

```js
import { createApp } from 'vue'
import App from './App.vue'
import router from './router.js'
import './style.css'

const app = createApp(App)
app.use(router)
app.mount('#app')
```

- [ ] **Step 8: Verify the app shell works**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga/frontend
npm run dev
```

Open `http://localhost:5173` — should redirect to `#/login`. Enter `felix` / `changeme` — should show sidebar with all navigation items and placeholder content.

- [ ] **Step 9: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/
git commit -m "feat: add Vue app shell with router, sidebar, auth guard, login"
```

---

## Task 14: Reusable InlineEdit & ConfirmDialog Components

**Files:**
- Create: `frontend/src/components/InlineEdit.vue`
- Create: `frontend/src/components/ConfirmDialog.vue`

- [ ] **Step 1: Create InlineEdit component**

Create `frontend/src/components/InlineEdit.vue`:

```vue
<template>
  <span v-if="!editing" class="inline-edit" @click="startEdit">
    {{ displayValue || '–' }}
  </span>
  <input
    v-else
    ref="inputRef"
    v-model="localValue"
    :type="inputType"
    class="inline-edit"
    @keydown.enter="save"
    @keydown.tab="save"
    @keydown.escape="cancel"
    @blur="save"
  >
</template>

<script setup>
import { ref, nextTick, computed } from 'vue'

const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  type: { type: String, default: 'text' },
})

const emit = defineEmits(['update:modelValue'])

const editing = ref(false)
const localValue = ref('')
const inputRef = ref(null)

const inputType = computed(() => props.type === 'number' ? 'number' : 'text')
const displayValue = computed(() => {
  if (props.type === 'number' && props.modelValue !== null && props.modelValue !== '') {
    return Number(props.modelValue).toFixed(2)
  }
  return props.modelValue
})

function startEdit() {
  localValue.value = props.modelValue ?? ''
  editing.value = true
  nextTick(() => inputRef.value?.select())
}

function save() {
  editing.value = false
  const val = props.type === 'number' ? parseFloat(localValue.value) || 0 : localValue.value
  if (val !== props.modelValue) {
    emit('update:modelValue', val)
  }
}

function cancel() {
  editing.value = false
}
</script>
```

- [ ] **Step 2: Create ConfirmDialog component**

Create `frontend/src/components/ConfirmDialog.vue`:

```vue
<template>
  <div v-if="visible" class="modal-overlay" @click.self="cancel">
    <div class="modal" style="max-width:400px">
      <p>{{ message }}</p>
      <div class="form-actions">
        <button class="btn" @click="cancel">Abbrechen</button>
        <button class="btn btn-danger" @click="confirm">Löschen</button>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  visible: { type: Boolean, default: false },
  message: { type: String, default: 'Wirklich löschen?' },
})

const emit = defineEmits(['confirm', 'cancel'])

function confirm() { emit('confirm') }
function cancel() { emit('cancel') }
</script>
```

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/components/InlineEdit.vue frontend/src/components/ConfirmDialog.vue
git commit -m "feat: add InlineEdit and ConfirmDialog reusable components"
```

---

## Task 15: Kunden Screen

**Files:**
- Modify: `frontend/src/views/Kunden.vue`

- [ ] **Step 1: Implement full Kunden view**

Replace `frontend/src/views/Kunden.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Kunden</h1>
      <div style="display:flex;gap:8px">
        <input v-model="search" class="search-input" placeholder="Suchen..." @input="loadCustomers">
        <button class="btn btn-primary" @click="addCustomer">+ Neuer Kunde</button>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Nr.</th>
          <th>Anrede</th>
          <th>Name</th>
          <th>Vorname</th>
          <th>Ort</th>
          <th>Telefon</th>
          <th>Email</th>
          <th style="text-align:right">Total CHF</th>
          <th style="text-align:right">Termine</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <template v-for="c in customers" :key="c.id">
          <tr>
            <td>{{ c.customer_number }}</td>
            <td><InlineEdit v-model="c.salutation" @update:model-value="v => updateField(c, 'salutation', v)" /></td>
            <td><InlineEdit v-model="c.last_name" @update:model-value="v => updateField(c, 'last_name', v)" /></td>
            <td><InlineEdit v-model="c.first_name" @update:model-value="v => updateField(c, 'first_name', v)" /></td>
            <td><InlineEdit v-model="c.city" @update:model-value="v => updateField(c, 'city', v)" /></td>
            <td><InlineEdit v-model="c.phone" @update:model-value="v => updateField(c, 'phone', v)" /></td>
            <td><InlineEdit v-model="c.email" @update:model-value="v => updateField(c, 'email', v)" /></td>
            <td style="text-align:right">{{ Number(c.total || 0).toFixed(2) }}</td>
            <td style="text-align:right">{{ c.order_count || 0 }}</td>
            <td>
              <button class="btn btn-sm" @click="toggleExpand(c.id)">{{ expanded === c.id ? '▲' : '▼' }}</button>
              <button class="btn btn-sm btn-danger" @click="confirmDelete(c)">✕</button>
            </td>
          </tr>
          <tr v-if="expanded === c.id" class="expand-row">
            <td colspan="10">
              <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;max-width:600px">
                <div><label style="font-size:12px;color:#6b7280">Strasse</label><InlineEdit v-model="c.street" @update:model-value="v => updateField(c, 'street', v)" /></div>
                <div><label style="font-size:12px;color:#6b7280">PLZ</label><InlineEdit v-model="c.zip" @update:model-value="v => updateField(c, 'zip', v)" /></div>
                <div><label style="font-size:12px;color:#6b7280">Nationalität</label><InlineEdit v-model="c.nationality" @update:model-value="v => updateField(c, 'nationality', v)" /></div>
              </div>
              <div style="margin-top:8px"><label style="font-size:12px;color:#6b7280">Anmerkung</label><InlineEdit v-model="c.notes" @update:model-value="v => updateField(c, 'notes', v)" /></div>
            </td>
          </tr>
        </template>
      </tbody>
    </table>

    <ConfirmDialog
      :visible="!!deleteTarget"
      :message="`${deleteTarget?.first_name} ${deleteTarget?.last_name} wirklich löschen?`"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const customers = ref([])
const search = ref('')
const expanded = ref(null)
const deleteTarget = ref(null)

onMounted(loadCustomers)

async function loadCustomers() {
  const query = search.value ? `?search=${encodeURIComponent(search.value)}` : ''
  customers.value = await api.get(`customers.php${query}`)
}

async function addCustomer() {
  const result = await api.post('customers.php', { first_name: '', last_name: 'Neuer Kunde' })
  await loadCustomers()
  expanded.value = result.id
}

async function updateField(customer, field, value) {
  await api.put(`customers.php?id=${customer.id}`, { [field]: value })
}

function toggleExpand(id) {
  expanded.value = expanded.value === id ? null : id
}

function confirmDelete(customer) {
  deleteTarget.value = customer
}

async function doDelete() {
  await api.del(`customers.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await loadCustomers()
}
</script>
```

- [ ] **Step 2: Verify in browser**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga/frontend
npm run dev
```

Navigate to `#/kunden`. Verify: table shows customers, inline editing works, expand row shows details, add/delete works.

- [ ] **Step 3: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/views/Kunden.vue
git commit -m "feat: implement Kunden screen with inline editing"
```

---

## Task 16: Dienstleistungen Screen

**Files:**
- Modify: `frontend/src/views/Dienstleistungen.vue`

- [ ] **Step 1: Implement Dienstleistungen view**

Replace `frontend/src/views/Dienstleistungen.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Dienstleistungen</h1>
      <button class="btn btn-primary" @click="addService">+ Neue Dienstleistung</button>
    </div>

    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th style="text-align:right">Preis CHF</th>
          <th>Beschreibung</th>
          <th>Aktiv</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="s in services" :key="s.id">
          <td><InlineEdit v-model="s.name" @update:model-value="v => update(s, 'name', v)" /></td>
          <td style="text-align:right"><InlineEdit v-model="s.price" type="number" @update:model-value="v => update(s, 'price', v)" /></td>
          <td><InlineEdit v-model="s.description" @update:model-value="v => update(s, 'description', v)" /></td>
          <td>
            <span class="toggle" :class="{ active: s.active == 1 }" @click="toggleActive(s)">
              {{ s.active == 1 ? '✓ Aktiv' : '✗ Inaktiv' }}
            </span>
          </td>
          <td><button class="btn btn-sm btn-danger" @click="confirmDelete(s)">✕</button></td>
        </tr>
      </tbody>
    </table>

    <ConfirmDialog
      :visible="!!deleteTarget"
      :message="`'${deleteTarget?.name}' wirklich löschen?`"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const services = ref([])
const deleteTarget = ref(null)

onMounted(load)

async function load() {
  services.value = await api.get('services.php')
}

async function addService() {
  await api.post('services.php', { name: 'Neue Dienstleistung', price: 0, active: 1 })
  await load()
}

async function update(service, field, value) {
  await api.put(`services.php?id=${service.id}`, { [field]: value })
}

async function toggleActive(service) {
  service.active = service.active == 1 ? 0 : 1
  await api.put(`services.php?id=${service.id}`, { active: service.active })
}

function confirmDelete(service) { deleteTarget.value = service }

async function doDelete() {
  await api.del(`services.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>
```

- [ ] **Step 2: Verify and commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/views/Dienstleistungen.vue
git commit -m "feat: implement Dienstleistungen screen"
```

---

## Task 17: Aufträge Screen + OrderModal

**Files:**
- Create: `frontend/src/components/OrderModal.vue`
- Modify: `frontend/src/views/Auftraege.vue`

- [ ] **Step 1: Create OrderModal component**

Create `frontend/src/components/OrderModal.vue`:

```vue
<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal">
      <h2>{{ order.id ? 'Auftrag bearbeiten' : 'Neuer Auftrag' }}</h2>

      <div class="form-group">
        <label>Datum</label>
        <input v-model="form.order_date" type="date" required>
      </div>

      <div class="form-group">
        <label>Vor Ort / Remote</label>
        <select v-model="form.location_type">
          <option value="vor_ort">Vor Ort</option>
          <option value="remote">Remote</option>
        </select>
      </div>

      <div class="form-group">
        <label>Kunde</label>
        <select v-model="form.customer_id">
          <option v-for="c in customers" :key="c.id" :value="c.id">{{ c.first_name }} {{ c.last_name }}</option>
        </select>
      </div>

      <div class="form-group">
        <label>Dienstleistungen</label>
        <div v-for="s in availableServices" :key="s.id" style="margin-bottom:4px">
          <label style="display:flex;align-items:center;gap:8px;font-weight:normal">
            <input type="checkbox" :value="s.id" v-model="selectedServiceIds">
            {{ s.name }} (CHF {{ Number(s.price).toFixed(2) }})
          </label>
        </div>
        <div style="margin-top:8px">
          <label style="font-weight:normal">
            <input type="checkbox" v-model="hasCustomService"> Custom-Dienstleistung
          </label>
          <div v-if="hasCustomService" style="display:flex;gap:8px;margin-top:4px">
            <input v-model="customServiceName" placeholder="Bezeichnung" style="flex:2">
            <input v-model.number="customServicePrice" type="number" step="0.01" placeholder="Preis" style="flex:1">
          </div>
        </div>
      </div>

      <div class="form-group">
        <label>Betrag CHF ({{ calculatedAmount.toFixed(2) }})</label>
        <input v-model.number="form.amount" type="number" step="0.01">
      </div>

      <div class="form-group">
        <label>Zuordnung</label>
        <select v-model="form.category_id">
          <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>

      <div class="form-group">
        <label>Anmerkungen</label>
        <textarea v-model="form.notes" rows="3"></textarea>
      </div>

      <div class="form-actions">
        <button class="btn" @click="$emit('close')">Abbrechen</button>
        <button class="btn btn-primary" @click="save">Speichern</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { api } from '../api.js'

const props = defineProps({
  order: { type: Object, default: () => ({}) },
})

const emit = defineEmits(['close', 'saved'])

const customers = ref([])
const availableServices = ref([])
const categories = ref([])
const selectedServiceIds = ref([])
const hasCustomService = ref(false)
const customServiceName = ref('')
const customServicePrice = ref(0)

const form = ref({
  order_date: props.order.order_date || new Date().toISOString().slice(0, 10),
  customer_id: props.order.customer_id || null,
  category_id: props.order.category_id || 1,
  location_type: props.order.location_type || 'vor_ort',
  amount: props.order.amount || 0,
  notes: props.order.notes || '',
})

const calculatedAmount = computed(() => {
  let total = 0
  for (const id of selectedServiceIds.value) {
    const svc = availableServices.value.find(s => s.id === id)
    if (svc) total += Number(svc.price)
  }
  if (hasCustomService.value) total += Number(customServicePrice.value) || 0
  return total
})

watch(calculatedAmount, (val) => {
  form.value.amount = val
})

onMounted(async () => {
  const [c, s, cat] = await Promise.all([
    api.get('customers.php'),
    api.get('services.php'),
    api.get('categories.php'),
  ])
  customers.value = c
  availableServices.value = s.filter(x => x.active == 1)
  categories.value = cat

  // Pre-fill if editing
  if (props.order.id) {
    const full = await api.get(`orders.php?id=${props.order.id}`)
    if (full.services) {
      for (const os of full.services) {
        if (os.service_id) {
          selectedServiceIds.value.push(os.service_id)
        } else if (os.custom_name) {
          hasCustomService.value = true
          customServiceName.value = os.custom_name
          customServicePrice.value = Number(os.price)
        }
      }
    }
  }
})

async function save() {
  const services = []
  for (const id of selectedServiceIds.value) {
    const svc = availableServices.value.find(s => s.id === id)
    services.push({ service_id: id, price: Number(svc.price) })
  }
  if (hasCustomService.value && customServiceName.value) {
    services.push({ service_id: null, custom_name: customServiceName.value, price: Number(customServicePrice.value) || 0 })
  }

  const payload = { ...form.value, services }

  if (props.order.id) {
    await api.put(`orders.php?id=${props.order.id}`, payload)
  } else {
    await api.post('orders.php', payload)
  }
  emit('saved')
}
</script>
```

- [ ] **Step 2: Implement Aufträge view**

Replace `frontend/src/views/Auftraege.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Aufträge</h1>
      <button class="btn btn-primary" @click="showModal = true; editOrder = {}">+ Neuer Auftrag</button>
    </div>

    <table>
      <thead>
        <tr>
          <th>Datum</th>
          <th>Kunde</th>
          <th>Dienstleistungen</th>
          <th style="text-align:right">Betrag CHF</th>
          <th>Zuordnung</th>
          <th>Ort</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="o in orders" :key="o.id">
          <td>{{ o.order_date }}</td>
          <td>{{ o.customer_first_name }} {{ o.customer_last_name }}</td>
          <td>{{ o.service_names || '–' }}</td>
          <td style="text-align:right">{{ Number(o.amount).toFixed(2) }}</td>
          <td>{{ o.category_name }}</td>
          <td>{{ o.location_type === 'remote' ? 'Remote' : 'Vor Ort' }}</td>
          <td>
            <button class="btn btn-sm" @click="edit(o)">✎</button>
            <button class="btn btn-sm btn-danger" @click="confirmDelete(o)">✕</button>
          </td>
        </tr>
      </tbody>
    </table>

    <OrderModal
      v-if="showModal"
      :order="editOrder"
      @close="showModal = false"
      @saved="showModal = false; load()"
    />

    <ConfirmDialog
      :visible="!!deleteTarget"
      message="Auftrag wirklich löschen?"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import OrderModal from '../components/OrderModal.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const orders = ref([])
const showModal = ref(false)
const editOrder = ref({})
const deleteTarget = ref(null)

onMounted(load)

async function load() {
  orders.value = await api.get('orders.php')
}

function edit(order) {
  editOrder.value = { ...order }
  showModal.value = true
}

function confirmDelete(order) { deleteTarget.value = order }

async function doDelete() {
  await api.del(`orders.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>
```

- [ ] **Step 3: Verify and commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/components/OrderModal.vue frontend/src/views/Auftraege.vue
git commit -m "feat: implement Auftraege screen with order creation modal"
```

---

## Task 18: Inventar Screen

**Files:**
- Modify: `frontend/src/views/Inventar.vue`

- [ ] **Step 1: Implement Inventar view**

Replace `frontend/src/views/Inventar.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Inventar</h1>
      <button class="btn btn-primary" @click="addItem">+ Neues Inventar</button>
    </div>

    <table>
      <thead>
        <tr>
          <th>Bezeichnung</th>
          <th style="text-align:right">Wert CHF</th>
          <th>Kaufdatum</th>
          <th>Zuordnung</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in items" :key="item.id">
          <td><InlineEdit v-model="item.name" @update:model-value="v => update(item, 'name', v)" /></td>
          <td style="text-align:right"><InlineEdit v-model="item.value" type="number" @update:model-value="v => update(item, 'value', v)" /></td>
          <td><InlineEdit v-model="item.purchase_date" @update:model-value="v => update(item, 'purchase_date', v)" /></td>
          <td>
            <select :value="item.owner" @change="update(item, 'owner', $event.target.value)" style="padding:2px 6px;border:1px solid #e5e7eb;border-radius:4px;font-size:14px">
              <option value="felix">Felix</option>
              <option value="araceli">Araceli</option>
            </select>
          </td>
          <td><button class="btn btn-sm btn-danger" @click="confirmDelete(item)">✕</button></td>
        </tr>
        <tr class="totals-row">
          <td>Total</td>
          <td style="text-align:right">{{ totalAll.toFixed(2) }}</td>
          <td colspan="3"></td>
        </tr>
        <tr>
          <td style="color:#6b7280">Felix</td>
          <td style="text-align:right;color:#6b7280">{{ totalFelix.toFixed(2) }}</td>
          <td colspan="3"></td>
        </tr>
        <tr>
          <td style="color:#6b7280">Araceli</td>
          <td style="text-align:right;color:#6b7280">{{ totalAraceli.toFixed(2) }}</td>
          <td colspan="3"></td>
        </tr>
      </tbody>
    </table>

    <ConfirmDialog
      :visible="!!deleteTarget"
      :message="`'${deleteTarget?.name}' wirklich löschen?`"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const items = ref([])
const deleteTarget = ref(null)

const totalAll = computed(() => items.value.reduce((sum, i) => sum + Number(i.value || 0), 0))
const totalFelix = computed(() => items.value.filter(i => i.owner === 'felix').reduce((sum, i) => sum + Number(i.value || 0), 0))
const totalAraceli = computed(() => items.value.filter(i => i.owner === 'araceli').reduce((sum, i) => sum + Number(i.value || 0), 0))

onMounted(load)

async function load() { items.value = await api.get('inventory.php') }

async function addItem() {
  await api.post('inventory.php', { name: 'Neuer Eintrag', value: 0, owner: 'felix' })
  await load()
}

async function update(item, field, value) {
  item[field] = value
  await api.put(`inventory.php?id=${item.id}`, { [field]: value })
}

function confirmDelete(item) { deleteTarget.value = item }

async function doDelete() {
  await api.del(`inventory.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>
```

- [ ] **Step 2: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/views/Inventar.vue
git commit -m "feat: implement Inventar screen with owner totals"
```

---

## Task 19: Aufwand Screen

**Files:**
- Modify: `frontend/src/views/Aufwand.vue`

- [ ] **Step 1: Implement Aufwand view**

Replace `frontend/src/views/Aufwand.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Aufwand</h1>
      <button class="btn btn-primary" @click="addExpense">+ Neuer Aufwand</button>
    </div>

    <table>
      <thead>
        <tr>
          <th>Datum</th>
          <th>Bezeichnung</th>
          <th style="text-align:right">Betrag CHF</th>
          <th>Zuordnung</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="e in expenses" :key="e.id">
          <td><InlineEdit v-model="e.expense_date" @update:model-value="v => update(e, 'expense_date', v)" /></td>
          <td><InlineEdit v-model="e.description" @update:model-value="v => update(e, 'description', v)" /></td>
          <td style="text-align:right"><InlineEdit v-model="e.amount" type="number" @update:model-value="v => update(e, 'amount', v)" /></td>
          <td>
            <select :value="e.category_id" @change="update(e, 'category_id', Number($event.target.value))" style="padding:2px 6px;border:1px solid #e5e7eb;border-radius:4px;font-size:14px">
              <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </td>
          <td><button class="btn btn-sm btn-danger" @click="confirmDelete(e)">✕</button></td>
        </tr>
        <tr class="totals-row">
          <td colspan="2">Total</td>
          <td style="text-align:right">{{ total.toFixed(2) }}</td>
          <td colspan="2"></td>
        </tr>
      </tbody>
    </table>

    <ConfirmDialog
      :visible="!!deleteTarget"
      message="Aufwand wirklich löschen?"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const expenses = ref([])
const categories = ref([])
const deleteTarget = ref(null)

const total = computed(() => expenses.value.reduce((sum, e) => sum + Number(e.amount || 0), 0))

onMounted(async () => {
  const [exp, cat] = await Promise.all([api.get('expenses.php'), api.get('categories.php')])
  expenses.value = exp
  categories.value = cat
})

async function load() { expenses.value = await api.get('expenses.php') }

async function addExpense() {
  await api.post('expenses.php', { expense_date: new Date().toISOString().slice(0, 10), description: '', amount: 0, category_id: 1 })
  await load()
}

async function update(expense, field, value) {
  expense[field] = value
  await api.put(`expenses.php?id=${expense.id}`, { [field]: value })
}

function confirmDelete(e) { deleteTarget.value = e }

async function doDelete() {
  await api.del(`expenses.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>
```

- [ ] **Step 2: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/views/Aufwand.vue
git commit -m "feat: implement Aufwand screen"
```

---

## Task 20: Geschäftszahlen Screen

**Files:**
- Modify: `frontend/src/views/Geschaeftszahlen.vue`

- [ ] **Step 1: Implement Geschäftszahlen view**

Replace `frontend/src/views/Geschaeftszahlen.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Geschäftszahlen</h1>
      <div style="display:flex;gap:8px;align-items:center">
        <button class="btn btn-sm" @click="prevPeriod">←</button>
        <select v-model="selectedYear" @change="load" style="width:auto">
          <option v-for="y in years" :key="y" :value="y">{{ y }}</option>
        </select>
        <select v-model="selectedMonth" @change="load" style="width:auto">
          <option :value="null">Ganzes Jahr</option>
          <option v-for="m in 12" :key="m" :value="m">{{ monthNames[m - 1] }}</option>
        </select>
        <button class="btn btn-sm" @click="nextPeriod">→</button>
      </div>
    </div>

    <div style="display:flex;gap:8px;margin-bottom:20px">
      <a :href="exportUrl('csv')" class="btn btn-sm">CSV Export</a>
      <a :href="exportUrl('pdf')" class="btn btn-sm">PDF Export</a>
    </div>

    <!-- Monthly detail view -->
    <template v-if="selectedMonth">
      <h3 style="margin-bottom:12px">Einnahmen</h3>
      <table>
        <thead>
          <tr><th>Datum</th><th>Kunde</th><th>Dienstleistung</th><th>Zuordnung</th><th style="text-align:right">CHF</th></tr>
        </thead>
        <tbody>
          <tr v-for="o in report.orders" :key="o.id">
            <td>{{ o.order_date }}</td>
            <td>{{ o.customer_first_name }} {{ o.customer_last_name }}</td>
            <td>{{ o.service_names }}</td>
            <td>{{ o.category_name }}</td>
            <td style="text-align:right">{{ Number(o.amount).toFixed(2) }}</td>
          </tr>
          <tr class="totals-row"><td colspan="4">Total Einnahmen</td><td style="text-align:right">{{ Number(report.total_income || 0).toFixed(2) }}</td></tr>
        </tbody>
      </table>

      <h3 style="margin:20px 0 12px">Aufwände</h3>
      <table>
        <thead>
          <tr><th>Datum</th><th>Bezeichnung</th><th>Zuordnung</th><th style="text-align:right">CHF</th></tr>
        </thead>
        <tbody>
          <tr v-for="e in report.expenses" :key="e.id">
            <td>{{ e.expense_date }}</td>
            <td>{{ e.description }}</td>
            <td>{{ e.category_name }}</td>
            <td style="text-align:right">{{ Number(e.amount).toFixed(2) }}</td>
          </tr>
          <tr class="totals-row"><td colspan="3">Total Aufwände</td><td style="text-align:right">{{ Number(report.total_expenses || 0).toFixed(2) }}</td></tr>
        </tbody>
      </table>

      <table style="margin-top:20px">
        <tbody>
          <tr class="totals-row">
            <td>Bilanz</td>
            <td style="text-align:right;font-size:16px">CHF {{ Number(report.balance || 0).toFixed(2) }}</td>
          </tr>
        </tbody>
      </table>
    </template>

    <!-- Yearly overview -->
    <template v-else>
      <table>
        <thead>
          <tr><th>Monat</th><th style="text-align:right">Einnahmen</th><th style="text-align:right">Aufwände</th><th style="text-align:right">Bilanz</th><th style="text-align:right">Aufträge</th></tr>
        </thead>
        <tbody>
          <tr v-for="m in report.months" :key="m.month" style="cursor:pointer" @click="selectedMonth = m.month; load()">
            <td>{{ monthNames[m.month - 1] }}</td>
            <td style="text-align:right">{{ Number(m.income).toFixed(2) }}</td>
            <td style="text-align:right">{{ Number(m.expenses).toFixed(2) }}</td>
            <td style="text-align:right">{{ Number(m.balance).toFixed(2) }}</td>
            <td style="text-align:right">{{ m.order_count }}</td>
          </tr>
          <tr class="totals-row">
            <td>Total</td>
            <td style="text-align:right">{{ Number(report.total_income || 0).toFixed(2) }}</td>
            <td style="text-align:right">{{ Number(report.total_expenses || 0).toFixed(2) }}</td>
            <td style="text-align:right">{{ Number(report.balance || 0).toFixed(2) }}</td>
            <td></td>
          </tr>
        </tbody>
      </table>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'

const monthNames = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember']
const currentYear = new Date().getFullYear()
const years = Array.from({ length: 5 }, (_, i) => currentYear - 2 + i)

const selectedYear = ref(currentYear)
const selectedMonth = ref(null)
const report = ref({})

onMounted(load)

async function load() {
  const params = selectedMonth.value
    ? `?month=${selectedMonth.value}&year=${selectedYear.value}`
    : `?year=${selectedYear.value}`
  report.value = await api.get(`reports.php${params}`)
}

function exportUrl(type) {
  const base = import.meta.env.DEV ? '/api' : '/orga/api'
  const params = selectedMonth.value
    ? `type=${type}&month=${selectedMonth.value}&year=${selectedYear.value}`
    : `type=${type}&year=${selectedYear.value}`
  return `${base}/export.php?${params}`
}

function prevPeriod() {
  if (selectedMonth.value) {
    selectedMonth.value--
    if (selectedMonth.value < 1) { selectedMonth.value = 12; selectedYear.value-- }
  } else {
    selectedYear.value--
  }
  load()
}

function nextPeriod() {
  if (selectedMonth.value) {
    selectedMonth.value++
    if (selectedMonth.value > 12) { selectedMonth.value = 1; selectedYear.value++ }
  } else {
    selectedYear.value++
  }
  load()
}
</script>
```

- [ ] **Step 2: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/views/Geschaeftszahlen.vue
git commit -m "feat: implement Geschaeftszahlen screen with export"
```

---

## Task 21: Termine Screen

**Files:**
- Modify: `frontend/src/views/Termine.vue`

- [ ] **Step 1: Implement Termine view**

Replace `frontend/src/views/Termine.vue`:

```vue
<template>
  <div>
    <div class="page-header">
      <h1>Termine</h1>
    </div>

    <table>
      <thead>
        <tr>
          <th>Datum</th>
          <th>Uhrzeit</th>
          <th>Typ</th>
          <th>Kunde</th>
          <th>Dienstleistungen</th>
          <th style="text-align:right">CHF</th>
          <th>Status</th>
          <th>Notizen</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="t in appointments" :key="t.id">
          <td>{{ t.event_date }}</td>
          <td>{{ t.time_display }}</td>
          <td><span class="badge" :style="{ background: t.color + '33', color: t.color }">{{ t.event_type }}</span></td>
          <td>{{ t.customer_first_name ? `${t.customer_first_name} ${t.customer_last_name}` : '–' }}</td>
          <td>{{ t.service_names || '–' }}</td>
          <td style="text-align:right">{{ t.total_price ? Number(t.total_price).toFixed(2) : '–' }}</td>
          <td>
            <select :value="t.status" @change="updateStatus(t, $event.target.value)" style="padding:2px 6px;border:1px solid #e5e7eb;border-radius:4px;font-size:13px">
              <option value="pending">Ausstehend</option>
              <option value="confirmed">Bestätigt</option>
              <option value="completed">Abgeschlossen</option>
              <option value="cancelled">Abgesagt</option>
            </select>
          </td>
          <td><InlineEdit v-model="t.notes" @update:model-value="v => updateNotes(t, v)" /></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'

const appointments = ref([])

onMounted(async () => {
  appointments.value = await api.get('appointments.php')
})

async function updateStatus(appointment, status) {
  appointment.status = status
  await api.put(`appointments.php?id=${appointment.id}`, { status })
}

async function updateNotes(appointment, notes) {
  await api.put(`appointments.php?id=${appointment.id}`, { notes })
}
</script>
```

- [ ] **Step 2: Commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add frontend/src/views/Termine.vue
git commit -m "feat: implement Termine screen"
```

---

## Task 22: Build, Test & Deployment Config

**Files:**
- Modify: `frontend/vite.config.js` (if needed)
- Modify: `.gitignore`

- [ ] **Step 1: Build the Vue app**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga/frontend
npm run build
```

Expected: Build output in `../dist/` with `index.html` and `assets/` folder.

- [ ] **Step 2: Test the built app via Apache**

Open `http://localhost:8080/orga/` in a browser.

Expected: Redirects to `#/login`, login works, all screens accessible, API calls work.

Verify:
- Login with felix/changeme
- Navigate all 7 screens via sidebar
- Create a customer, edit inline, delete
- Create an order via modal
- Export CSV/PDF from Geschäftszahlen

- [ ] **Step 3: Add dist/ to git (for simple deployment)**

Update `.gitignore` — make sure `dist/` is NOT in gitignore (we want it deployed):

Verify that `.gitignore` does not contain `dist/`. If it does, remove that line.

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add dist/
git commit -m "feat: add Vue build output for deployment"
```

- [ ] **Step 4: Create production config note**

For deployment, `api/config.php` needs the production DB credentials. Create a note in the repo:

The deployment workflow is:
1. Push to GitHub
2. On the server: `git pull`
3. Update `api/config.php` with production DB credentials (do this once manually, keep it out of git)

Add `api/config.php` to `.gitignore` for production if sensitive, or use environment variables. For simplicity, you can keep a `api/config.example.php` and gitignore the actual config:

Create `api/config.example.php` — copy of `config.php` with placeholder credentials:

```php
<?php
// Copy this file to config.php and fill in your credentials
$host = 'localhost';
$port = 3306;
$dbname = 'luftgaessli';
$dbuser = 'your_user';
$dbpass = 'your_password';
// ... rest identical to config.php
```

- [ ] **Step 5: Final commit**

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/orga
git add .
git commit -m "feat: complete orga-tool v1 — ready for deployment"
```
