<?php
/**
 * Sync Orga bookings into the bewerbungenundmehr.ch Terminmanager (Slot Manager).
 *
 * Both apps share the same database, so a booking with a time simply creates a
 * blocking `events` row (hourly slot grid, slot N = N:00-N+1:00). The event id
 * is remembered in orders.tm_event_id so updates and deletes follow along.
 *
 * All entry points are best-effort: they must never break saving a booking.
 * Callers wrap them via tmSafe(); failures land in the PHP error log.
 */

const TM_USER_ID = 1;               // felix
const TM_EVENT_TYPE_NAME = 'Orga Buchung';

function tmSafe(callable $fn) {
    try {
        return $fn();
    } catch (Exception $e) {
        error_log('Terminmanager sync failed: ' . $e->getMessage());
        return null;
    }
}

// Event type used for all Orga-synced events; created once on demand.
function tmEventTypeId(PDO $pdo) {
    $stmt = $pdo->prepare('SELECT id FROM event_types WHERE user_id = ? AND name = ?');
    $stmt->execute([TM_USER_ID, TM_EVENT_TYPE_NAME]);
    $id = $stmt->fetchColumn();
    if ($id) return (int)$id;

    $stmt = $pdo->prepare('
        INSERT INTO event_types (user_id, name, color, blocks_availability, is_customer_bookable, sort_order)
        VALUES (?, ?, ?, 1, 0, 90)
    ');
    $stmt->execute([TM_USER_ID, TM_EVENT_TYPE_NAME, '#728fef']);
    return (int)$pdo->lastInsertId();
}

// Hourly grid: block every slot the booking touches, minutes rounded outward.
// No duration set -> assume one hour.
function tmComputeSlots($orderTime, $durationMinutes) {
    [$h, $m] = array_map('intval', explode(':', $orderTime));
    $start = $h + $m / 60;
    $end = $start + max((int)$durationMinutes, 60) / 60;
    return [(int)floor($start), (int)ceil($end)];
}

/**
 * Create/update/remove the blocking event for one order. Call after the order
 * row is committed.
 */
function tmSyncOrder(PDO $pdo, $orderId) {
    $stmt = $pdo->prepare('SELECT order_number, order_date, order_time, duration_minutes, customer_id, tm_event_id FROM orders WHERE id = ?');
    $stmt->execute([$orderId]);
    $order = $stmt->fetch();
    if (!$order) return;

    // No time -> nothing to block; drop a stale event if one exists.
    if (empty($order['order_time'])) {
        if ($order['tm_event_id']) {
            $pdo->prepare('DELETE FROM events WHERE id = ?')->execute([$order['tm_event_id']]);
            $pdo->prepare('UPDATE orders SET tm_event_id = NULL WHERE id = ?')->execute([$orderId]);
        }
        return;
    }

    [$startSlot, $endSlot] = tmComputeSlots($order['order_time'], $order['duration_minutes']);
    $title = trim(TM_EVENT_TYPE_NAME . ' ' . ($order['order_number'] ?? ''));

    // Re-create if the linked event was deleted in the Terminmanager meanwhile.
    $eventId = $order['tm_event_id'];
    if ($eventId) {
        $stmt = $pdo->prepare('SELECT id FROM events WHERE id = ?');
        $stmt->execute([$eventId]);
        if (!$stmt->fetchColumn()) $eventId = null;
    }

    if ($eventId) {
        $stmt = $pdo->prepare('
            UPDATE events
            SET event_date = ?, start_slot = ?, end_slot = ?, customer_id = ?, title = ?, status = "confirmed"
            WHERE id = ?
        ');
        $stmt->execute([$order['order_date'], $startSlot, $endSlot, $order['customer_id'], $title, $eventId]);
    } else {
        $stmt = $pdo->prepare('
            INSERT INTO events (user_id, event_type_id, event_date, start_slot, end_slot, customer_id, title, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, "confirmed")
        ');
        $stmt->execute([TM_USER_ID, tmEventTypeId($pdo), $order['order_date'], $startSlot, $endSlot, $order['customer_id'], $title]);
        $eventId = (int)$pdo->lastInsertId();
        $pdo->prepare('UPDATE orders SET tm_event_id = ? WHERE id = ?')->execute([$eventId, $orderId]);
    }
}

// Remove the blocking event when its order is deleted.
function tmDeleteEvent(PDO $pdo, $tmEventId) {
    if ($tmEventId) {
        $pdo->prepare('DELETE FROM events WHERE id = ?')->execute([$tmEventId]);
    }
}
