-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Erstellungszeit: 16. Apr 2026 um 14:11
-- Server-Version: 10.6.18-MariaDB-log
-- PHP-Version: 8.4.5

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Datenbank: `luftgaessli`
--

DELIMITER $$
--
-- Prozeduren
--
CREATE DEFINER=`luftgaessli`@`%` PROCEDURE `sp_check_availability` (IN `p_user_id` INT, IN `p_event_date` DATE, IN `p_start_slot` TINYINT, IN `p_end_slot` TINYINT, OUT `p_is_available` BOOLEAN)   BEGIN
    DECLARE conflict_count INT;
    
    -- Prüfe auf blockierte Tage
    SELECT COUNT(*) INTO conflict_count
    FROM blocked_dates
    WHERE blocked_date = p_event_date
    AND (user_id = p_user_id OR user_id IS NULL);
    
    IF conflict_count > 0 THEN
        SET p_is_available = FALSE;
    ELSE
        -- Prüfe auf überlappende Events
        SELECT COUNT(*) INTO conflict_count
        FROM events e
        JOIN event_types et ON e.event_type_id = et.id
        WHERE e.user_id = p_user_id
        AND e.event_date = p_event_date
        AND et.blocks_availability = TRUE
        AND e.status != 'cancelled'
        AND (
            (p_start_slot >= e.start_slot AND p_start_slot < e.end_slot)
            OR (p_end_slot > e.start_slot AND p_end_slot <= e.end_slot)
            OR (p_start_slot <= e.start_slot AND p_end_slot >= e.end_slot)
        );
        
        SET p_is_available = (conflict_count = 0);
    END IF;
END$$

CREATE DEFINER=`luftgaessli`@`%` PROCEDURE `sp_create_customer_booking` (IN `p_customer_number` VARCHAR(20), IN `p_first_name` VARCHAR(100), IN `p_last_name` VARCHAR(100), IN `p_email` VARCHAR(255), IN `p_phone` VARCHAR(30), IN `p_event_date` DATE, IN `p_start_slot` TINYINT, IN `p_end_slot` TINYINT, IN `p_service_ids` VARCHAR(255), IN `p_notes` TEXT, OUT `p_event_id` INT, OUT `p_success` BOOLEAN, OUT `p_message` VARCHAR(255))   BEGIN
    DECLARE v_customer_id INT;
    DECLARE v_is_available BOOLEAN;
    DECLARE v_event_type_id INT;
    DECLARE v_service_id INT;
    DECLARE v_service_price DECIMAL(10,2);
    DECLARE v_pos INT DEFAULT 1;
    DECLARE v_len INT;
    DECLARE v_item VARCHAR(10);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Datenbankfehler bei der Buchung';
    END;
    
    START TRANSACTION;
    
    -- Prüfe Verfügbarkeit
    CALL sp_check_availability(1, p_event_date, p_start_slot, p_end_slot, v_is_available);
    
    IF NOT v_is_available THEN
        SET p_success = FALSE;
        SET p_message = 'Der gewählte Zeitraum ist nicht mehr verfügbar';
        ROLLBACK;
    ELSE
        -- Kunde anlegen oder finden
        SELECT id INTO v_customer_id FROM customers 
        WHERE email = p_email OR (first_name = p_first_name AND last_name = p_last_name)
        LIMIT 1;
        
        IF v_customer_id IS NULL THEN
            INSERT INTO customers (customer_number, first_name, last_name, email, phone)
            VALUES (p_customer_number, p_first_name, p_last_name, p_email, p_phone);
            SET v_customer_id = LAST_INSERT_ID();
        END IF;
        
        -- Event-Type für Kundenbuchungen holen
        SELECT id INTO v_event_type_id FROM event_types 
        WHERE user_id = 1 AND is_customer_bookable = TRUE
        LIMIT 1;
        
        -- Event erstellen
        INSERT INTO events (user_id, event_type_id, event_date, start_slot, end_slot, customer_id, notes, status)
        VALUES (1, v_event_type_id, p_event_date, p_start_slot, p_end_slot, v_customer_id, p_notes, 'confirmed');
        
        SET p_event_id = LAST_INSERT_ID();
        
        -- Services verarbeiten (kommagetrennte IDs)
        SET v_len = LENGTH(p_service_ids);
        
        WHILE v_pos <= v_len DO
            SET v_item = SUBSTRING_INDEX(SUBSTRING_INDEX(p_service_ids, ',', v_pos), ',', -1);
            SET v_service_id = CAST(TRIM(v_item) AS UNSIGNED);
            
            IF v_service_id > 0 THEN
                SELECT price INTO v_service_price FROM services WHERE id = v_service_id;
                
                INSERT INTO bookings (event_id, service_id, price_at_booking)
                VALUES (p_event_id, v_service_id, v_service_price);
            END IF;
            
            SET v_pos = v_pos + 1;
            
            -- Abbruch wenn keine weiteren Kommas
            IF LOCATE(',', p_service_ids, v_pos) = 0 AND v_pos <= v_len THEN
                SET v_item = SUBSTRING(p_service_ids, v_pos);
                SET v_service_id = CAST(TRIM(v_item) AS UNSIGNED);
                
                IF v_service_id > 0 THEN
                    SELECT price INTO v_service_price FROM services WHERE id = v_service_id;
                    
                    INSERT INTO bookings (event_id, service_id, price_at_booking)
                    VALUES (p_event_id, v_service_id, v_service_price);
                END IF;
                
                SET v_pos = v_len + 1;
            END IF;
        END WHILE;
        
        COMMIT;
        SET p_success = TRUE;
        SET p_message = 'Buchung erfolgreich erstellt';
    END IF;
END$$

CREATE DEFINER=`luftgaessli`@`%` PROCEDURE `sp_get_available_slots_for_date` (IN `p_user_id` INT, IN `p_event_date` DATE, IN `p_required_slots` INT)   BEGIN
    SELECT 
        s.slot_hour AS start_slot,
        s.slot_hour + p_required_slots AS end_slot,
        CONCAT(
            LPAD(s.slot_hour, 2, '0'), ':00 - ', 
            LPAD(s.slot_hour + p_required_slots, 2, '0'), ':00'
        ) AS time_display,
        CASE 
            WHEN bd.id IS NOT NULL THEN 'blocked_day'
            WHEN e.id IS NOT NULL THEN 'occupied'
            ELSE 'available'
        END AS status
    FROM (
        SELECT 8 AS slot_hour UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 
        UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 
        UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 
        UNION SELECT 20 UNION SELECT 21
    ) s
    LEFT JOIN blocked_dates bd ON bd.blocked_date = p_event_date 
        AND (bd.user_id = p_user_id OR bd.user_id IS NULL)
    LEFT JOIN events e ON e.user_id = p_user_id 
        AND e.event_date = p_event_date
        AND e.status != 'cancelled'
        AND s.slot_hour >= e.start_slot 
        AND s.slot_hour < e.end_slot
        AND e.event_type_id IN (
            SELECT id FROM event_types WHERE blocks_availability = TRUE
        )
    WHERE s.slot_hour + p_required_slots <= 22
    ORDER BY s.slot_hour;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `availability_settings`
--

CREATE TABLE `availability_settings` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `day_of_week` tinyint(4) NOT NULL,
  `start_slot` tinyint(4) NOT NULL,
  `end_slot` tinyint(4) NOT NULL,
  `active` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `availability_settings`
--

INSERT INTO `availability_settings` (`id`, `user_id`, `day_of_week`, `start_slot`, `end_slot`, `active`) VALUES
(1, 1, 0, 8, 22, 1),
(2, 1, 1, 8, 22, 1),
(3, 1, 2, 8, 22, 1),
(4, 1, 3, 8, 22, 1),
(5, 1, 4, 8, 22, 1),
(6, 1, 5, 8, 22, 1),
(7, 1, 6, 8, 22, 1),
(8, 2, 0, 8, 22, 1),
(9, 2, 1, 8, 22, 1),
(10, 2, 2, 8, 22, 1),
(11, 2, 3, 8, 22, 1),
(12, 2, 4, 8, 22, 1),
(13, 2, 5, 8, 22, 1),
(14, 2, 6, 8, 22, 1);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `blocked_dates`
--

CREATE TABLE `blocked_dates` (
  `id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `blocked_date` date NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `blocked_dates`
--

INSERT INTO `blocked_dates` (`id`, `user_id`, `blocked_date`, `reason`, `created_at`) VALUES
(1, NULL, '2026-01-01', 'Neujahr', '2025-12-26 18:51:23'),
(2, NULL, '2026-01-02', 'Berchtoldstag', '2025-12-26 18:51:23'),
(3, NULL, '2026-04-03', 'Karfreitag', '2025-12-26 18:51:23'),
(4, NULL, '2026-04-06', 'Ostermontag', '2025-12-26 18:51:23'),
(5, NULL, '2026-05-01', 'Tag der Arbeit', '2025-12-26 18:51:23'),
(6, NULL, '2026-05-14', 'Auffahrt', '2025-12-26 18:51:23'),
(7, NULL, '2026-05-25', 'Pfingstmontag', '2025-12-26 18:51:23'),
(8, NULL, '2026-08-01', 'Nationalfeiertag', '2025-12-26 18:51:23'),
(9, NULL, '2026-12-25', 'Weihnachten', '2025-12-26 18:51:23'),
(10, NULL, '2026-12-26', 'Stephanstag', '2025-12-26 18:51:23');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `bookings`
--

CREATE TABLE `bookings` (
  `id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL,
  `service_id` int(11) NOT NULL,
  `price_at_booking` decimal(10,2) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `bookings`
--

INSERT INTO `bookings` (`id`, `event_id`, `service_id`, `price_at_booking`, `notes`, `created_at`) VALUES
(36, 28, 1, 30.00, NULL, '2026-01-15 11:24:05'),
(37, 28, 3, 30.00, NULL, '2026-01-15 11:24:05');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `customers`
--

CREATE TABLE `customers` (
  `id` int(11) NOT NULL,
  `customer_number` varchar(20) DEFAULT NULL,
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `customers`
--

INSERT INTO `customers` (`id`, `customer_number`, `first_name`, `last_name`, `email`, `phone`, `notes`, `created_at`, `updated_at`) VALUES
(2, 'CUST202601048944', 'Felix', 'Weissheimer', 'f.weissheimer@gmx.ch', '0788923013', NULL, '2026-01-04 17:49:28', '2026-01-04 17:49:28');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `events`
--

CREATE TABLE `events` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `event_type_id` int(11) NOT NULL,
  `event_date` date NOT NULL,
  `start_slot` tinyint(4) NOT NULL,
  `end_slot` tinyint(4) NOT NULL,
  `customer_id` int(11) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `status` enum('pending','confirmed','cancelled','completed') DEFAULT 'confirmed',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `events`
--

INSERT INTO `events` (`id`, `user_id`, `event_type_id`, `event_date`, `start_slot`, `end_slot`, `customer_id`, `title`, `notes`, `status`, `created_at`, `updated_at`) VALUES
(28, 1, 1, '2026-01-17', 10, 12, 2, NULL, '', 'pending', '2026-01-15 11:24:05', '2026-01-15 11:24:05');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `event_types`
--

CREATE TABLE `event_types` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `color` varchar(7) DEFAULT '#FFD700',
  `blocks_availability` tinyint(1) DEFAULT 1,
  `is_customer_bookable` tinyint(1) DEFAULT 0,
  `sort_order` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `event_types`
--

INSERT INTO `event_types` (`id`, `user_id`, `name`, `color`, `blocks_availability`, `is_customer_bookable`, `sort_order`, `created_at`) VALUES
(1, 1, 'Termine Kunden Bewerbungen & Mehr', '#FFD700', 1, 1, 1, '2025-12-26 18:51:23'),
(2, 1, 'Arbeit Web Kunden', '#4A90D9', 1, 0, 2, '2025-12-26 18:51:23'),
(3, 1, 'Private Projekte', '#7B68EE', 1, 0, 3, '2025-12-26 18:51:23'),
(4, 1, 'Custom Termine', '#20B2AA', 1, 0, 4, '2025-12-26 18:51:23'),
(5, 1, 'Präsenzzeit Raum', '#90EE90', 0, 0, 5, '2025-12-26 18:51:23'),
(6, 2, 'Kundentermine', '#FF6B6B', 1, 0, 1, '2025-12-26 18:51:23'),
(7, 2, 'Projektarbeit', '#4ECDC4', 1, 0, 2, '2025-12-26 18:51:23'),
(8, 2, 'Custom Termine', '#20B2AA', 1, 0, 3, '2025-12-26 18:51:23'),
(9, 2, 'Präsenzzeit Raum', '#90EE90', 0, 0, 4, '2025-12-26 18:51:23');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `free_slots`
--

CREATE TABLE `free_slots` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL DEFAULT 1,
  `slot_date` date NOT NULL,
  `slot_hour` tinyint(4) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `created_by` varchar(50) DEFAULT 'system'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `free_slots`
--

INSERT INTO `free_slots` (`id`, `user_id`, `slot_date`, `slot_hour`, `created_at`, `created_by`) VALUES
(1237, 1, '2026-01-05', 9, '2026-01-06 16:44:59', 'generator'),
(1238, 1, '2026-01-05', 10, '2026-01-06 16:44:59', 'generator'),
(1239, 1, '2026-01-05', 12, '2026-01-06 16:44:59', 'generator'),
(1240, 1, '2026-01-05', 13, '2026-01-06 16:44:59', 'generator'),
(1241, 1, '2026-01-05', 15, '2026-01-06 16:44:59', 'generator'),
(1242, 1, '2026-01-05', 16, '2026-01-06 16:44:59', 'generator'),
(1243, 1, '2026-01-06', 9, '2026-01-06 16:44:59', 'generator'),
(1244, 1, '2026-01-06', 10, '2026-01-06 16:44:59', 'generator'),
(1245, 1, '2026-01-06', 12, '2026-01-06 16:44:59', 'generator'),
(1246, 1, '2026-01-06', 13, '2026-01-06 16:44:59', 'generator'),
(1249, 1, '2026-01-07', 9, '2026-01-06 16:44:59', 'generator'),
(1250, 1, '2026-01-07', 10, '2026-01-06 16:44:59', 'generator'),
(1258, 1, '2026-01-08', 14, '2026-01-06 16:44:59', 'generator'),
(1259, 1, '2026-01-08', 15, '2026-01-06 16:44:59', 'generator'),
(1260, 1, '2026-01-08', 16, '2026-01-06 16:44:59', 'generator'),
(1261, 1, '2026-01-09', 9, '2026-01-06 16:44:59', 'generator'),
(1265, 1, '2026-01-09', 15, '2026-01-06 16:44:59', 'generator'),
(1266, 1, '2026-01-09', 16, '2026-01-06 16:44:59', 'generator'),
(1269, 1, '2026-01-12', 9, '2026-01-06 16:44:59', 'generator'),
(1270, 1, '2026-01-12', 10, '2026-01-06 16:44:59', 'generator'),
(1271, 1, '2026-01-12', 13, '2026-01-06 16:44:59', 'generator'),
(1272, 1, '2026-01-12', 14, '2026-01-06 16:44:59', 'generator'),
(1273, 1, '2026-01-12', 15, '2026-01-06 16:44:59', 'generator'),
(1274, 1, '2026-01-12', 16, '2026-01-06 16:44:59', 'generator'),
(1275, 1, '2026-01-13', 9, '2026-01-06 16:44:59', 'generator'),
(1276, 1, '2026-01-13', 10, '2026-01-06 16:44:59', 'generator'),
(1277, 1, '2026-01-13', 13, '2026-01-06 16:44:59', 'generator'),
(1278, 1, '2026-01-13', 14, '2026-01-06 16:44:59', 'generator'),
(1279, 1, '2026-01-13', 15, '2026-01-06 16:44:59', 'generator'),
(1280, 1, '2026-01-13', 16, '2026-01-06 16:44:59', 'generator'),
(1281, 1, '2026-01-14', 9, '2026-01-06 16:44:59', 'generator'),
(1282, 1, '2026-01-14', 10, '2026-01-06 16:44:59', 'generator'),
(1285, 1, '2026-01-14', 15, '2026-01-06 16:44:59', 'generator'),
(1286, 1, '2026-01-14', 16, '2026-01-06 16:44:59', 'generator'),
(1287, 1, '2026-01-15', 9, '2026-01-06 16:44:59', 'generator'),
(1288, 1, '2026-01-15', 10, '2026-01-06 16:44:59', 'generator'),
(1293, 1, '2026-01-16', 9, '2026-01-06 16:44:59', 'generator'),
(1294, 1, '2026-01-16', 10, '2026-01-06 16:44:59', 'generator'),
(1295, 1, '2026-01-16', 13, '2026-01-06 16:44:59', 'generator'),
(1296, 1, '2026-01-16', 14, '2026-01-06 16:44:59', 'generator'),
(1297, 1, '2026-01-16', 15, '2026-01-06 16:44:59', 'generator'),
(1298, 1, '2026-01-16', 16, '2026-01-06 16:44:59', 'generator'),
(1299, 1, '2026-01-17', 10, '2026-01-06 16:44:59', 'generator'),
(1300, 1, '2026-01-17', 11, '2026-01-06 16:44:59', 'generator'),
(1301, 1, '2026-01-19', 9, '2026-01-06 16:44:59', 'generator'),
(1302, 1, '2026-01-19', 10, '2026-01-06 16:44:59', 'generator'),
(1303, 1, '2026-01-19', 13, '2026-01-06 16:44:59', 'generator'),
(1304, 1, '2026-01-19', 14, '2026-01-06 16:44:59', 'generator'),
(1305, 1, '2026-01-19', 15, '2026-01-06 16:44:59', 'generator'),
(1306, 1, '2026-01-19', 16, '2026-01-06 16:44:59', 'generator'),
(1307, 1, '2026-01-20', 9, '2026-01-06 16:44:59', 'generator'),
(1308, 1, '2026-01-20', 10, '2026-01-06 16:44:59', 'generator'),
(1313, 1, '2026-01-21', 9, '2026-01-06 16:44:59', 'generator'),
(1314, 1, '2026-01-21', 10, '2026-01-06 16:44:59', 'generator'),
(1315, 1, '2026-01-21', 13, '2026-01-06 16:44:59', 'generator'),
(1316, 1, '2026-01-21', 14, '2026-01-06 16:44:59', 'generator'),
(1317, 1, '2026-01-21', 15, '2026-01-06 16:44:59', 'generator'),
(1318, 1, '2026-01-21', 16, '2026-01-06 16:44:59', 'generator'),
(1319, 1, '2026-01-22', 9, '2026-01-06 16:44:59', 'generator'),
(1320, 1, '2026-01-22', 10, '2026-01-06 16:44:59', 'generator'),
(1321, 1, '2026-01-22', 12, '2026-01-06 16:44:59', 'generator'),
(1322, 1, '2026-01-22', 13, '2026-01-06 16:44:59', 'generator'),
(1323, 1, '2026-01-22', 15, '2026-01-06 16:44:59', 'generator'),
(1324, 1, '2026-01-22', 16, '2026-01-06 16:44:59', 'generator'),
(1325, 1, '2026-01-23', 9, '2026-01-06 16:44:59', 'generator'),
(1326, 1, '2026-01-23', 10, '2026-01-06 16:44:59', 'generator'),
(1327, 1, '2026-01-23', 12, '2026-01-06 16:44:59', 'generator'),
(1328, 1, '2026-01-23', 13, '2026-01-06 16:44:59', 'generator'),
(1329, 1, '2026-01-23', 15, '2026-01-06 16:44:59', 'generator'),
(1330, 1, '2026-01-23', 16, '2026-01-06 16:44:59', 'generator'),
(1331, 1, '2026-01-24', 10, '2026-01-06 16:44:59', 'generator'),
(1332, 1, '2026-01-24', 11, '2026-01-06 16:44:59', 'generator'),
(1333, 1, '2026-01-26', 9, '2026-01-06 16:44:59', 'generator'),
(1334, 1, '2026-01-26', 10, '2026-01-06 16:44:59', 'generator'),
(1335, 1, '2026-01-26', 13, '2026-01-06 16:44:59', 'generator'),
(1336, 1, '2026-01-26', 14, '2026-01-06 16:44:59', 'generator'),
(1337, 1, '2026-01-26', 15, '2026-01-06 16:44:59', 'generator'),
(1338, 1, '2026-01-26', 16, '2026-01-06 16:44:59', 'generator'),
(1339, 1, '2026-01-27', 9, '2026-01-06 16:44:59', 'generator'),
(1340, 1, '2026-01-27', 10, '2026-01-06 16:44:59', 'generator'),
(1345, 1, '2026-01-28', 9, '2026-01-06 16:44:59', 'generator'),
(1346, 1, '2026-01-28', 10, '2026-01-06 16:44:59', 'generator'),
(1347, 1, '2026-01-28', 12, '2026-01-06 16:44:59', 'generator'),
(1348, 1, '2026-01-28', 13, '2026-01-06 16:44:59', 'generator'),
(1349, 1, '2026-01-28', 15, '2026-01-06 16:44:59', 'generator'),
(1350, 1, '2026-01-28', 16, '2026-01-06 16:44:59', 'generator'),
(1351, 1, '2026-01-29', 9, '2026-01-06 16:44:59', 'generator'),
(1352, 1, '2026-01-29', 10, '2026-01-06 16:44:59', 'generator'),
(1353, 1, '2026-01-29', 13, '2026-01-06 16:44:59', 'generator'),
(1354, 1, '2026-01-29', 14, '2026-01-06 16:44:59', 'generator'),
(1355, 1, '2026-01-29', 15, '2026-01-06 16:44:59', 'generator'),
(1356, 1, '2026-01-29', 16, '2026-01-06 16:44:59', 'generator'),
(1357, 1, '2026-01-30', 9, '2026-01-06 16:44:59', 'generator'),
(1358, 1, '2026-01-30', 10, '2026-01-06 16:44:59', 'generator'),
(1359, 1, '2026-01-30', 12, '2026-01-06 16:44:59', 'generator'),
(1360, 1, '2026-01-30', 13, '2026-01-06 16:44:59', 'generator'),
(1361, 1, '2026-01-30', 15, '2026-01-06 16:44:59', 'generator'),
(1362, 1, '2026-01-30', 16, '2026-01-06 16:44:59', 'generator'),
(1363, 1, '2026-01-31', 10, '2026-01-06 16:44:59', 'generator'),
(1364, 1, '2026-01-31', 11, '2026-01-06 16:44:59', 'generator'),
(1365, 1, '2026-02-02', 9, '2026-01-06 16:44:59', 'generator'),
(1366, 1, '2026-02-02', 10, '2026-01-06 16:44:59', 'generator'),
(1367, 1, '2026-02-02', 13, '2026-01-06 16:44:59', 'generator'),
(1368, 1, '2026-02-02', 14, '2026-01-06 16:44:59', 'generator'),
(1369, 1, '2026-02-02', 15, '2026-01-06 16:44:59', 'generator'),
(1370, 1, '2026-02-02', 16, '2026-01-06 16:44:59', 'generator'),
(1371, 1, '2026-02-03', 9, '2026-01-06 16:44:59', 'generator'),
(1372, 1, '2026-02-03', 10, '2026-01-06 16:44:59', 'generator'),
(1373, 1, '2026-02-03', 12, '2026-01-06 16:44:59', 'generator'),
(1374, 1, '2026-02-03', 13, '2026-01-06 16:44:59', 'generator'),
(1375, 1, '2026-02-03', 15, '2026-01-06 16:44:59', 'generator'),
(1376, 1, '2026-02-03', 16, '2026-01-06 16:44:59', 'generator'),
(1377, 1, '2026-02-04', 9, '2026-01-06 16:44:59', 'generator'),
(1378, 1, '2026-02-04', 10, '2026-01-06 16:44:59', 'generator'),
(1379, 1, '2026-02-04', 12, '2026-01-06 16:44:59', 'generator'),
(1380, 1, '2026-02-04', 13, '2026-01-06 16:44:59', 'generator'),
(1381, 1, '2026-02-04', 15, '2026-01-06 16:44:59', 'generator'),
(1382, 1, '2026-02-04', 16, '2026-01-06 16:44:59', 'generator'),
(1383, 1, '2026-02-05', 9, '2026-01-06 16:44:59', 'generator'),
(1384, 1, '2026-02-05', 10, '2026-01-06 16:44:59', 'generator'),
(1385, 1, '2026-02-05', 13, '2026-01-06 16:44:59', 'generator'),
(1389, 1, '2026-02-06', 9, '2026-01-06 16:44:59', 'generator'),
(1390, 1, '2026-02-06', 10, '2026-01-06 16:44:59', 'generator'),
(1395, 1, '2026-02-07', 10, '2026-01-06 16:44:59', 'generator'),
(1396, 1, '2026-02-07', 11, '2026-01-06 16:44:59', 'generator'),
(1400, 1, '2026-02-09', 13, '2026-01-06 16:44:59', 'generator'),
(1401, 1, '2026-02-09', 15, '2026-01-06 16:44:59', 'generator'),
(1402, 1, '2026-02-09', 16, '2026-01-06 16:44:59', 'generator'),
(1403, 1, '2026-02-10', 9, '2026-01-06 16:44:59', 'generator'),
(1404, 1, '2026-02-10', 10, '2026-01-06 16:44:59', 'generator'),
(1405, 1, '2026-02-10', 13, '2026-01-06 16:44:59', 'generator'),
(1406, 1, '2026-02-10', 14, '2026-01-06 16:44:59', 'generator'),
(1412, 1, '2026-02-11', 14, '2026-01-06 16:44:59', 'generator'),
(1413, 1, '2026-02-11', 15, '2026-01-06 16:44:59', 'generator'),
(1414, 1, '2026-02-11', 16, '2026-01-06 16:44:59', 'generator'),
(1415, 1, '2026-02-12', 9, '2026-01-06 16:44:59', 'generator'),
(1416, 1, '2026-02-12', 10, '2026-01-06 16:44:59', 'generator'),
(1417, 1, '2026-02-12', 13, '2026-01-06 16:44:59', 'generator'),
(1421, 1, '2026-02-13', 9, '2026-01-06 16:44:59', 'generator'),
(1422, 1, '2026-02-13', 10, '2026-01-06 16:44:59', 'generator'),
(1423, 1, '2026-02-13', 13, '2026-01-06 16:44:59', 'generator'),
(1424, 1, '2026-02-13', 14, '2026-01-06 16:44:59', 'generator'),
(1425, 1, '2026-02-13', 15, '2026-01-06 16:44:59', 'generator'),
(1426, 1, '2026-02-13', 16, '2026-01-06 16:44:59', 'generator'),
(1427, 1, '2026-02-14', 10, '2026-01-06 16:44:59', 'generator'),
(1428, 1, '2026-02-14', 11, '2026-01-06 16:44:59', 'generator'),
(1432, 1, '2026-02-16', 14, '2026-01-06 16:44:59', 'generator'),
(1433, 1, '2026-02-16', 15, '2026-01-06 16:44:59', 'generator'),
(1434, 1, '2026-02-16', 16, '2026-01-06 16:44:59', 'generator'),
(1435, 1, '2026-02-17', 9, '2026-01-06 16:44:59', 'generator'),
(1436, 1, '2026-02-17', 10, '2026-01-06 16:44:59', 'generator'),
(1437, 1, '2026-02-17', 12, '2026-01-06 16:44:59', 'generator'),
(1438, 1, '2026-02-17', 13, '2026-01-06 16:44:59', 'generator'),
(1444, 1, '2026-02-18', 13, '2026-01-06 16:44:59', 'generator'),
(1445, 1, '2026-02-18', 15, '2026-01-06 16:44:59', 'generator'),
(1446, 1, '2026-02-18', 16, '2026-01-06 16:44:59', 'generator'),
(1447, 1, '2026-02-19', 9, '2026-01-06 16:44:59', 'generator'),
(1448, 1, '2026-02-19', 10, '2026-01-06 16:44:59', 'generator'),
(1449, 1, '2026-02-19', 13, '2026-01-06 16:44:59', 'generator'),
(1450, 1, '2026-02-19', 14, '2026-01-06 16:44:59', 'generator'),
(1451, 1, '2026-02-19', 15, '2026-01-06 16:44:59', 'generator'),
(1452, 1, '2026-02-19', 16, '2026-01-06 16:44:59', 'generator'),
(1453, 1, '2026-02-20', 9, '2026-01-06 16:44:59', 'generator'),
(1454, 1, '2026-02-20', 10, '2026-01-06 16:44:59', 'generator'),
(1455, 1, '2026-02-20', 12, '2026-01-06 16:44:59', 'generator'),
(1456, 1, '2026-02-20', 13, '2026-01-06 16:44:59', 'generator'),
(1457, 1, '2026-02-20', 15, '2026-01-06 16:44:59', 'generator'),
(1458, 1, '2026-02-20', 16, '2026-01-06 16:44:59', 'generator'),
(1459, 1, '2026-02-21', 10, '2026-01-06 16:44:59', 'generator'),
(1460, 1, '2026-02-21', 11, '2026-01-06 16:44:59', 'generator'),
(1464, 1, '2026-02-23', 13, '2026-01-06 16:44:59', 'generator'),
(1465, 1, '2026-02-23', 15, '2026-01-06 16:44:59', 'generator'),
(1466, 1, '2026-02-23', 16, '2026-01-06 16:44:59', 'generator'),
(1467, 1, '2026-02-24', 9, '2026-01-06 16:44:59', 'generator'),
(1468, 1, '2026-02-24', 10, '2026-01-06 16:44:59', 'generator'),
(1469, 1, '2026-02-24', 12, '2026-01-06 16:44:59', 'generator'),
(1470, 1, '2026-02-24', 13, '2026-01-06 16:44:59', 'generator'),
(1475, 1, '2026-02-25', 13, '2026-01-06 16:44:59', 'generator'),
(1476, 1, '2026-02-25', 14, '2026-01-06 16:44:59', 'generator'),
(1477, 1, '2026-02-25', 15, '2026-01-06 16:44:59', 'generator'),
(1478, 1, '2026-02-25', 16, '2026-01-06 16:44:59', 'generator'),
(1479, 1, '2026-02-26', 9, '2026-01-06 16:44:59', 'generator'),
(1480, 1, '2026-02-26', 10, '2026-01-06 16:44:59', 'generator'),
(1481, 1, '2026-02-26', 13, '2026-01-06 16:44:59', 'generator'),
(1482, 1, '2026-02-26', 14, '2026-01-06 16:44:59', 'generator'),
(1483, 1, '2026-02-26', 15, '2026-01-06 16:44:59', 'generator'),
(1484, 1, '2026-02-26', 16, '2026-01-06 16:44:59', 'generator'),
(1485, 1, '2026-02-27', 9, '2026-01-06 16:44:59', 'generator'),
(1486, 1, '2026-02-27', 10, '2026-01-06 16:44:59', 'generator'),
(1487, 1, '2026-02-27', 12, '2026-01-06 16:44:59', 'generator'),
(1488, 1, '2026-02-27', 13, '2026-01-06 16:44:59', 'generator'),
(1489, 1, '2026-02-27', 15, '2026-01-06 16:44:59', 'generator'),
(1490, 1, '2026-02-27', 16, '2026-01-06 16:44:59', 'generator'),
(1491, 1, '2026-02-28', 10, '2026-01-06 16:44:59', 'generator'),
(1492, 1, '2026-02-28', 11, '2026-01-06 16:44:59', 'generator'),
(1496, 1, '2026-03-02', 13, '2026-01-06 16:44:59', 'generator'),
(1497, 1, '2026-03-02', 15, '2026-01-06 16:44:59', 'generator'),
(1498, 1, '2026-03-02', 16, '2026-01-06 16:44:59', 'generator'),
(1499, 1, '2026-03-03', 9, '2026-01-06 16:44:59', 'generator'),
(1500, 1, '2026-03-03', 10, '2026-01-06 16:44:59', 'generator'),
(1501, 1, '2026-03-03', 13, '2026-01-06 16:44:59', 'generator'),
(1502, 1, '2026-03-03', 14, '2026-01-06 16:44:59', 'generator'),
(1508, 1, '2026-03-04', 13, '2026-01-06 16:44:59', 'generator'),
(1509, 1, '2026-03-04', 15, '2026-01-06 16:44:59', 'generator'),
(1510, 1, '2026-03-04', 16, '2026-01-06 16:44:59', 'generator'),
(1511, 1, '2026-03-05', 9, '2026-01-06 16:44:59', 'generator'),
(1512, 1, '2026-03-05', 10, '2026-01-06 16:44:59', 'generator'),
(1513, 1, '2026-03-05', 13, '2026-01-06 16:44:59', 'generator'),
(1517, 1, '2026-03-06', 9, '2026-01-06 16:44:59', 'generator'),
(1518, 1, '2026-03-06', 10, '2026-01-06 16:44:59', 'generator'),
(1519, 1, '2026-03-06', 12, '2026-01-06 16:44:59', 'generator'),
(1520, 1, '2026-03-06', 13, '2026-01-06 16:44:59', 'generator'),
(1521, 1, '2026-03-06', 15, '2026-01-06 16:44:59', 'generator'),
(1522, 1, '2026-03-06', 16, '2026-01-06 16:44:59', 'generator'),
(1523, 1, '2026-03-07', 10, '2026-01-06 16:44:59', 'generator'),
(1524, 1, '2026-03-07', 11, '2026-01-06 16:44:59', 'generator'),
(1528, 1, '2026-03-09', 13, '2026-01-06 16:44:59', 'generator'),
(1529, 1, '2026-03-09', 15, '2026-01-06 16:44:59', 'generator'),
(1530, 1, '2026-03-09', 16, '2026-01-06 16:44:59', 'generator'),
(1531, 1, '2026-03-10', 9, '2026-01-06 16:44:59', 'generator'),
(1532, 1, '2026-03-10', 10, '2026-01-06 16:44:59', 'generator'),
(1533, 1, '2026-03-10', 13, '2026-01-06 16:44:59', 'generator'),
(1534, 1, '2026-03-10', 14, '2026-01-06 16:44:59', 'generator'),
(1540, 1, '2026-03-11', 13, '2026-01-06 16:44:59', 'generator'),
(1541, 1, '2026-03-11', 15, '2026-01-06 16:44:59', 'generator'),
(1542, 1, '2026-03-11', 16, '2026-01-06 16:44:59', 'generator'),
(1543, 1, '2026-03-12', 9, '2026-01-06 16:44:59', 'generator'),
(1544, 1, '2026-03-12', 10, '2026-01-06 16:44:59', 'generator'),
(1545, 1, '2026-03-12', 13, '2026-01-06 16:44:59', 'generator'),
(1546, 1, '2026-03-12', 14, '2026-01-06 16:44:59', 'generator'),
(1549, 1, '2026-03-13', 9, '2026-01-06 16:44:59', 'generator'),
(1550, 1, '2026-03-13', 10, '2026-01-06 16:44:59', 'generator'),
(1551, 1, '2026-03-13', 12, '2026-01-06 16:44:59', 'generator'),
(1552, 1, '2026-03-13', 13, '2026-01-06 16:44:59', 'generator'),
(1553, 1, '2026-03-13', 15, '2026-01-06 16:44:59', 'generator'),
(1554, 1, '2026-03-13', 16, '2026-01-06 16:44:59', 'generator'),
(1555, 1, '2026-03-14', 10, '2026-01-06 16:44:59', 'generator'),
(1556, 1, '2026-03-14', 11, '2026-01-06 16:44:59', 'generator'),
(1560, 1, '2026-03-16', 14, '2026-01-06 16:44:59', 'generator'),
(1561, 1, '2026-03-16', 15, '2026-01-06 16:44:59', 'generator'),
(1562, 1, '2026-03-16', 16, '2026-01-06 16:44:59', 'generator'),
(1563, 1, '2026-03-17', 9, '2026-01-06 16:44:59', 'generator'),
(1564, 1, '2026-03-17', 10, '2026-01-06 16:44:59', 'generator'),
(1565, 1, '2026-03-17', 12, '2026-01-06 16:44:59', 'generator'),
(1566, 1, '2026-03-17', 13, '2026-01-06 16:44:59', 'generator'),
(1569, 1, '2026-03-18', 9, '2026-01-06 16:44:59', 'generator'),
(1570, 1, '2026-03-18', 10, '2026-01-06 16:44:59', 'generator'),
(1571, 1, '2026-03-18', 13, '2026-01-06 16:44:59', 'generator'),
(1572, 1, '2026-03-18', 14, '2026-01-06 16:44:59', 'generator'),
(1573, 1, '2026-03-18', 15, '2026-01-06 16:44:59', 'generator'),
(1574, 1, '2026-03-18', 16, '2026-01-06 16:44:59', 'generator'),
(1575, 1, '2026-03-19', 9, '2026-01-06 16:44:59', 'generator'),
(1576, 1, '2026-03-19', 10, '2026-01-06 16:44:59', 'generator'),
(1577, 1, '2026-03-19', 13, '2026-01-06 16:44:59', 'generator'),
(1578, 1, '2026-03-19', 14, '2026-01-06 16:44:59', 'generator'),
(1579, 1, '2026-03-19', 15, '2026-01-06 16:44:59', 'generator'),
(1580, 1, '2026-03-19', 16, '2026-01-06 16:44:59', 'generator'),
(1581, 1, '2026-03-20', 9, '2026-01-06 16:44:59', 'generator'),
(1582, 1, '2026-03-20', 10, '2026-01-06 16:44:59', 'generator'),
(1583, 1, '2026-03-20', 13, '2026-01-06 16:44:59', 'generator'),
(1584, 1, '2026-03-20', 14, '2026-01-06 16:44:59', 'generator'),
(1585, 1, '2026-03-20', 15, '2026-01-06 16:44:59', 'generator'),
(1586, 1, '2026-03-20', 16, '2026-01-06 16:44:59', 'generator'),
(1587, 1, '2026-03-21', 10, '2026-01-06 16:44:59', 'generator'),
(1588, 1, '2026-03-21', 11, '2026-01-06 16:44:59', 'generator'),
(1589, 1, '2026-03-23', 9, '2026-01-06 16:44:59', 'generator'),
(1590, 1, '2026-03-23', 10, '2026-01-06 16:44:59', 'generator'),
(1591, 1, '2026-03-23', 12, '2026-01-06 16:44:59', 'generator'),
(1592, 1, '2026-03-23', 13, '2026-01-06 16:44:59', 'generator'),
(1593, 1, '2026-03-23', 15, '2026-01-06 16:44:59', 'generator'),
(1594, 1, '2026-03-23', 16, '2026-01-06 16:44:59', 'generator'),
(1595, 1, '2026-03-24', 9, '2026-01-06 16:44:59', 'generator'),
(1596, 1, '2026-03-24', 10, '2026-01-06 16:44:59', 'generator'),
(1597, 1, '2026-03-24', 13, '2026-01-06 16:44:59', 'generator'),
(1598, 1, '2026-03-24', 14, '2026-01-06 16:44:59', 'generator'),
(1599, 1, '2026-03-24', 15, '2026-01-06 16:44:59', 'generator'),
(1600, 1, '2026-03-24', 16, '2026-01-06 16:44:59', 'generator'),
(1601, 1, '2026-03-25', 9, '2026-01-06 16:44:59', 'generator'),
(1602, 1, '2026-03-25', 10, '2026-01-06 16:44:59', 'generator'),
(1603, 1, '2026-03-25', 12, '2026-01-06 16:44:59', 'generator'),
(1604, 1, '2026-03-25', 13, '2026-01-06 16:44:59', 'generator'),
(1605, 1, '2026-03-25', 15, '2026-01-06 16:44:59', 'generator'),
(1606, 1, '2026-03-25', 16, '2026-01-06 16:44:59', 'generator'),
(1607, 1, '2026-03-26', 9, '2026-01-06 16:44:59', 'generator'),
(1608, 1, '2026-03-26', 10, '2026-01-06 16:44:59', 'generator'),
(1609, 1, '2026-03-26', 12, '2026-01-06 16:44:59', 'generator'),
(1610, 1, '2026-03-26', 13, '2026-01-06 16:44:59', 'generator'),
(1611, 1, '2026-03-26', 15, '2026-01-06 16:44:59', 'generator'),
(1612, 1, '2026-03-26', 16, '2026-01-06 16:44:59', 'generator'),
(1613, 1, '2026-03-27', 9, '2026-01-06 16:44:59', 'generator'),
(1614, 1, '2026-03-27', 10, '2026-01-06 16:44:59', 'generator'),
(1615, 1, '2026-03-27', 12, '2026-01-06 16:44:59', 'generator'),
(1616, 1, '2026-03-27', 13, '2026-01-06 16:44:59', 'generator'),
(1617, 1, '2026-03-27', 15, '2026-01-06 16:44:59', 'generator'),
(1618, 1, '2026-03-27', 16, '2026-01-06 16:44:59', 'generator'),
(1619, 1, '2026-03-28', 10, '2026-01-06 16:44:59', 'generator'),
(1620, 1, '2026-03-28', 11, '2026-01-06 16:44:59', 'generator'),
(1621, 1, '2026-03-30', 9, '2026-01-06 16:44:59', 'generator'),
(1622, 1, '2026-03-30', 10, '2026-01-06 16:44:59', 'generator'),
(1623, 1, '2026-03-30', 12, '2026-01-06 16:44:59', 'generator'),
(1624, 1, '2026-03-30', 13, '2026-01-06 16:44:59', 'generator'),
(1625, 1, '2026-03-30', 15, '2026-01-06 16:44:59', 'generator'),
(1626, 1, '2026-03-30', 16, '2026-01-06 16:44:59', 'generator'),
(1627, 1, '2026-03-31', 9, '2026-01-06 16:44:59', 'generator'),
(1628, 1, '2026-03-31', 10, '2026-01-06 16:44:59', 'generator'),
(1629, 1, '2026-03-31', 12, '2026-01-06 16:44:59', 'generator'),
(1630, 1, '2026-03-31', 13, '2026-01-06 16:44:59', 'generator'),
(1631, 1, '2026-03-31', 15, '2026-01-06 16:44:59', 'generator'),
(1632, 1, '2026-03-31', 16, '2026-01-06 16:44:59', 'generator'),
(1634, 1, '2026-01-07', 11, '2026-01-06 20:07:02', 'admin'),
(1635, 1, '2026-01-08', 8, '2026-01-06 20:07:11', 'admin'),
(1636, 1, '2026-01-08', 9, '2026-01-06 20:07:16', 'admin'),
(1638, 1, '2026-01-09', 8, '2026-01-06 20:07:31', 'admin'),
(1641, 1, '2026-01-09', 14, '2026-01-06 20:07:56', 'admin'),
(1642, 1, '2026-01-15', 8, '2026-01-06 20:09:28', 'admin'),
(1643, 1, '2026-01-14', 8, '2026-01-06 20:09:38', 'admin'),
(1644, 1, '2026-01-14', 11, '2026-01-06 20:09:45', 'admin'),
(1645, 1, '2026-01-20', 8, '2026-01-06 20:10:33', 'admin'),
(1646, 1, '2026-01-27', 8, '2026-01-06 20:11:06', 'admin'),
(1647, 1, '2026-02-06', 11, '2026-02-04 20:05:39', 'admin'),
(1648, 1, '2026-02-09', 14, '2026-02-04 20:05:54', 'admin'),
(1649, 1, '2026-02-12', 8, '2026-02-04 20:06:34', 'admin'),
(1650, 1, '2026-02-13', 8, '2026-02-04 20:06:43', 'admin'),
(1651, 1, '2026-02-17', 11, '2026-02-04 20:07:00', 'admin'),
(1652, 1, '2026-03-05', 11, '2026-02-04 20:08:15', 'admin'),
(1653, 1, '2026-03-05', 12, '2026-02-04 20:08:15', 'admin'),
(1654, 1, '2026-03-05', 14, '2026-02-04 20:08:20', 'admin'),
(1655, 1, '2026-03-12', 8, '2026-02-04 20:08:51', 'admin'),
(1656, 1, '2026-03-13', 11, '2026-02-04 20:08:56', 'admin'),
(1657, 1, '2026-03-02', 9, '2026-03-31 20:05:37', 'generator'),
(1658, 1, '2026-03-02', 10, '2026-03-31 20:05:37', 'generator'),
(1660, 1, '2026-03-02', 14, '2026-03-31 20:05:37', 'generator'),
(1665, 1, '2026-03-03', 12, '2026-03-31 20:05:37', 'generator'),
(1667, 1, '2026-03-03', 15, '2026-03-31 20:05:37', 'generator'),
(1668, 1, '2026-03-03', 16, '2026-03-31 20:05:37', 'generator'),
(1669, 1, '2026-03-04', 9, '2026-03-31 20:05:37', 'generator'),
(1670, 1, '2026-03-04', 10, '2026-03-31 20:05:37', 'generator'),
(1671, 1, '2026-03-04', 12, '2026-03-31 20:05:37', 'generator'),
(1679, 1, '2026-03-05', 15, '2026-03-31 20:05:37', 'generator'),
(1680, 1, '2026-03-05', 16, '2026-03-31 20:05:37', 'generator'),
(1689, 1, '2026-03-09', 9, '2026-03-31 20:05:37', 'generator'),
(1690, 1, '2026-03-09', 10, '2026-03-31 20:05:37', 'generator'),
(1692, 1, '2026-03-09', 14, '2026-03-31 20:05:37', 'generator'),
(1697, 1, '2026-03-10', 12, '2026-03-31 20:05:37', 'generator'),
(1699, 1, '2026-03-10', 15, '2026-03-31 20:05:37', 'generator'),
(1700, 1, '2026-03-10', 16, '2026-03-31 20:05:37', 'generator'),
(1701, 1, '2026-03-11', 9, '2026-03-31 20:05:37', 'generator'),
(1702, 1, '2026-03-11', 10, '2026-03-31 20:05:37', 'generator'),
(1704, 1, '2026-03-11', 14, '2026-03-31 20:05:37', 'generator'),
(1709, 1, '2026-03-12', 12, '2026-03-31 20:05:37', 'generator'),
(1711, 1, '2026-03-12', 15, '2026-03-31 20:05:37', 'generator'),
(1712, 1, '2026-03-12', 16, '2026-03-31 20:05:37', 'generator'),
(1721, 1, '2026-03-16', 9, '2026-03-31 20:05:37', 'generator'),
(1722, 1, '2026-03-16', 10, '2026-03-31 20:05:37', 'generator'),
(1723, 1, '2026-03-16', 12, '2026-03-31 20:05:37', 'generator'),
(1724, 1, '2026-03-16', 13, '2026-03-31 20:05:37', 'generator'),
(1730, 1, '2026-03-17', 14, '2026-03-31 20:05:37', 'generator'),
(1731, 1, '2026-03-17', 15, '2026-03-31 20:05:37', 'generator'),
(1732, 1, '2026-03-17', 16, '2026-03-31 20:05:37', 'generator'),
(1741, 1, '2026-03-19', 12, '2026-03-31 20:05:37', 'generator'),
(1761, 1, '2026-03-24', 12, '2026-03-31 20:05:37', 'generator'),
(1768, 1, '2026-03-25', 14, '2026-03-31 20:05:37', 'generator'),
(1774, 1, '2026-03-26', 14, '2026-03-31 20:05:37', 'generator'),
(1788, 1, '2026-03-30', 14, '2026-03-31 20:05:37', 'generator'),
(1800, 1, '2026-04-01', 14, '2026-03-31 20:05:37', 'generator'),
(1801, 1, '2026-04-01', 15, '2026-03-31 20:05:37', 'generator'),
(1802, 1, '2026-04-01', 16, '2026-03-31 20:05:37', 'generator'),
(1803, 1, '2026-04-02', 9, '2026-03-31 20:05:37', 'generator'),
(1804, 1, '2026-04-02', 10, '2026-03-31 20:05:37', 'generator'),
(1814, 1, '2026-04-07', 13, '2026-03-31 20:05:37', 'generator'),
(1815, 1, '2026-04-07', 15, '2026-03-31 20:05:37', 'generator'),
(1816, 1, '2026-04-07', 16, '2026-03-31 20:05:37', 'generator'),
(1819, 1, '2026-04-08', 13, '2026-03-31 20:05:37', 'generator'),
(1820, 1, '2026-04-08', 14, '2026-03-31 20:05:37', 'generator'),
(1821, 1, '2026-04-08', 15, '2026-03-31 20:05:37', 'generator'),
(1822, 1, '2026-04-08', 16, '2026-03-31 20:05:37', 'generator'),
(1823, 1, '2026-04-09', 9, '2026-03-31 20:05:37', 'generator'),
(1824, 1, '2026-04-09', 10, '2026-03-31 20:05:37', 'generator'),
(1829, 1, '2026-04-10', 9, '2026-03-31 20:05:37', 'generator'),
(1830, 1, '2026-04-10', 10, '2026-03-31 20:05:37', 'generator'),
(1832, 1, '2026-04-10', 14, '2026-03-31 20:05:37', 'generator'),
(1833, 1, '2026-04-10', 15, '2026-03-31 20:05:37', 'generator'),
(1834, 1, '2026-04-10', 16, '2026-03-31 20:05:37', 'generator'),
(1835, 1, '2026-04-11', 10, '2026-03-31 20:05:37', 'generator'),
(1836, 1, '2026-04-11', 11, '2026-03-31 20:05:37', 'generator'),
(1839, 1, '2026-04-13', 13, '2026-03-31 20:05:37', 'generator'),
(1840, 1, '2026-04-13', 14, '2026-03-31 20:05:37', 'generator'),
(1841, 1, '2026-04-13', 15, '2026-03-31 20:05:37', 'generator'),
(1842, 1, '2026-04-13', 16, '2026-03-31 20:05:37', 'generator'),
(1843, 1, '2026-04-14', 9, '2026-03-31 20:05:37', 'generator'),
(1844, 1, '2026-04-14', 10, '2026-03-31 20:05:37', 'generator'),
(1852, 1, '2026-04-15', 13, '2026-03-31 20:05:37', 'generator'),
(1853, 1, '2026-04-15', 15, '2026-03-31 20:05:37', 'generator'),
(1854, 1, '2026-04-15', 16, '2026-03-31 20:05:37', 'generator'),
(1856, 1, '2026-04-16', 10, '2026-03-31 20:05:37', 'generator'),
(1861, 1, '2026-04-17', 9, '2026-03-31 20:05:37', 'generator'),
(1862, 1, '2026-04-17', 10, '2026-03-31 20:05:37', 'generator'),
(1865, 1, '2026-04-17', 15, '2026-03-31 20:05:37', 'generator'),
(1866, 1, '2026-04-17', 16, '2026-03-31 20:05:37', 'generator'),
(1867, 1, '2026-04-18', 10, '2026-03-31 20:05:37', 'generator'),
(1868, 1, '2026-04-18', 11, '2026-03-31 20:05:37', 'generator'),
(1872, 1, '2026-04-20', 13, '2026-03-31 20:05:37', 'generator'),
(1873, 1, '2026-04-20', 15, '2026-03-31 20:05:37', 'generator'),
(1874, 1, '2026-04-20', 16, '2026-03-31 20:05:37', 'generator'),
(1875, 1, '2026-04-21', 9, '2026-03-31 20:05:37', 'generator'),
(1876, 1, '2026-04-21', 10, '2026-03-31 20:05:37', 'generator'),
(1877, 1, '2026-04-21', 12, '2026-03-31 20:05:37', 'generator'),
(1883, 1, '2026-04-22', 13, '2026-03-31 20:05:37', 'generator'),
(1884, 1, '2026-04-22', 14, '2026-03-31 20:05:37', 'generator'),
(1885, 1, '2026-04-22', 15, '2026-03-31 20:05:37', 'generator'),
(1886, 1, '2026-04-22', 16, '2026-03-31 20:05:37', 'generator'),
(1887, 1, '2026-04-23', 9, '2026-03-31 20:05:37', 'generator'),
(1888, 1, '2026-04-23', 10, '2026-03-31 20:05:37', 'generator'),
(1893, 1, '2026-04-24', 9, '2026-03-31 20:05:37', 'generator'),
(1894, 1, '2026-04-24', 10, '2026-03-31 20:05:37', 'generator'),
(1895, 1, '2026-04-24', 13, '2026-03-31 20:05:37', 'generator'),
(1896, 1, '2026-04-24', 14, '2026-03-31 20:05:37', 'generator'),
(1897, 1, '2026-04-24', 15, '2026-03-31 20:05:37', 'generator'),
(1899, 1, '2026-04-25', 10, '2026-03-31 20:05:37', 'generator'),
(1900, 1, '2026-04-25', 11, '2026-03-31 20:05:37', 'generator'),
(1904, 1, '2026-04-27', 13, '2026-03-31 20:05:37', 'generator'),
(1905, 1, '2026-04-27', 15, '2026-03-31 20:05:37', 'generator'),
(1906, 1, '2026-04-27', 16, '2026-03-31 20:05:37', 'generator'),
(1908, 1, '2026-04-28', 10, '2026-03-31 20:05:37', 'generator'),
(1916, 1, '2026-04-29', 13, '2026-03-31 20:05:37', 'generator'),
(1917, 1, '2026-04-29', 15, '2026-03-31 20:05:37', 'generator'),
(1918, 1, '2026-04-29', 16, '2026-03-31 20:05:37', 'generator'),
(1919, 1, '2026-04-30', 9, '2026-03-31 20:05:37', 'generator'),
(1920, 1, '2026-04-30', 10, '2026-03-31 20:05:37', 'generator'),
(1921, 1, '2026-04-30', 13, '2026-03-31 20:05:37', 'generator'),
(1922, 1, '2026-04-30', 14, '2026-03-31 20:05:37', 'generator'),
(1925, 1, '2026-05-02', 10, '2026-03-31 20:05:37', 'generator'),
(1926, 1, '2026-05-02', 11, '2026-03-31 20:05:37', 'generator'),
(1929, 1, '2026-05-04', 13, '2026-03-31 20:05:37', 'generator'),
(1930, 1, '2026-05-04', 14, '2026-03-31 20:05:37', 'generator'),
(1931, 1, '2026-05-04', 15, '2026-03-31 20:05:37', 'generator'),
(1932, 1, '2026-05-04', 16, '2026-03-31 20:05:37', 'generator'),
(1933, 1, '2026-05-05', 9, '2026-03-31 20:05:37', 'generator'),
(1934, 1, '2026-05-05', 10, '2026-03-31 20:05:37', 'generator'),
(1935, 1, '2026-05-05', 13, '2026-03-31 20:05:37', 'generator'),
(1936, 1, '2026-05-05', 14, '2026-03-31 20:05:37', 'generator'),
(1937, 1, '2026-05-05', 15, '2026-03-31 20:05:37', 'generator'),
(1938, 1, '2026-05-05', 16, '2026-03-31 20:05:37', 'generator'),
(1939, 1, '2026-05-06', 9, '2026-03-31 20:05:37', 'generator'),
(1940, 1, '2026-05-06', 10, '2026-03-31 20:05:37', 'generator'),
(1941, 1, '2026-05-06', 12, '2026-03-31 20:05:37', 'generator'),
(1942, 1, '2026-05-06', 13, '2026-03-31 20:05:37', 'generator'),
(1943, 1, '2026-05-06', 15, '2026-03-31 20:05:37', 'generator'),
(1944, 1, '2026-05-06', 16, '2026-03-31 20:05:37', 'generator'),
(1945, 1, '2026-05-07', 9, '2026-03-31 20:05:37', 'generator'),
(1946, 1, '2026-05-07', 10, '2026-03-31 20:05:37', 'generator'),
(1947, 1, '2026-05-07', 13, '2026-03-31 20:05:37', 'generator'),
(1948, 1, '2026-05-07', 14, '2026-03-31 20:05:37', 'generator'),
(1949, 1, '2026-05-07', 15, '2026-03-31 20:05:37', 'generator'),
(1950, 1, '2026-05-07', 16, '2026-03-31 20:05:37', 'generator'),
(1951, 1, '2026-05-08', 9, '2026-03-31 20:05:37', 'generator'),
(1952, 1, '2026-05-08', 10, '2026-03-31 20:05:37', 'generator'),
(1953, 1, '2026-05-08', 12, '2026-03-31 20:05:37', 'generator'),
(1954, 1, '2026-05-08', 13, '2026-03-31 20:05:37', 'generator'),
(1955, 1, '2026-05-08', 15, '2026-03-31 20:05:37', 'generator'),
(1956, 1, '2026-05-08', 16, '2026-03-31 20:05:37', 'generator'),
(1957, 1, '2026-05-09', 10, '2026-03-31 20:05:37', 'generator'),
(1958, 1, '2026-05-09', 11, '2026-03-31 20:05:37', 'generator'),
(1959, 1, '2026-05-11', 9, '2026-03-31 20:05:37', 'generator'),
(1960, 1, '2026-05-11', 10, '2026-03-31 20:05:37', 'generator'),
(1961, 1, '2026-05-11', 12, '2026-03-31 20:05:37', 'generator'),
(1962, 1, '2026-05-11', 13, '2026-03-31 20:05:37', 'generator'),
(1963, 1, '2026-05-11', 15, '2026-03-31 20:05:37', 'generator'),
(1964, 1, '2026-05-11', 16, '2026-03-31 20:05:37', 'generator'),
(1965, 1, '2026-05-12', 9, '2026-03-31 20:05:37', 'generator'),
(1966, 1, '2026-05-12', 10, '2026-03-31 20:05:37', 'generator'),
(1967, 1, '2026-05-12', 12, '2026-03-31 20:05:37', 'generator'),
(1968, 1, '2026-05-12', 13, '2026-03-31 20:05:37', 'generator'),
(1969, 1, '2026-05-12', 15, '2026-03-31 20:05:37', 'generator'),
(1970, 1, '2026-05-12', 16, '2026-03-31 20:05:37', 'generator'),
(1971, 1, '2026-05-13', 9, '2026-03-31 20:05:37', 'generator'),
(1972, 1, '2026-05-13', 10, '2026-03-31 20:05:37', 'generator'),
(1973, 1, '2026-05-13', 13, '2026-03-31 20:05:37', 'generator'),
(1974, 1, '2026-05-13', 14, '2026-03-31 20:05:37', 'generator'),
(1975, 1, '2026-05-13', 15, '2026-03-31 20:05:37', 'generator'),
(1976, 1, '2026-05-13', 16, '2026-03-31 20:05:37', 'generator'),
(1977, 1, '2026-05-15', 9, '2026-03-31 20:05:37', 'generator'),
(1978, 1, '2026-05-15', 10, '2026-03-31 20:05:37', 'generator'),
(1979, 1, '2026-05-15', 13, '2026-03-31 20:05:37', 'generator'),
(1980, 1, '2026-05-15', 14, '2026-03-31 20:05:37', 'generator'),
(1981, 1, '2026-05-15', 15, '2026-03-31 20:05:37', 'generator'),
(1982, 1, '2026-05-15', 16, '2026-03-31 20:05:37', 'generator'),
(1983, 1, '2026-05-16', 10, '2026-03-31 20:05:37', 'generator'),
(1984, 1, '2026-05-16', 11, '2026-03-31 20:05:37', 'generator'),
(1985, 1, '2026-05-18', 9, '2026-03-31 20:05:37', 'generator'),
(1986, 1, '2026-05-18', 10, '2026-03-31 20:05:37', 'generator'),
(1987, 1, '2026-05-18', 13, '2026-03-31 20:05:37', 'generator'),
(1988, 1, '2026-05-18', 14, '2026-03-31 20:05:37', 'generator'),
(1989, 1, '2026-05-18', 15, '2026-03-31 20:05:37', 'generator'),
(1990, 1, '2026-05-18', 16, '2026-03-31 20:05:37', 'generator'),
(1991, 1, '2026-05-19', 9, '2026-03-31 20:05:37', 'generator'),
(1992, 1, '2026-05-19', 10, '2026-03-31 20:05:37', 'generator'),
(1993, 1, '2026-05-19', 12, '2026-03-31 20:05:37', 'generator'),
(1994, 1, '2026-05-19', 13, '2026-03-31 20:05:37', 'generator'),
(1995, 1, '2026-05-19', 15, '2026-03-31 20:05:37', 'generator'),
(1996, 1, '2026-05-19', 16, '2026-03-31 20:05:37', 'generator'),
(1997, 1, '2026-05-20', 9, '2026-03-31 20:05:37', 'generator'),
(1998, 1, '2026-05-20', 10, '2026-03-31 20:05:37', 'generator'),
(1999, 1, '2026-05-20', 13, '2026-03-31 20:05:37', 'generator'),
(2000, 1, '2026-05-20', 14, '2026-03-31 20:05:37', 'generator'),
(2001, 1, '2026-05-20', 15, '2026-03-31 20:05:37', 'generator'),
(2002, 1, '2026-05-20', 16, '2026-03-31 20:05:37', 'generator'),
(2003, 1, '2026-05-21', 9, '2026-03-31 20:05:37', 'generator'),
(2004, 1, '2026-05-21', 10, '2026-03-31 20:05:37', 'generator'),
(2005, 1, '2026-05-21', 12, '2026-03-31 20:05:37', 'generator'),
(2006, 1, '2026-05-21', 13, '2026-03-31 20:05:37', 'generator'),
(2007, 1, '2026-05-21', 15, '2026-03-31 20:05:37', 'generator'),
(2008, 1, '2026-05-21', 16, '2026-03-31 20:05:37', 'generator'),
(2009, 1, '2026-05-22', 9, '2026-03-31 20:05:37', 'generator'),
(2010, 1, '2026-05-22', 10, '2026-03-31 20:05:37', 'generator'),
(2011, 1, '2026-05-22', 12, '2026-03-31 20:05:37', 'generator'),
(2012, 1, '2026-05-22', 13, '2026-03-31 20:05:37', 'generator'),
(2013, 1, '2026-05-22', 15, '2026-03-31 20:05:37', 'generator'),
(2014, 1, '2026-05-22', 16, '2026-03-31 20:05:37', 'generator'),
(2015, 1, '2026-05-23', 10, '2026-03-31 20:05:37', 'generator'),
(2016, 1, '2026-05-23', 11, '2026-03-31 20:05:37', 'generator'),
(2017, 1, '2026-05-26', 9, '2026-03-31 20:05:37', 'generator'),
(2018, 1, '2026-05-26', 10, '2026-03-31 20:05:37', 'generator'),
(2019, 1, '2026-05-26', 12, '2026-03-31 20:05:37', 'generator'),
(2020, 1, '2026-05-26', 13, '2026-03-31 20:05:37', 'generator'),
(2021, 1, '2026-05-26', 15, '2026-03-31 20:05:37', 'generator'),
(2022, 1, '2026-05-26', 16, '2026-03-31 20:05:37', 'generator'),
(2023, 1, '2026-05-27', 9, '2026-03-31 20:05:37', 'generator'),
(2024, 1, '2026-05-27', 10, '2026-03-31 20:05:37', 'generator'),
(2025, 1, '2026-05-27', 13, '2026-03-31 20:05:37', 'generator'),
(2026, 1, '2026-05-27', 14, '2026-03-31 20:05:37', 'generator'),
(2027, 1, '2026-05-27', 15, '2026-03-31 20:05:37', 'generator'),
(2028, 1, '2026-05-27', 16, '2026-03-31 20:05:37', 'generator'),
(2029, 1, '2026-05-28', 9, '2026-03-31 20:05:37', 'generator'),
(2030, 1, '2026-05-28', 10, '2026-03-31 20:05:37', 'generator'),
(2031, 1, '2026-05-28', 12, '2026-03-31 20:05:37', 'generator'),
(2032, 1, '2026-05-28', 13, '2026-03-31 20:05:37', 'generator'),
(2033, 1, '2026-05-28', 15, '2026-03-31 20:05:37', 'generator'),
(2034, 1, '2026-05-28', 16, '2026-03-31 20:05:37', 'generator'),
(2035, 1, '2026-05-29', 9, '2026-03-31 20:05:37', 'generator'),
(2036, 1, '2026-05-29', 10, '2026-03-31 20:05:37', 'generator'),
(2037, 1, '2026-05-29', 13, '2026-03-31 20:05:37', 'generator'),
(2038, 1, '2026-05-29', 14, '2026-03-31 20:05:37', 'generator'),
(2039, 1, '2026-05-29', 15, '2026-03-31 20:05:37', 'generator'),
(2040, 1, '2026-05-29', 16, '2026-03-31 20:05:37', 'generator'),
(2041, 1, '2026-05-30', 10, '2026-03-31 20:05:37', 'generator'),
(2042, 1, '2026-05-30', 11, '2026-03-31 20:05:37', 'generator'),
(2043, 1, '2026-04-02', 11, '2026-03-31 20:06:07', 'admin'),
(2044, 1, '2026-04-07', 14, '2026-03-31 20:06:35', 'admin'),
(2045, 1, '2026-04-09', 11, '2026-03-31 20:06:45', 'admin'),
(2046, 1, '2026-04-09', 13, '2026-03-31 20:06:47', 'admin'),
(2047, 1, '2026-04-09', 12, '2026-03-31 20:06:52', 'admin'),
(2048, 1, '2026-04-10', 11, '2026-03-31 20:06:55', 'admin'),
(2050, 1, '2026-04-14', 11, '2026-03-31 20:07:10', 'admin'),
(2051, 1, '2026-04-14', 13, '2026-03-31 20:07:12', 'admin'),
(2052, 1, '2026-04-15', 14, '2026-03-31 20:07:22', 'admin'),
(2053, 1, '2026-04-16', 9, '2026-03-31 20:07:30', 'admin'),
(2054, 1, '2026-04-16', 11, '2026-03-31 20:07:31', 'admin'),
(2055, 1, '2026-04-17', 11, '2026-03-31 20:07:39', 'admin'),
(2056, 1, '2026-04-17', 14, '2026-03-31 20:07:39', 'admin'),
(2057, 1, '2026-04-21', 11, '2026-03-31 20:07:55', 'admin'),
(2058, 1, '2026-04-23', 11, '2026-03-31 20:08:06', 'admin'),
(2059, 1, '2026-04-23', 12, '2026-03-31 20:08:12', 'admin'),
(2060, 1, '2026-04-23', 8, '2026-03-31 20:08:13', 'admin'),
(2061, 1, '2026-04-23', 13, '2026-03-31 20:08:15', 'admin'),
(2065, 1, '2026-04-24', 11, '2026-03-31 20:08:51', 'admin'),
(2066, 1, '2026-04-27', 14, '2026-03-31 20:10:28', 'admin'),
(2067, 1, '2026-04-28', 9, '2026-03-31 20:10:39', 'admin'),
(2068, 1, '2026-04-28', 11, '2026-03-31 20:10:42', 'admin'),
(2069, 1, '2026-04-28', 12, '2026-03-31 20:10:43', 'admin'),
(2070, 1, '2026-04-29', 14, '2026-03-31 20:10:57', 'admin'),
(2071, 1, '2026-04-30', 11, '2026-03-31 20:11:00', 'admin');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `services`
--

CREATE TABLE `services` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `duration_slots` int(11) DEFAULT 1,
  `price` decimal(10,2) NOT NULL,
  `description` text DEFAULT NULL,
  `active` tinyint(1) DEFAULT 1,
  `sort_order` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `services`
--

INSERT INTO `services` (`id`, `name`, `duration_slots`, `price`, `description`, `active`, `sort_order`, `created_at`) VALUES
(1, 'Lebenslauf', 1, 30.00, NULL, 1, 1, '2025-12-26 18:51:23'),
(2, 'Bewerbungsschreiben', 1, 30.00, NULL, 1, 2, '2025-12-26 18:51:23'),
(3, 'Etwas anderes', 1, 30.00, NULL, 1, 3, '2025-12-26 18:51:23');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `display_name` varchar(100) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `active` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `users`
--

INSERT INTO `users` (`id`, `username`, `display_name`, `email`, `phone`, `created_at`, `active`) VALUES
(1, 'felix', 'Felix Weissheimer', 'felix@bewerbungenundmehr.ch', '076 575 60 52', '2025-12-26 18:51:23', 1),
(2, 'mitmieterin', 'Mitmieterin', NULL, NULL, '2025-12-26 18:51:23', 1);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `v_available_slots`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `v_available_slots` (
`event_date` date
,`start_slot` tinyint(4)
,`end_slot` int(5)
,`time_display` varchar(13)
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `v_booking_details`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `v_booking_details` (
`event_id` int(11)
,`event_date` date
,`start_slot` tinyint(4)
,`end_slot` tinyint(4)
,`time_display` varchar(13)
,`customer_number` varchar(20)
,`customer_name` varchar(201)
,`customer_email` varchar(255)
,`customer_phone` varchar(30)
,`service_name` varchar(100)
,`price_at_booking` decimal(10,2)
,`booking_notes` text
,`status` enum('pending','confirmed','cancelled','completed')
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `v_daily_schedule`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `v_daily_schedule` (
`id` int(11)
,`user_id` int(11)
,`user_name` varchar(100)
,`event_date` date
,`start_slot` tinyint(4)
,`end_slot` tinyint(4)
,`time_display` varchar(13)
,`event_type_id` int(11)
,`event_type` varchar(100)
,`color` varchar(7)
,`is_customer_bookable` tinyint(1)
,`blocks_availability` tinyint(1)
,`customer_id` int(11)
,`customer_number` varchar(20)
,`customer_first_name` varchar(100)
,`customer_last_name` varchar(100)
,`customer_name` varchar(201)
,`customer_email` varchar(255)
,`customer_phone` varchar(30)
,`title` varchar(255)
,`notes` text
,`status` enum('pending','confirmed','cancelled','completed')
,`created_at` timestamp
,`updated_at` timestamp
);

--
-- Indizes der exportierten Tabellen
--

--
-- Indizes für die Tabelle `availability_settings`
--
ALTER TABLE `availability_settings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_user_day` (`user_id`,`day_of_week`);

--
-- Indizes für die Tabelle `blocked_dates`
--
ALTER TABLE `blocked_dates`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `idx_blocked_date` (`blocked_date`);

--
-- Indizes für die Tabelle `bookings`
--
ALTER TABLE `bookings`
  ADD PRIMARY KEY (`id`),
  ADD KEY `event_id` (`event_id`),
  ADD KEY `service_id` (`service_id`);

--
-- Indizes für die Tabelle `customers`
--
ALTER TABLE `customers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `customer_number` (`customer_number`),
  ADD KEY `idx_customer_number` (`customer_number`),
  ADD KEY `idx_customer_name` (`last_name`,`first_name`);

--
-- Indizes für die Tabelle `events`
--
ALTER TABLE `events`
  ADD PRIMARY KEY (`id`),
  ADD KEY `event_type_id` (`event_type_id`),
  ADD KEY `customer_id` (`customer_id`),
  ADD KEY `idx_availability` (`user_id`,`event_date`,`start_slot`,`end_slot`),
  ADD KEY `idx_event_date` (`event_date`),
  ADD KEY `idx_status` (`status`);

--
-- Indizes für die Tabelle `event_types`
--
ALTER TABLE `event_types`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indizes für die Tabelle `free_slots`
--
ALTER TABLE `free_slots`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_slot` (`user_id`,`slot_date`,`slot_hour`),
  ADD KEY `idx_slot_date` (`slot_date`),
  ADD KEY `idx_user_date` (`user_id`,`slot_date`);

--
-- Indizes für die Tabelle `services`
--
ALTER TABLE `services`
  ADD PRIMARY KEY (`id`);

--
-- Indizes für die Tabelle `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- AUTO_INCREMENT für exportierte Tabellen
--

--
-- AUTO_INCREMENT für Tabelle `availability_settings`
--
ALTER TABLE `availability_settings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT für Tabelle `blocked_dates`
--
ALTER TABLE `blocked_dates`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT für Tabelle `bookings`
--
ALTER TABLE `bookings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=38;

--
-- AUTO_INCREMENT für Tabelle `customers`
--
ALTER TABLE `customers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT für Tabelle `events`
--
ALTER TABLE `events`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT für Tabelle `event_types`
--
ALTER TABLE `event_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT für Tabelle `free_slots`
--
ALTER TABLE `free_slots`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2072;

--
-- AUTO_INCREMENT für Tabelle `services`
--
ALTER TABLE `services`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT für Tabelle `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

-- --------------------------------------------------------

--
-- Struktur des Views `v_available_slots`
--
DROP TABLE IF EXISTS `v_available_slots`;

CREATE ALGORITHM=UNDEFINED DEFINER=`luftgaessli`@`%` SQL SECURITY DEFINER VIEW `v_available_slots`  AS SELECT `fs`.`slot_date` AS `event_date`, `fs`.`slot_hour` AS `start_slot`, `fs`.`slot_hour`+ 1 AS `end_slot`, concat(lpad(`fs`.`slot_hour`,2,'0'),':00 - ',lpad(`fs`.`slot_hour` + 1,2,'0'),':00') AS `time_display` FROM `free_slots` AS `fs` WHERE `fs`.`user_id` = 1 AND !(`fs`.`slot_date` in (select `blocked_dates`.`blocked_date` from `blocked_dates` where `blocked_dates`.`user_id` = 1 OR `blocked_dates`.`user_id` is null)) AND !exists(select 1 from (`events` `e` join `event_types` `et` on(`e`.`event_type_id` = `et`.`id`)) where `e`.`user_id` = 1 AND `e`.`event_date` = `fs`.`slot_date` AND `et`.`blocks_availability` = 1 AND `e`.`status` <> 'cancelled' AND `fs`.`slot_hour` >= `e`.`start_slot` AND `fs`.`slot_hour` < `e`.`end_slot` limit 1) AND `fs`.`slot_date` >= curdate() ;

-- --------------------------------------------------------

--
-- Struktur des Views `v_booking_details`
--
DROP TABLE IF EXISTS `v_booking_details`;

CREATE ALGORITHM=UNDEFINED DEFINER=`luftgaessli`@`%` SQL SECURITY DEFINER VIEW `v_booking_details`  AS SELECT `e`.`id` AS `event_id`, `e`.`event_date` AS `event_date`, `e`.`start_slot` AS `start_slot`, `e`.`end_slot` AS `end_slot`, concat(lpad(`e`.`start_slot`,2,'0'),':00 - ',lpad(`e`.`end_slot`,2,'0'),':00') AS `time_display`, `c`.`customer_number` AS `customer_number`, concat(`c`.`first_name`,' ',`c`.`last_name`) AS `customer_name`, `c`.`email` AS `customer_email`, `c`.`phone` AS `customer_phone`, `s`.`name` AS `service_name`, `b`.`price_at_booking` AS `price_at_booking`, `b`.`notes` AS `booking_notes`, `e`.`status` AS `status`, `e`.`created_at` AS `created_at` FROM ((((`events` `e` join `event_types` `et` on(`e`.`event_type_id` = `et`.`id`)) join `customers` `c` on(`e`.`customer_id` = `c`.`id`)) join `bookings` `b` on(`e`.`id` = `b`.`event_id`)) join `services` `s` on(`b`.`service_id` = `s`.`id`)) WHERE `et`.`is_customer_bookable` = 1 ORDER BY `e`.`event_date` DESC, `e`.`start_slot` ASC ;

-- --------------------------------------------------------

--
-- Struktur des Views `v_daily_schedule`
--
DROP TABLE IF EXISTS `v_daily_schedule`;

CREATE ALGORITHM=UNDEFINED DEFINER=`luftgaessli`@`%` SQL SECURITY DEFINER VIEW `v_daily_schedule`  AS SELECT `e`.`id` AS `id`, `e`.`user_id` AS `user_id`, `u`.`display_name` AS `user_name`, `e`.`event_date` AS `event_date`, `e`.`start_slot` AS `start_slot`, `e`.`end_slot` AS `end_slot`, concat(lpad(`e`.`start_slot`,2,'0'),':00 - ',lpad(`e`.`end_slot`,2,'0'),':00') AS `time_display`, `et`.`id` AS `event_type_id`, `et`.`name` AS `event_type`, `et`.`color` AS `color`, `et`.`is_customer_bookable` AS `is_customer_bookable`, `et`.`blocks_availability` AS `blocks_availability`, `c`.`id` AS `customer_id`, `c`.`customer_number` AS `customer_number`, `c`.`first_name` AS `customer_first_name`, `c`.`last_name` AS `customer_last_name`, concat(`c`.`first_name`,' ',`c`.`last_name`) AS `customer_name`, `c`.`email` AS `customer_email`, `c`.`phone` AS `customer_phone`, `e`.`title` AS `title`, `e`.`notes` AS `notes`, `e`.`status` AS `status`, `e`.`created_at` AS `created_at`, `e`.`updated_at` AS `updated_at` FROM (((`events` `e` join `users` `u` on(`e`.`user_id` = `u`.`id`)) join `event_types` `et` on(`e`.`event_type_id` = `et`.`id`)) left join `customers` `c` on(`e`.`customer_id` = `c`.`id`)) ORDER BY `e`.`event_date` ASC, `e`.`start_slot` ASC ;

--
-- Constraints der exportierten Tabellen
--

--
-- Constraints der Tabelle `availability_settings`
--
ALTER TABLE `availability_settings`
  ADD CONSTRAINT `availability_settings_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `blocked_dates`
--
ALTER TABLE `blocked_dates`
  ADD CONSTRAINT `blocked_dates_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`service_id`) REFERENCES `services` (`id`);

--
-- Constraints der Tabelle `events`
--
ALTER TABLE `events`
  ADD CONSTRAINT `events_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `events_ibfk_2` FOREIGN KEY (`event_type_id`) REFERENCES `event_types` (`id`),
  ADD CONSTRAINT `events_ibfk_3` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL;

--
-- Constraints der Tabelle `event_types`
--
ALTER TABLE `event_types`
  ADD CONSTRAINT `event_types_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `free_slots`
--
ALTER TABLE `free_slots`
  ADD CONSTRAINT `free_slots_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
