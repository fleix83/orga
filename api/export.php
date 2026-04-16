<?php
require_once __DIR__ . '/config.php';
requireAuth();

$type = getParam('type', 'csv');
$month = getParam('month');
$year = getParam('year', date('Y'));

$startDate = $month
    ? "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-01"
    : "$year-01-01";
$endDate = $month
    ? date('Y-m-t', strtotime($startDate))
    : "$year-12-31";

$periodLabel = $month
    ? str_pad($month, 2, '0', STR_PAD_LEFT) . "-$year"
    : "Jahr-$year";

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
    GROUP BY o.id ORDER BY o.order_date
');
$stmt->execute([$startDate, $endDate]);
$orders = $stmt->fetchAll();

$stmt2 = $pdo->prepare('
    SELECT e.expense_date, e.description, e.amount, c.name AS category_name
    FROM expenses e JOIN categories c ON e.category_id = c.id
    WHERE e.expense_date BETWEEN ? AND ? ORDER BY e.expense_date
');
$stmt2->execute([$startDate, $endDate]);
$expenses = $stmt2->fetchAll();

$totalIncome = array_sum(array_column($orders, 'amount'));
$totalExpenses = array_sum(array_column($expenses, 'amount'));

if ($type === 'csv') {
    header_remove('Content-Type');
    header('Content-Type: text/csv; charset=utf-8');
    header("Content-Disposition: attachment; filename=\"geschaeftszahlen-$periodLabel.csv\"");

    $out = fopen('php://output', 'w');
    fprintf($out, chr(0xEF) . chr(0xBB) . chr(0xBF));
    fputcsv($out, ['Felix Weissheimer - Geschaeftszahlen ' . $periodLabel], ';');
    fputcsv($out, [], ';');
    fputcsv($out, ['EINNAHMEN'], ';');
    fputcsv($out, ['Datum', 'Kunde', 'Dienstleistung', 'Zuordnung', 'Betrag CHF'], ';');
    foreach ($orders as $o) {
        fputcsv($out, [$o['order_date'], $o['customer_name'], $o['service_names'], $o['category_name'], number_format($o['amount'], 2, '.', '')], ';');
    }
    fputcsv($out, ['', '', '', 'Total Einnahmen', number_format($totalIncome, 2, '.', '')], ';');
    fputcsv($out, [], ';');
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

if ($type === 'pdf') {
    require_once __DIR__ . '/../vendor/autoload.php';

    $pdf = new TCPDF('P', 'mm', 'A4', true, 'UTF-8');
    $pdf->SetCreator('Orga-Tool');
    $pdf->SetAuthor('Felix Weissheimer');
    $pdf->SetTitle("Geschaeftszahlen $periodLabel");
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetMargins(15, 15, 15);
    $pdf->AddPage();

    $pdf->SetFont('helvetica', 'B', 16);
    $pdf->Cell(0, 10, 'Felix Weissheimer', 0, 1, 'L');
    $pdf->SetFont('helvetica', '', 11);
    $pdf->Cell(0, 6, "Geschaeftszahlen $periodLabel", 0, 1, 'L');
    $pdf->Ln(8);

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

    $pdf->SetFont('helvetica', 'B', 12);
    $pdf->Cell(150, 8, 'Bilanz');
    $pdf->Cell(30, 8, 'CHF ' . number_format($totalIncome - $totalExpenses, 2, '.', ''), 0, 1, 'R');

    header_remove('Content-Type');
    $pdf->Output("geschaeftszahlen-$periodLabel.pdf", 'D');
    exit;
}

jsonResponse(['error' => 'Unbekannter Export-Typ. Verwende type=csv oder type=pdf'], 400);
