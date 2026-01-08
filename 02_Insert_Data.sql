USE netflix_analytics_v2;
GO

-- 1. Users
BULK INSERT users
FROM 'C:\Path\to\combined_dataset\users.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    TABLOCK,
    CODEPAGE = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO

-- 2. Titles
BULK INSERT titles
FROM 'C:\Path\to\combined_dataset\titles.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    TABLOCK,
    CODEPAGE = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO

-- 3. Genres
BULK INSERT genres
FROM 'C:\Path\to\combined_dataset\genres.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    TABLOCK,
    CODEPAGE = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO

-- 4. Title_Genres
BULK INSERT title_genres
FROM 'C:\Path\to\combined_dataset\title_genres.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    TABLOCK,
    CODEPAGE = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO

-- 5. Watch_History
BULK INSERT watch_history
FROM 'C:\Path\to\combined_dataset\watch_history.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    TABLOCK,
    CODEPAGE = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO

-- 6. Subscriptions
BULK INSERT subscriptions
FROM 'C:\Path\to\combined_dataset\subscriptions.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    TABLOCK,
    CODEPAGE = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO

-- 7. Sources
BULK INSERT sources
FROM 'C:\Path\to\combined_dataset\sources.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    TABLOCK,
    CODEPAGE = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO

-- 8. Title_Sources
BULK INSERT title_sources
FROM 'C:\Path\to\combined_dataset\title_sources.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    TABLOCK,
    CODEPAGE = '65001',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO
