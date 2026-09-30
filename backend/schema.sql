-- =====================================================================
-- RituMita Boutique Database Schema (MySQL / MariaDB)
-- Hostinger Subdomain: api.ritumitasrentaljewels.com
-- Database Name: u519811289_boutique
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Users Table (Authentication, Staff, Cashier, Admin)
CREATE TABLE IF NOT EXISTS `users` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `uid` VARCHAR(64) NOT NULL UNIQUE,
  `name` VARCHAR(150) NOT NULL,
  `email` VARCHAR(150) NOT NULL UNIQUE,
  `phone` VARCHAR(30) DEFAULT NULL,
  `role` VARCHAR(50) NOT NULL DEFAULT 'Staff',
  `password_hash` VARCHAR(255) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `permissions` JSON DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Default Admin User (admin@ritumita.com)
INSERT INTO `users` (`uid`, `name`, `email`, `phone`, `role`, `password_hash`, `is_active`)
VALUES (
  'admin_root',
  'Super Admin',
  'admin@ritumita.com',
  '9876543210',
  'Admin',
  '$2y$10$wE9mHlWkn40eRzP9tMzgfub/q7Q9WqQvP0v0sPz9w5kH8x7d6f5ye',
  1
) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- 2. Master Dropdowns (Categories, Materials, Units, Weight Units, Item Names)
CREATE TABLE IF NOT EXISTS `master_items` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `type` VARCHAR(50) NOT NULL, -- 'category', 'material', 'unit', 'weight_unit', 'item_name'
  `name` VARCHAR(150) NOT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `idx_type_name` (`type`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed Standard Master Data
INSERT IGNORE INTO `master_items` (`type`, `name`) VALUES
('category', 'MALAS'),
('category', 'GEMS'),
('category', 'BRACELET'),
('category', 'RINGS'),
('category', 'PENDANTS'),
('material', 'Brass'),
('material', 'Silver'),
('material', 'Gold'),
('material', 'Wood'),
('material', 'Stone'),
('unit', 'piece'),
('unit', 'set'),
('unit', 'gram'),
('weight_unit', 'g'),
('weight_unit', 'mg'),
('weight_unit', 'ct');

-- 3. Products Table (Inventory, Pricing, Weight, Stock)
CREATE TABLE IF NOT EXISTS `products` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `tag_id` VARCHAR(100) NOT NULL UNIQUE,
  `name` VARCHAR(255) NOT NULL,
  `category` VARCHAR(100) DEFAULT '',
  `deity` VARCHAR(100) DEFAULT '',
  `material` VARCHAR(100) DEFAULT '',
  `size` VARCHAR(50) DEFAULT '',
  `status` VARCHAR(50) DEFAULT 'In Stock',
  `vendor` VARCHAR(150) DEFAULT '',
  `notes` TEXT DEFAULT NULL,
  `pricing_type` VARCHAR(50) DEFAULT 'Quantity-Based',
  `gross_weight` DECIMAL(12, 3) DEFAULT 0.000,
  `net_weight` DECIMAL(12, 3) DEFAULT 0.000,
  `weight_unit` VARCHAR(20) DEFAULT 'g',
  `rate_per_gram` DECIMAL(12, 2) DEFAULT 0.00,
  `making_charges` DECIMAL(12, 2) DEFAULT 0.00,
  `quantity` INT DEFAULT 0,
  `issue_quantity` INT DEFAULT 0,
  `reserved_quantity` INT DEFAULT 0,
  `unit` VARCHAR(30) DEFAULT 'piece',
  `mrp` DECIMAL(12, 2) DEFAULT 0.00,
  `selling_price` DECIMAL(12, 2) DEFAULT 0.00,
  `discount_value` DECIMAL(12, 2) DEFAULT 0.00,
  `discount_type` VARCHAR(10) DEFAULT '%',
  `final_price` DECIMAL(12, 2) DEFAULT 0.00,
  `gst_rate` DECIMAL(6, 2) DEFAULT 0.00,
  `is_festival_stock` TINYINT(1) DEFAULT 0,
  `is_reserved` TINYINT(1) DEFAULT 0,
  `reserved_for` VARCHAR(150) DEFAULT '',
  `image_url` TEXT DEFAULT NULL,
  `images` JSON DEFAULT NULL,
  `raw_json` JSON DEFAULT NULL,
  `added_date` DATETIME DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_cat_status` (`category`, `status`),
  INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Bills Table (POS Invoices, Customers, Payments, Totals)
CREATE TABLE IF NOT EXISTS `bills` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `doc_id` VARCHAR(64) NOT NULL UNIQUE,
  `bill_no` VARCHAR(100) NOT NULL UNIQUE,
  `bill_type` VARCHAR(50) DEFAULT 'Retail',
  `narration` TEXT DEFAULT NULL,
  `bill_date` DATETIME NOT NULL,
  `customer_name` VARCHAR(150) DEFAULT '',
  `customer_mobile` VARCHAR(30) DEFAULT '',
  `customer_address` TEXT DEFAULT NULL,
  `custom_customer_details` JSON DEFAULT NULL,
  `items` JSON NOT NULL,
  `subtotal` DECIMAL(12, 2) DEFAULT 0.00,
  `extra_discount_type` VARCHAR(10) DEFAULT '%',
  `extra_discount_value` DECIMAL(12, 2) DEFAULT 0.00,
  `extra_discount_amount` DECIMAL(12, 2) DEFAULT 0.00,
  `gst_percent` DECIMAL(6, 2) DEFAULT 0.00,
  `tax_amount` DECIMAL(12, 2) DEFAULT 0.00,
  `adjustment_amount` DECIMAL(12, 2) DEFAULT 0.00,
  `total_payable` DECIMAL(12, 2) DEFAULT 0.00,
  `payment_mode` VARCHAR(50) DEFAULT 'Cash',
  `payments` JSON DEFAULT NULL,
  `payment_history` JSON DEFAULT NULL,
  `amount_received` DECIMAL(12, 2) DEFAULT 0.00,
  `pending_balance` DECIMAL(12, 2) DEFAULT 0.00,
  `is_fully_paid` TINYINT(1) DEFAULT 0,
  `payment_status` VARCHAR(50) DEFAULT 'Paid',
  `balance_returned` DECIMAL(12, 2) DEFAULT 0.00,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_bill_date` (`bill_date`),
  INDEX `idx_cust_mobile` (`customer_mobile`),
  INDEX `idx_payment_status` (`payment_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Vendor Issues Table (Damaged items sent to vendor / repair)
CREATE TABLE IF NOT EXISTS `vendor_issues` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `doc_id` VARCHAR(64) NOT NULL UNIQUE,
  `vendor_name` VARCHAR(150) NOT NULL,
  `issue_date` DATETIME NOT NULL,
  `status` VARCHAR(50) DEFAULT 'Pending',
  `items` JSON NOT NULL,
  `total_amount` DECIMAL(12, 2) DEFAULT 0.00,
  `notes` TEXT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_vendor_status` (`vendor_name`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Settings Table (Rates, Designer settings, live rates, etc.)
CREATE TABLE IF NOT EXISTS `settings` (
  `setting_key` VARCHAR(100) PRIMARY KEY,
  `setting_value` JSON NOT NULL,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
