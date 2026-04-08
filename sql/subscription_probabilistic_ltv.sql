-- Subscription LTV Analysis Case
-- Author: Artem Liakh
-- Description: Funnel, conversion rates, expected LTV,
-- geographic segmentation and revenue projection (6m / 12m)
-- Data source: subscription_payment table
-- Date: 2026-02

SELECT * FROM public.subscription_payment
LIMIT 10;

/* 1. ПЕРЕВІРКА ДАНИХ */

-- Перевіряємо загальну кількість записів у таблиці
SELECT COUNT(*) AS total_rows
FROM public.subscription_payment;

-- Рахуємо кількість NULL значень по кожному полю
SELECT
    COUNT(*) FILTER (WHERE user_id IS NULL) AS user_id_nulls,
    COUNT(*) FILTER (WHERE install_date IS NULL) AS install_date_nulls,
    COUNT(*) FILTER (WHERE subscription_name IS NULL) AS subscription_name_nulls,
    COUNT(*) FILTER (WHERE payment_type IS NULL) AS payment_type_nulls,
    COUNT(*) FILTER (WHERE event_date IS NULL) AS event_date_nulls,
    COUNT(*) FILTER (WHERE country IS NULL) AS country_nulls,
    COUNT(*) FILTER (WHERE device_family IS NULL) AS device_family_nulls,
    COUNT(*) FILTER (WHERE device_type IS NULL) AS device_type_nulls,
    COUNT(*) FILTER (WHERE os_version IS NULL) AS os_version_nulls,
    COUNT(*) FILTER (WHERE language IS NULL) AS language_nulls,
    COUNT(*) FILTER (WHERE system_theme IS NULL) AS system_theme_nulls,
    COUNT(*) FILTER (WHERE refund IS NULL) AS refund_nulls
FROM public.subscription_payment; 
--system_theme 134 NULLS
-- тому подивимось на розподіл:
SELECT
    system_theme,
    COUNT(DISTINCT user_id) AS users
FROM public.subscription_payment
GROUP BY system_theme; 

-- Перевіряємо можливі дублікати (за user_id + event_date)
SELECT
    user_id,
    event_date,
    COUNT(*) AS duplicate_count
FROM public.subscription_payment
GROUP BY user_id, event_date
HAVING COUNT(*) > 1;

-- Перевіряємо, чи немає event_date раніше install_date
SELECT *
FROM public.subscription_payment
WHERE event_date < install_date;
-- 154 рядка

-- Перевірка розподілу значень refund
SELECT
    refund,
    COUNT(*) AS count_rows
FROM public.subscription_payment
GROUP BY refund;

-- Унікальні subscription_name з кількістю
SELECT 
    subscription_name,
    COUNT(*) AS cnt
FROM public.subscription_payment
GROUP BY subscription_name
ORDER BY cnt DESC;

-- Унікальні payment_type з кількістю
SELECT 
    payment_type,
    COUNT(*) AS cnt
FROM public.subscription_payment
GROUP BY payment_type
ORDER BY cnt DESC;

-- Визначаємо часовий проміжок даних у таблиці
SELECT
    MIN(install_date) AS min_install_date,  -- найраніша дата встановлення підписки
    MAX(install_date) AS max_install_date,  -- найпізніша дата встановлення підписки
    MIN(event_date) AS min_event_date,      -- найраніша дата події (платіж чи пробний період)
    MAX(event_date) AS max_event_date       -- найпізніша дата події
FROM public.subscription_payment;

/* 2. РОЗРАХУНКИ*/

-- кількість користувачів, які  встановили додаток (trial)
WITH trial_users AS (
    SELECT DISTINCT user_id
    FROM public.subscription_payment
    WHERE payment_type = 'free_trial'
),
-- кількість користувачів, які зробили хоча б один платіж після trial
paid_users AS (
    SELECT DISTINCT user_id
    FROM public.subscription_payment
    WHERE payment_type = 'recurrent'
)
-- конверсія trial-to-first
SELECT 
    COUNT(paid_users.user_id)::float / COUNT(trial_users.user_id) AS conversion_trial_to_first
FROM trial_users
LEFT JOIN paid_users
ON trial_users.user_id = paid_users.user_id;

-- LTV
WITH cleaned_data AS (
    -- залишаємо тільки коректні платежі (event_date >= install_date)
    -- и виключаємо повернення
    SELECT *
    FROM public.subscription_payment
    WHERE event_date >= install_date
      AND (refund IS NOT TRUE)
),
trial_users AS (
    -- унікальні користувачі, які почали trial
    SELECT DISTINCT user_id
    FROM cleaned_data
    WHERE payment_type = 'free_trial'
),
recurrent_counts AS (
    -- рахуємо, скільки платних тижнів зробив кожен користувач
    SELECT 
        user_id,
        COUNT(*) FILTER (WHERE payment_type = 'recurrent') AS recurrent_count
    FROM cleaned_data
    GROUP BY user_id
),
conversions AS (
    -- рахуємо конверсії між платежами
    SELECT
        COUNT(*) FILTER (WHERE recurrent_count >= 1)::float / NULLIF((SELECT COUNT(*) FROM trial_users),0) AS conv_trial_to_1,
        COUNT(*) FILTER (WHERE recurrent_count >= 2)::float / NULLIF(COUNT(*) FILTER (WHERE recurrent_count >= 1),0) AS conv_1_to_2,
        COUNT(*) FILTER (WHERE recurrent_count >= 3)::float / NULLIF(COUNT(*) FILTER (WHERE recurrent_count >= 2),0) AS conv_2_to_3,
        COUNT(*) FILTER (WHERE recurrent_count >= 4)::float / NULLIF(COUNT(*) FILTER (WHERE recurrent_count >= 3),0) AS conv_3_to_4,
        COUNT(*) FILTER (WHERE recurrent_count >= 5)::float / NULLIF(COUNT(*) FILTER (WHERE recurrent_count >= 4),0) AS conv_4_to_5
    FROM recurrent_counts
),
ltv_calc AS (
    SELECT
        4.99 * 0.7 AS dev_proceeds, -- дохід розробника з одного тижня після комісії Apple
        conv_trial_to_1,
        conv_1_to_2,
        conv_2_to_3,
        conv_3_to_4,
        conv_4_to_5
    FROM conversions
)
SELECT
    dev_proceeds * conv_trial_to_1 AS step_1,
    (dev_proceeds * conv_trial_to_1) * conv_1_to_2 AS step_2,
    ((dev_proceeds * conv_trial_to_1) * conv_1_to_2) * conv_2_to_3 AS step_3,
    (((dev_proceeds * conv_trial_to_1) * conv_1_to_2) * conv_2_to_3) * conv_3_to_4 AS step_4,
    ((((dev_proceeds * conv_trial_to_1) * conv_1_to_2) * conv_2_to_3) * conv_3_to_4) * conv_4_to_5 AS step_5,
    -- підсумковий LTV = сума всіх кроків
    (dev_proceeds * conv_trial_to_1)
    + ((dev_proceeds * conv_trial_to_1) * conv_1_to_2)
    + (((dev_proceeds * conv_trial_to_1) * conv_1_to_2) * conv_2_to_3)
    + ((((dev_proceeds * conv_trial_to_1) * conv_1_to_2) * conv_2_to_3) * conv_3_to_4)
    + ((((dev_proceeds * conv_trial_to_1) * conv_1_to_2) * conv_2_to_3) * conv_3_to_4) * conv_4_to_5
    AS ltv
FROM ltv_calc;


-- Кількість оплат на користувача (без повернень)
WITH cleaned_data AS (
    SELECT *
    FROM public.subscription_payment
    WHERE event_date >= install_date
      AND refund IS NOT TRUE
),
user_payments AS (
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE payment_type = 'recurrent') AS recurrent_count
    FROM cleaned_data
    GROUP BY user_id
),
trial_users AS (
    SELECT DISTINCT user_id
    FROM cleaned_data
    WHERE payment_type = 'free_trial'
)
SELECT
    -- Кількість trial
    (SELECT COUNT(*) FROM trial_users) AS trials,

    -- користувачі, які зробили ≥1 платіж
    COUNT(*) FILTER (WHERE recurrent_count >= 1) AS first_purchase,

    -- ≥2 платежів
    COUNT(*) FILTER (WHERE recurrent_count >= 2) AS second_purchase,

    -- ≥3 платежів
    COUNT(*) FILTER (WHERE recurrent_count >= 3) AS third_purchase,

    -- ≥4 платежів
    COUNT(*) FILTER (WHERE recurrent_count >= 4) AS fourth_purchase,

    -- ≥5 платежів
    COUNT(*) FILTER (WHERE recurrent_count >= 5) AS fifth_purchase

FROM user_payments;

-- конверсії
WITH cleaned_data AS (
    -- прибираємо некоректні дати і повернення платежів
    SELECT *
    FROM public.subscription_payment
    WHERE event_date >= install_date
      AND refund IS NOT TRUE
),

trial_users AS (
    -- Всі користувачі з trial
    SELECT DISTINCT user_id
    FROM cleaned_data
    WHERE payment_type = 'free_trial'
),

user_payments AS (
    -- рахуємо кількість оплат на користувача
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE payment_type = 'recurrent') AS recurrent_count
    FROM cleaned_data
    GROUP BY user_id
),

aggregated AS (
    SELECT
        (SELECT COUNT(*) FROM trial_users) AS trials,
        COUNT(*) FILTER (WHERE recurrent_count >= 1) AS first_purchase,
        COUNT(*) FILTER (WHERE recurrent_count >= 2) AS second_purchase,
        COUNT(*) FILTER (WHERE recurrent_count >= 3) AS third_purchase,
        COUNT(*) FILTER (WHERE recurrent_count >= 4) AS fourth_purchase,
        COUNT(*) FILTER (WHERE recurrent_count >= 5) AS fifth_purchase
    FROM user_payments
)

SELECT
    trials,
    first_purchase,
    second_purchase,
    third_purchase,
    fourth_purchase,
    fifth_purchase,

    ROUND(first_purchase::numeric / NULLIF(trials,0), 4) AS conv_trial_to_1,
    ROUND(second_purchase::numeric / NULLIF(first_purchase,0), 4) AS conv_1_to_2,
    ROUND(third_purchase::numeric / NULLIF(second_purchase,0), 4) AS conv_2_to_3,
    ROUND(fourth_purchase::numeric / NULLIF(third_purchase,0), 4) AS conv_3_to_4,
    ROUND(fifth_purchase::numeric / NULLIF(fourth_purchase,0), 4) AS conv_4_to_5

FROM aggregated;

-- Expected LTV
WITH cleaned_data AS (
    SELECT *
    FROM public.subscription_payment
    WHERE event_date >= install_date
      AND refund IS NOT TRUE
),

-- рахуємо кількість оплат на користувача
user_payments AS (
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE payment_type = 'recurrent') AS recurrent_count
    FROM cleaned_data
    GROUP BY user_id
),

-- агрегуємо воронку
funnel AS (
    SELECT
        COUNT(*) AS trials,
        COUNT(*) FILTER (WHERE recurrent_count >= 1) AS first_purchase,
        COUNT(*) FILTER (WHERE recurrent_count >= 2) AS second_purchase,
        COUNT(*) FILTER (WHERE recurrent_count >= 3) AS third_purchase,
        COUNT(*) FILTER (WHERE recurrent_count >= 4) AS fourth_purchase,
        COUNT(*) FILTER (WHERE recurrent_count >= 5) AS fifth_purchase
    FROM user_payments
),

-- рахуємо конверсії
conversions AS (
    SELECT
        trials,
        first_purchase,
        second_purchase,
        third_purchase,
        fourth_purchase,
        fifth_purchase,

        first_purchase::numeric / trials AS c1,
        second_purchase::numeric / first_purchase AS c2,
        third_purchase::numeric / second_purchase AS c3,
        fourth_purchase::numeric / third_purchase AS c4,
        fifth_purchase::numeric / fourth_purchase AS c5
    FROM funnel
),

-- рахуємо вірогідність дійти до кожної покупки
probabilities AS (
    SELECT
        4.99 * 0.7 AS dev_proceeds,   -- ціна * 70%

        c1 AS p1,
        c1 * c2 AS p2,
        c1 * c2 * c3 AS p3,
        c1 * c2 * c3 * c4 AS p4,
        c1 * c2 * c3 * c4 * c5 AS p5
    FROM conversions
)

SELECT
    ROUND(dev_proceeds, 2) AS dev_proceeds,

    ROUND(dev_proceeds * p1, 2) AS step_1, -- очікуваний дохід (expected revenue)
    ROUND(dev_proceeds * p2, 2) AS step_2,
    ROUND(dev_proceeds * p3, 2) AS step_3,
    ROUND(dev_proceeds * p4, 2) AS step_4,
    ROUND(dev_proceeds * p5, 2) AS step_5,

    ROUND(
        dev_proceeds * (p1 + p2 + p3 + p4 + p5),
        2
    ) AS expected_ltv

FROM probabilities;

/* ФІНАЛЬНИЙ ЗАПИТ ДО ТАБЛИЦІ 3 */

WITH cleaned_data AS (
    SELECT *
    FROM public.subscription_payment
    WHERE event_date >= install_date
      AND refund IS NOT TRUE
),

-- присвоюються групи країн
country_grouped AS (
    SELECT
        user_id,
        CASE
            WHEN country IN (
                'United States','Canada','United Kingdom','Australia'
            ) THEN 'Tier1'

            WHEN country IN (
                'Sweden','Ireland','Belgium','France','Italy','Austria',
                'Germany','Denmark','Norway','Switzerland','Netherlands',
                'New Zealand','Finland','Luxembourg','Iceland'
            ) THEN 'RW'

            WHEN country IN (
                'Chile','Venezuela','Spain','Puerto Rico','Bolivia',
                'Dominican Republic','Ecuador','Panama','Paraguay','Uruguay'
            ) THEN 'Spanish'

            ELSE 'Other'
        END AS region,
        payment_type
    FROM cleaned_data
),

-- розрахунок кількості оплат на користувача всередині регіону
user_payments AS (
    SELECT
        region,
        user_id,
        COUNT(*) FILTER (WHERE payment_type = 'recurrent') AS recurrent_count,
        MAX(CASE WHEN payment_type = 'free_trial' THEN 1 ELSE 0 END) AS has_trial
    FROM country_grouped
    GROUP BY region, user_id
),

aggregated AS (
    SELECT
        region,

        COUNT(*) FILTER (WHERE has_trial = 1) AS trials,

        COUNT(*) FILTER (WHERE recurrent_count >= 1) AS first_purchase,

        COUNT(*) FILTER (WHERE recurrent_count >= 2) AS second_purchase

    FROM user_payments
    GROUP BY region
)

SELECT
    region,

    ROUND(first_purchase::numeric / NULLIF(trials,0), 4) AS cr_to_1st,

    ROUND(second_purchase::numeric / NULLIF(first_purchase,0), 4) AS cr_to_2nd

FROM aggregated
ORDER BY region;
