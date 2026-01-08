import streamlit as st
import pandas as pd
import pyodbc
import altair as alt

# ------------------------------
# Database connection configuration
# ------------------------------
@st.cache_resource
def init_connection():
    drivers = [x for x in pyodbc.drivers() if 'SQL Server' in x]
    for driver in drivers:
        print(f"Found driver: {driver}")
    
    drivers_sorted = sorted(drivers, key=lambda x: '18' in x, reverse=True)
    
    if not drivers:
        st.error("No SQL Server ODBC drivers found. Please install msodbcsql17.")
        st.info(f"Available drivers: {pyodbc.drivers()}")
        return None
    
    # st.info("Attempting to connect to SQL Server...")
    
    for driver in drivers_sorted:
        try:
            conn = pyodbc.connect(
                f'DRIVER={{{driver}}};'
                'SERVER=0.0.0.0,1433;'
                'DATABASE=netflix_analytics;'
                'UID=sa;'
                'PWD=p@ssw0rd;'
                'TrustServerCertificate=yes;'
                'Encrypt=no;'

            )
            cursor = conn.cursor()
            cursor.execute("SELECT @@VERSION")
            version = cursor.fetchone()[0]
            cursor.close()
            # st.success(f"Connected using driver: {driver}")
            return conn
        except pyodbc.Error as e:
            print(f"Failed with {driver}: {str(e)}")
            continue
        except Exception as e:
            print(f"Unexpected error with {driver}: {str(e)}")
            continue
    
    st.error(f"Database connection failed with all available drivers: {drivers}")
    return None

# ------------------------------
# Query execution function
# ------------------------------
@st.cache_data(ttl=600)
def run_query(query=None):
    conn = init_connection()
    if conn is None:
        return pd.DataFrame()
    try:
        if query is not None:
            df = pd.read_sql(query, conn)
            return df
        return "HI"
    except Exception as e:
        st.error(f"Query execution failed: {e}")
        return pd.DataFrame()

# ------------------------------
# Streamlit App Layout
# ------------------------------
st.set_page_config(page_title="Netflix Analytics", layout="wide")
st.title("Netflix Analytics Dashboard")

page = st.sidebar.selectbox(
    "Select Analysis",
    ["Overview", "User Activity", "Genre Performance", "Subscription & Revenue", "Cross Analysis", "Recommender Demo"]
)

# ================================
# Overview Page
# ================================
if page == "Overview":
    st.header("Platform Overview")
    
    col1, col2, col3, col4 = st.columns(4)
    
    total_users = run_query("SELECT COUNT(*) AS count FROM users")
    active_subs = run_query("SELECT COUNT(*) AS count FROM vw_active_subscriptions")
    total_titles = run_query("SELECT COUNT(*) AS count FROM titles")
    total_watches = run_query("SELECT COUNT(*) AS count FROM watch_history")
    
    col1.metric("Total Users", f"{total_users['count'][0]:,}")
    col2.metric("Active Subscriptions", f"{active_subs['count'][0]:,}")
    col3.metric("Total Titles", f"{total_titles['count'][0]:,}")
    col4.metric("Total Watches", f"{total_watches['count'][0]:,}")

    st.subheader("Revenue Analysis")
    revenue_data = run_query("SELECT * FROM vw_revenue_analysis")
    if not revenue_data.empty:
        st.dataframe(revenue_data, use_container_width=True)
        st.bar_chart(revenue_data.set_index('subscription_type')['monthly_revenue'])

# ================================
# User Activity Page
# ================================
elif page == "User Activity":
    st.header("User Activity Analysis")

    st.subheader("User Activity Summary")
    user_activity = run_query("SELECT TOP 50 * FROM vw_user_activity_summary ORDER BY watch_time_hours DESC")
    st.dataframe(user_activity, use_container_width=True)

    st.subheader("SQL Behind the View")
    st.code("""
        CREATE OR ALTER VIEW vw_user_activity_summary AS
        SELECT 
            u.user_id, u.name, u.country, u.subscription_type,
            u.watch_time_hours,
            COUNT(DISTINCT wh.title_id) AS titles_watched,
            COUNT(wh.watch_id) AS total_watches,
            SUM(CAST(wh.completed AS INT)) AS completed_watches,
            ROUND(AVG(CAST(wh.watch_percentage AS FLOAT)) * 100, 2) AS avg_watch_percentage
        FROM users u
        LEFT JOIN watch_history wh ON u.user_id = wh.user_id
        GROUP BY u.user_id, u.name, u.country, u.subscription_type, u.watch_time_hours;
        """, language="sql")

    st.subheader("Engagement by Country")
    country_data = run_query("SELECT * FROM vw_country_engagement ORDER BY user_count DESC")
    st.dataframe(country_data, use_container_width=True)
    
    col1, col2 = st.columns(2)
    with col1:
        st.write("**Average Watch Hours by Country**")
        country_chart = (
            alt.Chart(country_data.head(10))
            .mark_bar()
            .encode(
                x=alt.X('avg_watch_hours:Q', title='Avg Watch Hours'),
                y=alt.Y('country:N', sort='-x', title='Country'),
                color=alt.Color('avg_watch_hours:Q', scale=alt.Scale(scheme='blues'), legend=None),
                tooltip=['country', 'avg_watch_hours', 'user_count', 'avg_completion_rate']
            )
            .properties(height=400)
        )
        st.altair_chart(country_chart, use_container_width=True)
    
    with col2:
        st.write("**Completion Rate vs User Count**")
        scatter_chart = (
            alt.Chart(country_data)
            .mark_circle(size=100)
            .encode(
                x=alt.X('user_count:Q', title='Number of Users'),
                y=alt.Y('avg_completion_rate:Q', title='Avg Completion Rate (%)'),
                size=alt.Size('avg_watch_hours:Q', title='Avg Watch Hours'),
                color=alt.Color('country:N', legend=None),
                tooltip=['country', 'user_count', 'avg_completion_rate', 'avg_watch_hours']
            )
            .properties(height=400)
        )
        st.altair_chart(scatter_chart, use_container_width=True)
    
    st.code("""
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
        """, language="sql")
    
    st.subheader("Average watch percentage per user")
    query = """
    SELECT 
        u.user_id,
        u.name,
        ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_percentage,
        COUNT(wh.watch_id) AS total_watches,
        SUM(wh.completed) AS completed_watches
    FROM users u
    LEFT JOIN watch_history wh ON u.user_id = wh.user_id
    GROUP BY u.user_id, u.name
    ORDER BY avg_watch_percentage DESC;"""
    data = run_query(query)
    st.dataframe(data, use_container_width=True)
    
    top_users = data.head(15)
    user_chart = (
        alt.Chart(top_users)
        .mark_bar()
        .encode(
            x=alt.X('avg_watch_percentage:Q', title='Avg Watch Percentage (%)', scale=alt.Scale(domain=[0, 100])),
            y=alt.Y('name:N', sort='-x', title='User'),
            color=alt.condition(
                alt.datum.avg_watch_percentage > 80,
                alt.value('green'),
                alt.value('steelblue')
            ),
            tooltip=['name', 'avg_watch_percentage', 'total_watches', 'completed_watches']
        )
        .properties(height=500)
    )
    st.altair_chart(user_chart, use_container_width=True)
    st.code(query, language="sql")

    st.subheader("Top users by completed titles")
    query = """
    SELECT TOP 10
        u.user_id,
        u.name,
        SUM(wh.completed) AS completed_watches
    FROM users u
    JOIN watch_history wh ON u.user_id = wh.user_id
    GROUP BY u.user_id, u.name
    ORDER BY completed_watches DESC;"""
    data = run_query(query)
    st.dataframe(data, use_container_width=True)
    
    completion_chart = (
        alt.Chart(data)
        .mark_bar()
        .encode(
            x=alt.X('completed_watches:Q', title='Completed Watches'),
            y=alt.Y('name:N', sort='-x', title='User'),
            color=alt.Color('completed_watches:Q', scale=alt.Scale(scheme='greens'), legend=None),
            tooltip=['name', 'completed_watches']
        )
        .properties(height=400)
    )
    st.altair_chart(completion_chart, use_container_width=True)
    st.code(query, language="sql")

    st.subheader("Watch Behavior by Subscription Type & Age Group")
    query = """
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
    ORDER BY ag.age_group, ag.subscription_type;"""
    data = run_query(query)
    st.dataframe(data, use_container_width=True)
    
    st.subheader("Watch Events by Age Group & Subscription Type")
    grouped_chart = (
        alt.Chart(data)
        .mark_bar()
        .encode(
            x=alt.X('age_group:N', title='Age Group', axis=alt.Axis(labelAngle=-45)),
            y=alt.Y('total_watch_events:Q', title='Total Watch Events'),
            color=alt.Color('subscription_type:N', title='Subscription Type'),
            column=alt.Column('subscription_type:N', title='Subscription Type'),
            tooltip=['age_group', 'subscription_type', 'total_watch_events', 'avg_watch_percentage', 'users_in_segment']
        )
        .properties(width=200, height=300)
    )
    st.altair_chart(grouped_chart)
    
    # Additional heatmap visualization
    st.subheader("Average Watch Percentage Heatmap")
    heatmap = (
        alt.Chart(data)
        .mark_rect()
        .encode(
            x=alt.X('subscription_type:N', title='Subscription Type'),
            y=alt.Y('age_group:N', title='Age Group'),
            color=alt.Color('avg_watch_percentage:Q', 
                          scale=alt.Scale(scheme='viridis'),
                          title='Avg Watch %'),
            tooltip=['age_group', 'subscription_type', 'avg_watch_percentage', 'total_watch_events']
        )
        .properties(width=400, height=400)
    )
    st.altair_chart(heatmap, use_container_width=True)
    st.code(query, language="sql")


# ================================
# Genre / Titles Performance Page
# ================================
elif page == "Genre Performance":
    st.header("Genre & Titles Performance Analysis")

    query = """
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
    GROUP BY g.genre_id, g.name;"""
    genre_data = run_query("SELECT * FROM vw_genre_performance ORDER BY total_watches DESC")
    if not genre_data.empty:
        st.subheader("Genre Metrics")
        st.dataframe(genre_data, use_container_width=True)
        
        col1, col2 = st.columns(2)
        with col1:
            st.write("**Total Watches by Genre**")
            watches_chart = (
                alt.Chart(genre_data)
                .mark_bar()
                .encode(
                    x=alt.X('total_watches:Q', title='Total Watches'),
                    y=alt.Y('genre_name:N', sort='-x', title='Genre'),
                    color=alt.Color('total_watches:Q', scale=alt.Scale(scheme='blues'), legend=None),
                    tooltip=['genre_name', 'total_watches', 'avg_watch_percentage', 'unique_viewers']
                )
                .properties(height=500)
            )
            st.altair_chart(watches_chart, use_container_width=True)
        
        with col2:
            st.write("**Avg Watch Percentage by Genre**")
            percentage_chart = (
                alt.Chart(genre_data)
                .mark_bar()
                .encode(
                    x=alt.X('avg_watch_percentage:Q', title='Avg Watch Percentage (%)', scale=alt.Scale(domain=[0, 100])),
                    y=alt.Y('genre_name:N', sort='-x', title='Genre'),
                    color=alt.Color('avg_watch_percentage:Q', scale=alt.Scale(scheme='greens'), legend=None),
                    tooltip=['genre_name', 'avg_watch_percentage', 'total_watches', 'unique_viewers']
                )
                .properties(height=500)
            )
            st.altair_chart(percentage_chart, use_container_width=True)
        
        st.code(query, language="sql")

    st.subheader("Title-Level Analysis")
    query = """
        SELECT TOP 50
            t.title, t.release_year, t.imdb_score,
            COUNT(wh.watch_id) AS total_watches,
            ROUND(AVG(wh.watch_percentage), 2) AS avg_watch_percentage
        FROM titles t
        LEFT JOIN watch_history wh ON t.title_id = wh.title_id
        GROUP BY t.title, t.release_year, t.imdb_score
        ORDER BY total_watches DESC
    """
    title_data = run_query(query)
    st.dataframe(title_data, use_container_width=True)
    st.bar_chart(title_data.set_index('title')['total_watches'])
    st.code(query, language="sql")

    st.subheader("Titles with highest completion rates")
    query = """
    SELECT TOP 20
    t.title,
    ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_percentage,
    SUM(wh.completed) AS total_completed
    FROM titles t
    JOIN watch_history wh ON t.title_id = wh.title_id
    GROUP BY t.title
    ORDER BY avg_watch_percentage DESC, total_completed DESC;"""
    data = run_query(query)
    st.dataframe(data, use_container_width=True)
    st.bar_chart(data.set_index('title')['total_completed'])
    st.code(query, language="sql")

    st.subheader("Genre with highest engagement score")
    query = """
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
    END;"""
    data = run_query('EXEC sp_get_genre_trends')
    st.dataframe(data, use_container_width=True)
    st.bar_chart(data.set_index('genre_name')['engagement_score'])
    st.code(query, language="sql")

    

# ================================
# Subscription & Revenue Page
# ================================
elif page == "Subscription & Revenue":
    st.header("Subscription & Revenue Analytics")

    query="""
        SELECT subscription_type, COUNT(subscription_id) AS subscriber_count,
               SUM(monthly_fee) AS total_monthly_revenue,
               ROUND(AVG(monthly_fee), 2) AS avg_fee
        FROM subscriptions
        WHERE subscription_status='active'
        GROUP BY subscription_type
    """
    sub_data = run_query(query)
    st.subheader("Revenue by Subscription Type")
    st.dataframe(sub_data, use_container_width=True)
    st.bar_chart(sub_data.set_index('subscription_type')['total_monthly_revenue'])
    st.code(query, language="sql")

    query="""
        SELECT u.user_id, u.name, dbo.fn_calculate_user_ltv(u.user_id) AS lifetime_value
        FROM users u
        ORDER BY lifetime_value DESC
    """
    ltv_data = run_query(query)
    st.subheader("Top Users by Lifetime Value")
    st.dataframe(ltv_data.head(10), use_container_width=True)
    st.code(query, language="sql")
    st.code("""
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
    """, language="sql")

# ================================
# Cross-Analysis: Content vs User Engagement
# ================================
elif page == "Cross Analysis":
    st.header("Cross-Analysis: Content vs User Engagement")

    query="""SELECT 
        u.country,
        g.name AS genre,
        ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_percentage,
        COUNT(wh.watch_id) AS total_watches
    FROM users u
    JOIN watch_history wh ON u.user_id = wh.user_id
    JOIN title_genres tg ON wh.title_id = tg.title_id
    JOIN genres g ON tg.genre_id = g.genre_id
    GROUP BY u.country, g.name
    ORDER BY u.country, avg_watch_percentage DESC;"""
    data = run_query(query)
    st.subheader("Active vs Inactive subscriptions")
    st.dataframe(data, use_container_width=True)
    st.code(query, language="sql")

    query="""
    SELECT 
        u.user_id,
        u.name,
        ROUND(AVG(wh.watch_percentage * 100), 2) AS avg_watch_percentage,
        dbo.fn_calculate_user_ltv(u.user_id) AS lifetime_value
    FROM users u
    JOIN watch_history wh ON u.user_id = wh.user_id
    GROUP BY u.user_id, u.name
    HAVING AVG(wh.watch_percentage) > 0.8 AND dbo.fn_calculate_user_ltv(u.user_id) < 50
    ORDER BY avg_watch_percentage DESC;"""
    data = run_query(query)
    st.subheader("Users with high watch percentage but low subscription revenue")
    st.dataframe(data, use_container_width=True)
    st.code(query, language="sql")

# ------------------------------
# Recommender Demo Page
# ------------------------------
elif page == "Recommender Demo":
    st.header("Recommender System & Trigger Demo")

    # Fetch users
    users_df = run_query("SELECT user_id, name FROM users")
    if users_df.empty:
        st.info("No users available.")
    else:
        # Remove duplicate names
        users_df['display'] = users_df['name'] + " (" + users_df['user_id'] + ")"
        selected_display = st.selectbox("Select User:", users_df['display'])
        user_id = users_df.loc[users_df['display'] == selected_display, 'user_id'].values[0]


        # Fetch titles
        titles_df = run_query("SELECT title_id, title FROM titles ORDER BY title")
        if titles_df.empty:
            st.info("No titles available.")
        else:
            selected_title = st.selectbox("Select Title to Watch:", titles_df['title'])
            if selected_title is not None:
                title_id = titles_df.loc[titles_df['title'] == selected_title, 'title_id'].values[0]

                # Watch percentage input
                watch_percentage = st.slider("Watch Percentage", min_value=0, max_value=100, value=50)

                default_recs = 5

                number_of_recommendations = st.number_input(
                    "Enter number of recommendations:", 
                    min_value=1, max_value=50, value=default_recs, step=1
                )

                if st.button("Simulate Watching"):
                    conn = init_connection()
                    if conn:
                        try:
                            cursor = conn.cursor()
                            watch_percentage_decimal = watch_percentage / 100
                            cursor.execute("""
                                INSERT INTO watch_history 
                                (user_id, title_id, watch_percentage, completed, created_at, updated_at)
                                VALUES (?, ?, ?, ?, SYSDATETIME(), SYSDATETIME())
                            """, user_id, title_id, watch_percentage_decimal, 0)

                            conn.commit()

                            st.success("Watch history recorded! Trigger updated user watch_time_hours and completed flag.")

                            # User Metrics
                            user_metrics = run_query(f"""
                                SELECT name, watch_time_hours
                                FROM users
                                WHERE user_id='{user_id}'
                            """)
                            st.subheader("User Watch Time")
                            st.dataframe(user_metrics, use_container_width=True)

                            # Recent Watch History
                            recent_wh = run_query(f"""
                                SELECT TOP 5 *
                                FROM watch_history
                                WHERE user_id='{user_id}'
                                ORDER BY created_at DESC
                            """)
                            st.subheader("Recent Watch History")
                            st.dataframe(recent_wh, use_container_width=True)

                            recommendations = run_query(f"""
                                EXEC sp_get_user_recommendations @p_user_id='{user_id}', @p_limit={number_of_recommendations}
                            """)

                            st.subheader("Recommended Titles")
                            if not recommendations.empty:
                                st.dataframe(recommendations, use_container_width=True)
                                st.bar_chart(recommendations.set_index('title')['avg_rating'])
                            else:
                                st.info("No recommendations available yet.")
                            st.code("""
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
                            END;""", language="sql")

                        except Exception as e:
                            st.error(f"Error: {e}")
        

