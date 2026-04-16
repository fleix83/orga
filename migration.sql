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
