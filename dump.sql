-- Schema: ChatGPT Telemetry
-- Minimal indexes during load: only PKs and FKs. Extra indexes are created later.
-- Engine and charset tuned for bulk load.
CREATE DATABASE IF NOT EXISTS chatgpt_telemetry CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE chatgpt_telemetry;

SET FOREIGN_KEY_CHECKS=0;

DROP TABLE IF EXISTS message;
DROP TABLE IF EXISTS conversation;
DROP TABLE IF EXISTS user;
DROP TABLE IF EXISTS model;
DROP TABLE IF EXISTS locale;

CREATE TABLE locale (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(64) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE model (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(64) NOT NULL UNIQUE,
  provider VARCHAR(32) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE user (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(191) NOT NULL UNIQUE,
  country VARCHAR(2) NOT NULL,
  locale_id SMALLINT UNSIGNED,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (locale_id) REFERENCES locale(id)
) ENGINE=InnoDB;

CREATE TABLE conversation (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  title VARCHAR(160) NULL,
  model_id SMALLINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (user_id) REFERENCES user(id),
  FOREIGN KEY (model_id) REFERENCES model(id)
) ENGINE=InnoDB;

CREATE TABLE message (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  conversation_id BIGINT UNSIGNED NOT NULL,
  role ENUM('user','assistant') NOT NULL,
  author_user_id INT UNSIGNED NULL,
  content TEXT NOT NULL,
  token_in INT UNSIGNED NOT NULL,
  token_out INT UNSIGNED NOT NULL,
  latency_ms INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (conversation_id) REFERENCES conversation(id),
  FOREIGN KEY (author_user_id) REFERENCES user(id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS=1;
