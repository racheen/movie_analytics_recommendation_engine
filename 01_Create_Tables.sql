
-- ============================================================================
-- NETFLIX DATABASE SCHEMA
-- ============================================================================


-- Createing database if not exist
CREATE DATABASE netflix_analytics_v2;
GO
USE netflix_analytics_v2;
GO


-- Drop existing tables (in reverse order of dependencies)
DROP TABLE IF EXISTS title_sources;
DROP TABLE IF EXISTS sources;
DROP TABLE IF EXISTS watch_history;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS title_genres;
DROP TABLE IF EXISTS genres;
DROP TABLE IF EXISTS titles;
DROP TABLE IF EXISTS users;

-- Drop existing triggers
DROP TRIGGER IF EXISTS before_watch_history_insert;
DROP TRIGGER IF EXISTS after_watch_history_insert;
DROP TRIGGER IF EXISTS before_subscription_update;
DROP TRIGGER IF EXISTS after_subscription_insert;
DROP TRIGGER IF EXISTS validate_watch_percentage;

-- ============================================================================
-- 1. TABLE: users
-- ============================================================================
CREATE TABLE users (
    user_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    age INT,
    country VARCHAR(100),
    watch_time_hours DECIMAL(10,2) DEFAULT 0.00,
    favorite_genre VARCHAR(100),
    last_login DATE,
    created_at DATETIME2 DEFAULT SYSDATETIME() NOT NULL,
    updated_at DATETIME2 DEFAULT SYSDATETIME() NOT NULL
);

-- Indexes
CREATE INDEX idx_country ON users(country);
CREATE INDEX idx_last_login ON users(last_login);

-- Checks
ALTER TABLE users 
    ADD CONSTRAINT chk_users_age CHECK (age BETWEEN 13 AND 120);

-- ============================================================================
-- 2. TABLE: titles
-- ============================================================================
CREATE TABLE titles (
    title_id VARCHAR(50) PRIMARY KEY,                          
    title NVARCHAR(255) NOT NULL,                      
    type NVARCHAR(50),
    description NVARCHAR(MAX),
    release_year INT,
    age_certification NVARCHAR(10),
    runtime INT,
    production_countries NVARCHAR(255),
    seasons INT,
    imdb_id NVARCHAR(20),
    imdb_score FLOAT,
    imdb_votes INT,
    tmdb_popularity FLOAT,
    tmdb_score FLOAT
);

CREATE INDEX idx_release_year ON titles(release_year);
CREATE INDEX idx_avg_rating ON titles(imdb_score);

-- ============================================================================
-- 3. TABLE: genres
-- ============================================================================
CREATE TABLE genres (
    genre_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL UNIQUE
);

CREATE INDEX idx_genre_name ON genres(name);

-- ============================================================================
-- 4. TABLE: title_genres (Many-to-Many relationship)
-- ============================================================================
CREATE TABLE title_genres (
    title_id VARCHAR(50) NOT NULL,
    genre_id INT NOT NULL,
    PRIMARY KEY (title_id, genre_id),
    FOREIGN KEY (title_id) REFERENCES titles(title_id) ON DELETE CASCADE,
    FOREIGN KEY (genre_id) REFERENCES genres(genre_id) ON DELETE CASCADE
);

-- ============================================================================
-- 5. TABLE: sources
-- ============================================================================
CREATE TABLE sources (
    source_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL UNIQUE,
    region NVARCHAR(10)
);

-- ============================================================================
-- 6. TABLE: title_sources (Many-to-Many relationship)
-- ============================================================================

CREATE TABLE title_sources (
    title_id VARCHAR(50) NOT NULL,
    source_id INT NOT NULL,
    link VARCHAR(255),
    PRIMARY KEY (title_id, source_id),
    FOREIGN KEY (title_id) REFERENCES titles(title_id) ON DELETE CASCADE,
    FOREIGN KEY (source_id) REFERENCES sources(source_id) ON DELETE CASCADE
);


-- ============================================================================
-- 7. TABLE: subscriptions
-- ============================================================================
CREATE TABLE subscriptions (
    subscription_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    subscription_type NVARCHAR(50) NOT NULL,
    monthly_fee DECIMAL(10,2) NOT NULL,
    subscription_status NVARCHAR(20) NOT NULL DEFAULT 'active',
    subscription_start_date DATE NOT NULL,
    subscription_end_date DATE NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(subscription_status);

-- Checks
ALTER TABLE subscriptions
ADD CONSTRAINT chk_subscription_type
CHECK (subscription_type IN ('Basic','Standard','Premium'));

ALTER TABLE subscriptions
ADD CONSTRAINT chk_subscription_status
CHECK (subscription_status IN ('active','inactive','cancelled','suspended'));

ALTER TABLE subscriptions
ADD CONSTRAINT chk_subscription_end
CHECK (subscription_end_date IS NULL OR subscription_end_date >= subscription_start_date);


-- ============================================================================
-- 8. TABLE: watch_history
-- ============================================================================
CREATE TABLE watch_history (
    watch_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    title_id VARCHAR(50) NOT NULL,
    watch_percentage DECIMAL(5,2) CHECK (watch_percentage >= 0 AND watch_percentage <= 1),
    completed TINYINT DEFAULT 0,
    created_at DATETIME2 DEFAULT SYSDATETIME(),
    updated_at DATETIME2 DEFAULT SYSDATETIME(),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (title_id) REFERENCES titles(title_id) ON DELETE CASCADE
);

CREATE INDEX idx_wh_user ON watch_history(user_id);
CREATE INDEX idx_wh_title ON watch_history(title_id);
CREATE INDEX idx_wh_completed ON watch_history(completed);


-- ============================================================================
-- NETFLIX DATABASE SCHEMA END
-- ============================================================================