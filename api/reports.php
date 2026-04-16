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

if ($month) {
    $startDate = "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-01";
    $endDate = date('Y-m-t', strtotime($startDate));

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

$stmt = $pdo->prepare('
    SELECT MONTH(o.order_date) AS month, COUNT(*) AS order_count, SUM(o.amount) AS income
    FROM orders o WHERE YEAR(o.order_date) = ? GROUP BY MONTH(o.order_date) ORDER BY month
');
$stmt->execute([$year]);
$monthlyOrders = $stmt->fetchAll();

$stmt2 = $pdo->prepare('
    SELECT MONTH(e.expense_date) AS month, COUNT(*) AS expense_count, SUM(e.amount) AS expenses
    FROM expenses e WHERE YEAR(e.expense_date) = ? GROUP BY MONTH(e.expense_date) ORDER BY month
');
$stmt2->execute([$year]);
$monthlyExpenses = $stmt2->fetchAll();

$months = [];
for ($m = 1; $m <= 12; $m++) {
    $income = 0; $expenseTotal = 0; $orderCount = 0; $expenseCount = 0;
    foreach ($monthlyOrders as $row) {
        if ((int)$row['month'] === $m) { $income = (float)$row['income']; $orderCount = (int)$row['order_count']; break; }
    }
    foreach ($monthlyExpenses as $row) {
        if ((int)$row['month'] === $m) { $expenseTotal = (float)$row['expenses']; $expenseCount = (int)$row['expense_count']; break; }
    }
    $months[] = ['month' => $m, 'income' => $income, 'expenses' => $expenseTotal, 'balance' => $income - $expenseTotal, 'order_count' => $orderCount, 'expense_count' => $expenseCount];
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
