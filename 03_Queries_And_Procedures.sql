
-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger 1: Auto-update completed flag based on watch_percentage
CREATE OR ALTER TRIGGER trg_watch_history_completed
ON watch_history
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE wh
    SET completed = CASE WHEN i.watch_percentage >= 90 THEN 1 ELSE 0 END
    FROM watch_history wh
    INNER JOIN inserted i ON wh.watch_id = i.watch_id;
END;


-- Trigger 2: Update user's total watch time when new watch history is added
CREATE OR ALTER TRIGGER trg_watch_history_update_user_time
ON watch_history
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE u
    SET u.watch_time_hours = u.watch_time_hours + ((t.runtime * i.watch_percentage) / 60),
        u.updated_at = SYSDATETIME()
    FROM users u
    INNER JOIN inserted i ON u.user_id = i.user_id
    INNER JOIN titles t ON i.title_id = t.title_id
    WHERE t.runtime IS NOT NULL;
END;


-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View 1: User Activity Summary
CREATE OR ALTER VIEW vw_user_activity_summary AS
SELECT 
    u.user_id,
    u.name,
    u.country,
    u.subscription_type,
    u.watch_time_hours,
    COUNT(DISTINCT wh.title_id) AS titles_watched,
    COUNT(wh.watch_id) AS total_watches,
    SUM(CAST(wh.completed AS INT)) AS completed_watches,
    ROUND(AVG(CAST(wh.watch_percentage AS FLOAT)) * 100, 2) AS avg_watch_percentage
FROM users u
LEFT JOIN watch_history wh ON u.user_id = wh.user_id
GROUP BY u.user_id, u.name, u.country, u.subscription_type, u.watch_time_hours;


-- View 2: Genre Performance
CREATE OR ALTER VIEW vw_genre_performance AS
SELECT 
    g.genre_id,
    g.name AS genre_name,
    COUNT(DISTINCT tg.title_id) AS title_count,
    COUNT(DISTINCT wh.user_id) AS unique_viewers,
    COUNT(wh.watch_id) AS total_watches,
    ROUND(AVG(wh.watch_percentage) * 100, 2) AS avg_watch_percentage,
    SUM(wh.completed) AS completed_watches
FROM genres g
LEFT JOIN title_genres tg ON g.genre_id = tg.genre_id
LEFT JOIN watch_history wh ON tg.title_id = wh.title_id
GROUP BY g.genre_id, g.name;

-- View 3: Active Subscriptions
CREATE OR ALTER VIEW vw_active_subscriptions AS
SELECT
    s.subscription_id,
    s.user_id,
    u.name AS user_name,
    s.subscription_type,
    s.monthly_fee,
    s.subscription_start_date,
    s.subscription_end_date,
    s.subscription_status,
    DATEDIFF(DAY, s.subscription_start_date, CAST(GETDATE() AS DATE)) AS days_subscribed
FROM subscriptions s
JOIN users u ON s.user_id = u.user_id
WHERE s.subscription_status = 'active'
  AND (s.subscription_end_date IS NULL OR s.subscription_end_date >= '2025-01-01');

SELECT COUNT(*) AS count FROM vw_active_subscriptions

-- View 4: Revenue Analysis
CREATE OR ALTER VIEW vw_revenue_analysis AS
SELECT
    s.subscription_type,
    COUNT(DISTINCT s.user_id) AS subscriber_count,
    s.monthly_fee,
    COUNT(DISTINCT s.user_id) * s.monthly_fee AS monthly_revenue,
    ROUND(AVG(DATEDIFF(DAY, s.subscription_start_date, ISNULL(s.subscription_end_date, CAST(GETDATE() AS DATE)))), 2) AS avg_subscription_days
FROM subscriptions s
WHERE s.subscription_status = 'active'
GROUP BY s.subscription_type, s.monthly_fee;

-- View 5: User Engagement by Country
CREATE OR ALTER VIEW vw_country_engagement AS
SELECT
    u.country,
    COUNT(DISTINCT u.user_id) AS user_count,
    ROUND(AVG(u.watch_time_hours), 2) AS avg_watch_hours,
    COUNT(DISTINCT wh.title_id) AS unique_titles_watched,
    COUNT(wh.watch_id) AS total_watches,
    ROUND(AVG(wh.watch_percentage) * 100, 2) AS avg_completion_rate
FROM users u
INNER JOIN watch_history wh 
    ON u.user_id = wh.user_id
WHERE u.country IS NOT NULL
  AND wh.watch_percentage IS NOT NULL
GROUP BY u.country;

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

-- Procedure 1: Get User Recommendations
CREATE OR ALTER PROCEDURE sp_get_user_recommendations
    @p_user_id VARCHAR(50),
    @p_limit INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP(@p_limit)
        t.title_id,
        t.title,
        t.release_year,
        t.imdb_score AS avg_rating,
        STRING_AGG(g.name, ', ') AS genres
    FROM titles t
    JOIN title_genres tg ON t.title_id = tg.title_id
    JOIN genres g ON tg.genre_id = g.genre_id
    WHERE tg.genre_id IN (
        SELECT DISTINCT tg2.genre_id
        FROM watch_history wh
        JOIN title_genres tg2 ON wh.title_id = tg2.title_id
        WHERE wh.user_id = @p_user_id
    )
    AND t.title_id NOT IN (
        SELECT title_id
        FROM watch_history
        WHERE user_id = @p_user_id
    )
    GROUP BY t.title_id, t.title, t.release_year, t.imdb_score
    ORDER BY t.imdb_score DESC; 
END;

-- Procedure 2: Generates genre-level analytics,
CREATE OR ALTER PROCEDURE sp_get_genre_trends
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        g.genre_id,
        g.name AS genre_name,
        COUNT(DISTINCT tg.title_id) AS total_titles,
        COUNT(DISTINCT wh.user_id) AS unique_viewers,
        COUNT(wh.watch_id) AS total_watch_events,
        ROUND(AVG(CAST(wh.watch_percentage AS FLOAT)) * 100, 2) AS avg_watch_percentage,
        SUM(wh.completed) AS completed_watches,
        COUNT(wh.watch_id) * 1.0 / NULLIF(COUNT(DISTINCT tg.title_id), 0) AS engagement_score
    FROM genres g
    LEFT JOIN title_genres tg ON g.genre_id = tg.genre_id
    LEFT JOIN watch_history wh ON tg.title_id = wh.title_id
    GROUP BY g.genre_id, g.name
    ORDER BY total_watch_events DESC;
END;

EXEC sp_get_genre_trends


-- ============================================================================
-- FUNCTIONS
-- ============================================================================
-- Function 1: Calculate User Lifetime Value (LTV)
CREATE OR ALTER FUNCTION fn_calculate_user_ltv(@p_user_id VARCHAR(50))
RETURNS DECIMAL(10, 2)
AS
BEGIN
    DECLARE @ltv DECIMAL(10, 2);

    SELECT @ltv = SUM(s.monthly_fee * DATEDIFF(DAY, s.subscription_start_date, ISNULL(s.subscription_end_date, CAST(GETDATE() AS DATE))) / 30.0)
    FROM subscriptions s
    WHERE s.user_id = @p_user_id;

    RETURN ISNULL(@ltv, 0.00);
END;


-- Function 2: Get User Subscription Duration in Days
CREATE OR ALTER FUNCTION fn_subscription_duration(@p_user_id VARCHAR(50))
RETURNS INT
AS
BEGIN
    DECLARE @duration INT;

    SELECT @duration = SUM(DATEDIFF(DAY, s.subscription_start_date, ISNULL(s.subscription_end_date, CAST(GETDATE() AS DATE))))
    FROM subscriptions s
    WHERE s.user_id = @p_user_id;

    RETURN ISNULL(@duration, 0);
END;


-- ============================================================================
-- QUERIES FOR ANALYSIS
-- ============================================================================

-- User Engagement & Behavior
-- Query 1: Average watch percentage per user
SELECT 
    u.user_id,
    u.name,
    ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_percentage,
    COUNT(wh.watch_id) AS total_watches,
    SUM(wh.completed) AS completed_watches
FROM users u
LEFT JOIN watch_history wh ON u.user_id = wh.user_id
GROUP BY u.user_id, u.name
ORDER BY avg_watch_percentage DESC;
-- Insight: Identify highly engaged users vs low-engagement users.

SELECT * FROM watch_history ORDER BY watch_percentage DESC;


-- Query 2: Most Active Countries
SELECT 
    u.country,
    COUNT(DISTINCT u.user_id) AS user_count,
    ROUND(AVG(u.watch_time_hours), 2) AS avg_watch_hours,
    COUNT(wh.watch_id) AS total_watches
FROM users u
LEFT JOIN watch_history wh ON u.user_id = wh.user_id
GROUP BY u.country
ORDER BY total_watches DESC;
-- Insight: Shows which regions have the highest platform usage.

-- Query 3: Top users by completed titles
SELECT TOP 10
    u.user_id,
    u.name,
    SUM(wh.completed) AS completed_watches
FROM users u
JOIN watch_history wh ON u.user_id = wh.user_id
GROUP BY u.user_id, u.name
ORDER BY completed_watches DESC;
-- Insight: Identify power users or potential target for promotions.

-- Query 3: Total & Average Watch Consumption by Age Group
WITH age_groups AS (
    SELECT
        u.user_id,
        CASE
            WHEN u.age < 18 THEN 'Under 18'
            WHEN u.age BETWEEN 18 AND 24 THEN '18-24'
            WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
            WHEN u.age BETWEEN 35 AND 44 THEN '35-44'
            WHEN u.age BETWEEN 45 AND 54 THEN '45-54'
            WHEN u.age BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65+'
        END AS age_group
    FROM users u
)

SELECT
    ag.age_group,
    COUNT(wh.watch_id) AS total_watch_events,

    -- Sum of fractional watch, meaning: how many full content equivalents
    ROUND(SUM(CAST(wh.watch_percentage AS FLOAT)), 2) AS total_full_watch_equivalent,

    -- Average watch percentage as a real percent
    ROUND(AVG(CAST(wh.watch_percentage AS FLOAT)) * 100, 2) AS avg_watch_percentage

FROM watch_history wh
JOIN age_groups ag ON wh.user_id = ag.user_id
GROUP BY ag.age_group
ORDER BY total_full_watch_equivalent DESC;

-- Query 4: Watch Behavior by Subscription Type & Age Group
WITH age_groups AS (
    SELECT
        u.user_id,
        CASE
            WHEN u.age < 18 THEN 'Under 18'
            WHEN u.age BETWEEN 18 AND 24 THEN '18-24'
            WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
            WHEN u.age BETWEEN 35 AND 44 THEN '35-44'
            WHEN u.age BETWEEN 45 AND 54 THEN '45-54'
            WHEN u.age BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65+'
        END AS age_group,
        s.subscription_type
    FROM users u
    JOIN subscriptions s ON u.user_id = s.user_id
)

SELECT
    ag.age_group,
    ag.subscription_type,
    
    COUNT(DISTINCT ag.user_id) AS users_in_segment,
    COUNT(wh.watch_id) AS total_watch_events,

    ROUND(AVG(CAST(wh.watch_percentage AS FLOAT)) * 100, 2) AS avg_watch_percentage,
    ROUND(SUM(CAST(wh.watch_percentage AS FLOAT)) * 100, 2) AS total_watch_percentage

FROM age_groups ag
LEFT JOIN watch_history wh ON ag.user_id = wh.user_id

GROUP BY ag.age_group, ag.subscription_type
ORDER BY ag.age_group, ag.subscription_type;


-- Content & Genre Analytics
-- Query 1: Top watched generes
SELECT 
    g.name AS genre,
    COUNT(wh.watch_id) AS total_watches,
    ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_completion
FROM genres g
JOIN title_genres tg ON g.genre_id = tg.genre_id
JOIN watch_history wh ON tg.title_id = wh.title_id
GROUP BY g.name
ORDER BY total_watches DESC;
-- Insight: Which genres are most popular and have high engagement.

-- Query 2: Titles with highest completion rates
SELECT TOP 20
    t.title,
    ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_percentage,
    SUM(wh.completed) AS total_completed
FROM titles t
JOIN watch_history wh ON t.title_id = wh.title_id
GROUP BY t.title
ORDER BY avg_watch_percentage DESC, total_completed DESC;
-- Insight: Identify content that users actually finish watching.

-- Query 3: Titles with highest engagement score
SELECT 
    t.title,
    COUNT(wh.watch_id) * 1.0 / NULLIF(COUNT(DISTINCT wh.user_id), 0) AS engagement_score,
    COUNT(wh.watch_id) AS total_watches
FROM titles t
JOIN watch_history wh ON t.title_id = wh.title_id
GROUP BY t.title
ORDER BY engagement_score DESC;
-- Insight: Highlights binge-worthy or addictive content.

-- Subscription & Revenue Analytics
-- Query 1: Active vs Inactive subscriptions
SELECT 
    subscription_status,
    COUNT(subscription_id) AS total_subscriptions,
    ROUND(AVG(monthly_fee), 2) AS avg_monthly_fee
FROM subscriptions
GROUP BY subscription_status;
-- Insight: Understand churn and active user base.

-- Query 2: Revenue per subscription type
SELECT 
    subscription_type,
    COUNT(subscription_id) AS subscriber_count,
    SUM(monthly_fee) AS total_monthly_revenue,
    ROUND(AVG(monthly_fee), 2) AS avg_fee
FROM subscriptions
WHERE subscription_status = 'active'
GROUP BY subscription_type;
-- Insight: See which plan brings the most revenue.

-- Query 3: Lifetime value by user
SELECT 
    u.user_id,
    u.name,
    dbo.fn_calculate_user_ltv(u.user_id) AS lifetime_value
FROM users u
ORDER BY lifetime_value DESC;
Insight: Identify high-value users for retention strategies.

-- Cross-Analysis: Content vs User Engagement
-- Query 1: Active vs Inactive subscriptions
SELECT 
    u.country,
    g.name AS genre,
    ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_percentage,
    COUNT(wh.watch_id) AS total_watches
FROM users u
JOIN watch_history wh ON u.user_id = wh.user_id
JOIN title_genres tg ON wh.title_id = tg.title_id
JOIN genres g ON tg.genre_id = g.genre_id
GROUP BY u.country, g.name
ORDER BY u.country, avg_watch_percentage DESC;
-- Insight: Helps tailor content by region.

-- Query 2: Users with high watch percentage but low subscription revenue
SELECT 
    u.user_id,
    u.name,
    ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_percentage,
    dbo.fn_calculate_user_ltv(u.user_id) AS lifetime_value
FROM users u
JOIN watch_history wh ON u.user_id = wh.user_id
GROUP BY u.user_id, u.name
HAVING AVG(wh.watch_percentage) > 0.8 AND dbo.fn_calculate_user_ltv(u.user_id) < 50
ORDER BY avg_watch_percentage DESC;
-- Insight: These are highly engaged but low-paying users—good for upsell campaigns.

-- ============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================

CREATE INDEX idx_watch_user_date_title ON watch_history(user_id, title_id);
CREATE INDEX idx_subscription_user_status ON subscriptions(user_id, subscription_status);
CREATE INDEX idx_user_country_subscription ON users(country, subscription_type);

-- ============================================================================
-- END
-- ============================================================================
