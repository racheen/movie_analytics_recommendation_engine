# Movie Analytics & Recommendation Engine

A comprehensive SQL Server-based analytics and recommendation system for streaming content platforms. This project provides deep insights into user behavior, content performance, subscription metrics, and personalized recommendations.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Database Setup](#database-setup)
- [Dashboard Usage](#dashboard-usage)
- [Project Structure](#project-structure)
- [Key Queries & Analytics](#key-queries--analytics)
- [Contributing](#contributing)

## Overview

This project combines SQL Server database management with a Streamlit-based interactive dashboard to analyze streaming platform data. It enables stakeholders to:

- Track user engagement and viewing patterns
- Analyze content performance across genres and regions
- Monitor subscription and revenue metrics
- Generate personalized content recommendations
- Identify trends and business opportunities

## Features

### Analytics Dashboards
- **Overview**: High-level platform metrics and KPIs
- **User Activity**: User engagement, watch time, and behavior patterns
- **Genre Performance**: Content popularity and completion rates by genre
- **Subscription & Revenue**: Revenue analysis and subscription trends
- **Cross Analysis**: Multi-dimensional analysis combining user, content, and subscription data
- **Recommender Demo**: Personalized content recommendations for users

### Database Features
- **Relational Schema**: Optimized tables for users, titles, genres, subscriptions, and watch history
- **Stored Procedures**: Pre-built analytics queries for common use cases
- **Views**: Materialized views for frequently accessed data
- **Triggers**: Automated data updates (watch completion tracking, user metrics)
- **Functions**: Custom calculations (LTV, subscription duration)
- **Indexes**: Performance-optimized queries

## Architecture
```bash
Movie Analytics & Recommendation Engine
├── SQL Server Database (netflix_analytics_v2)
│   ├── Tables (users, titles, genres, subscriptions, watch_history, etc.)
│   ├── Views (vw_user_activity_summary, vw_genre_performance, etc.)
│   ├── Stored Procedures (sp_get_user_recommendations, sp_get_genre_trends)
│   ├── Functions (fn_calculate_user_ltv, fn_subscription_duration)
│   └── Triggers (auto-update watch completion, user metrics)
│
└── Streamlit Dashboard (dashboard.py)
    ├── Database Connection Management
    ├── Multi-page Analytics Interface
    └── Interactive Visualizations
```


## Prerequisites

- **SQL Server 2019+** (or compatible version)
- **Python 3.8+**
- **ODBC Driver 17 or 18 for SQL Server**
- **pip** (Python package manager)

### Required Python Libraries
```bash
    streamlit>=1.0.0
    pyodbc>=4.0.0
    pandas>=1.3.0
    plotly>=5.0.0
```

## Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd movie-analytics-recommendation-engine
```

### 2. Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 3. Install SQL Server ODBC Driver
**Windows:**
```bash
# Download and install from Microsoft
# https://docs.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server
```

**macOS:**
```bash
brew install msodbcsql17 mssql-tools
```
**Linux (Ubuntu/Debian):**

```bash
sudo apt-get install odbc-postgresql
sudo apt-get install msodbcsql17
```

## Database Setup

### 1. Create Database and Tables
```bash
# Connect to SQL Server and run:
sqlcmd -S <server> -U sa -P <password> -i 01_Create_Tables.sql
```

### 2. Insert Sample Data
```bash
# Update file paths in 02_Insert_Data.sql, then run:
sqlcmd -S <server> -U sa -P <password> -i 02_Insert_Data.sql
```

### 3. Create Procedures, Functions, and Views
```bash
sqlcmd -S <server> -U sa -P <password> -i 03_Queries_And_Procedures.sql
```

### 4. Update Connection String
Edit dashboard.py and update the connection parameters:
```bash
conn = pyodbc.connect(
    f'DRIVER={{{driver}}};'
    'SERVER=<your-server>,1433;'
    'DATABASE=netflix_analytics_v2;'
    'UID=<your-username>;'
    'PWD=<your-password>;'
    'TrustServerCertificate=yes;'
    'Encrypt=no;'
)
```

## Dashboard Usage
### **Launch the Dashboard**
```bash
streamlit run dashboard.py
```

The dashboard will open at http://localhost:8501
### **Navigation**

Use the sidebar to select different analysis pages:
- Overview: Platform-wide metrics
- User Activity: Individual and aggregate user behavior
- Genre Performance: Content category analysis
- Subscription & Revenue: Financial metrics
- Cross Analysis: Multi-dimensional insights
- Recommender Demo: Test recommendation engine

## Project Structure
```bash
movie-analytics-recommendation-engine/
├── dashboard.py                    # Main Streamlit application
├── 01_Create_Tables.sql           # Database schema definition
├── 02_Insert_Data.sql             # Data loading scripts
├── 03_Queries_And_Procedures.sql  # Stored procedures, views, functions
├── requirements.txt               # Python dependencies
└── README.md                      # This file
```

## Key Queries & Analytics
### User Engagement
- Average watch percentage per user
- Most active countries
- Top users by completed titles
- Watch behavior by age group and subscription type

### Content Performance
- Top watched genres
- Titles with highest completion rates
- Engagement scores by content

### Revenue Analysis
- Active vs inactive subscriptions
- Revenue per subscription type
- User lifetime value (LTV)
- High-engagement, low-revenue user identification

### Recommendations
- Genre-based recommendations
- Personalized suggestions based on watch history
- Trending content analysis

## Database Schema Overview
### Core Tables
- users: User profiles and metadata
- titles: Content library (movies/shows)
- genres: Content categories
- subscriptions: Subscription plans and status
- watch_history: User viewing records
- sources: Content distribution sources
- title_genres: Many-to-many relationship (content-genre mapping)
- title_sources: Many-to-many relationship (content-source mapping)

### Key Views
- vw_user_activity_summary: Aggregated user engagement metrics
- vw_genre_performance: Genre-level analytics
- vw_active_subscriptions: Current active subscriptions
- vw_revenue_analysis: Revenue breakdown
- vw_country_engagement: Regional engagement metrics

### Stored Procedures
- sp_get_user_recommendations: Generate personalized recommendations
- sp_get_genre_trends: Analyze genre-level trends

### Functions
- fn_calculate_user_ltv(): Calculate user lifetime value
- fn_subscription_duration(): Calculate subscription duration

## Performance Optimization
The database includes optimized indexes on frequently queried columns:
- idx_watch_user_date_title: Watch history queries
- idx_subscription_user_status: Subscription lookups
- idx_user_country_subscription: Regional analysis

## Contributing
Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch (git checkout -b feature/AmazingFeature)
3. Commit your changes (git commit -m 'Add AmazingFeature')
4. Push to the branch (git push origin feature/AmazingFeature)
5. Open a Pull Request

## Acknowledgments
SQL Server documentation and best practices
Streamlit framework
Data science and analytics community