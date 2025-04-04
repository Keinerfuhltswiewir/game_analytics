/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Куликова Екатерина
 * Дата: 30.12.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT  COUNT(id) AS total_users_counted,
SUM(payer) AS payer_counted,
ROUND(AVG(payer), 4)*100 AS payer_share
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
SELECT race,
SUM(payer) AS payer_counted,
COUNT(id) AS total_users_counted,
ROUND(SUM(payer::numeric)/COUNT(id), 4)*100 AS payer_share_race
FROM fantasy.users AS u LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY payer_share_race DESC;
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT COUNT(amount) AS counted_transaction,
SUM(amount) AS total_amount,
MIN(amount) AS min_amount,
MAX(amount) AS max_amount,
AVG(amount)::NUMERIC(10, 2) AS average_amount,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount),
STDDEV(amount)::NUMERIC(10, 2) AS stand_dev
FROM fantasy.events
WHERE amount <> 0;
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT COUNT(amount) FILTER (WHERE amount = 0) AS null_amount,
(COUNT(transaction_id) FILTER (WHERE amount = 0)/COUNT(transaction_id)::numeric) as null_amount_share
FROM fantasy.events;
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
WITH first_cte AS (
SELECT u.payer,
CASE WHEN payer = 0
THEN 'non_payers'
WHEN payer = 1
THEN 'payers'
END AS payers,
COUNT(DISTINCT u.id) AS users_counted,
COUNT(transaction_id) AS total_transactions,
SUM(amount) AS total_amount
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id = e.id
WHERE amount <> 0
GROUP BY u.payer)
SELECT payers,
users_counted,
total_transactions/users_counted::numeric AS transactions_per_user,
total_amount/users_counted::numeric AS summ_per_user
FROM first_cte;
-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь

WITH first_cte AS (
SELECT game_items,
transaction_id,
amount,
e.id,
COUNT(transaction_id) over() AS total_transactions,
COUNT(distinct e.id) AS total_users
FROM fantasy.events AS e 
FULL JOIN fantasy.users AS u ON e.id = u.id
FULL JOIN fantasy.items AS i ON i.item_code = e.item_code
WHERE amount > 0
GROUP BY game_items, transaction_id
)
SELECT game_items,
total_transactions,
COUNT(transaction_id) AS total_item_transaction,
(SELECT COUNT(e.id) OVER()
FROM fantasy.events AS e
FULL JOIN fantasy.items AS i ON i.item_code = e.item_code
WHERE game_items = i.game_items and amount > 0
GROUP BY e.id
LIMIT 1) AS total_unique_users,
COUNT(DISTINCT id) AS total_users_with_item,
COUNT(transaction_id)::numeric/total_transactions AS transactions_share,
COUNT(DISTINCT id)::numeric/(SELECT COUNT(e.id) OVER()
FROM fantasy.events AS e
FULL JOIN fantasy.items AS i ON i.item_code = e.item_code
WHERE game_items = i.game_items and amount > 0
GROUP BY e.id
LIMIT 1) AS users_with_item_share
FROM first_cte
WHERE amount > 0
GROUP BY game_items, total_transactions, total_users
ORDER BY transactions_share DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь

WITH first_cte AS (
SELECT race,
COUNT(DISTINCT u.id) AS total_users_race
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id = e.id
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY race
) ,
second_cte AS (
SELECT race,
COUNT (DISTINCT e.id) AS users_with_transactions
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id = e.id
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
WHERE amount > 0
GROUP BY race
) ,
third_cte AS (
SELECT race,
COUNT(DISTINCT u.id) AS total_payers
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id = e.id
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
WHERE payer = 1 and amount > 0
GROUP BY race 
),
fourth_cte AS ( 
SELECT race,
COUNT(e.transaction_id::NUMERIC) / COUNT(DISTINCT u.id)::real AS transaction_per_user,
SUM(e.amount::numeric)/COUNT(e.amount) AS avg_transaction,
SUM(e.amount::numeric) / COUNT(DISTINCT u.id) AS amount_per_user
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id = e.id
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
WHERE amount > 0
GROUP BY race
)
SELECT first_cte.race,
total_users_race,
users_with_transactions,
users_with_transactions/total_users_race::numeric AS users_with_transactions_share,
total_payers::numeric/users_with_transactions AS payer_users_share,
amount_per_user,
avg_transaction,
transaction_per_user
FROM first_cte
FULL JOIN second_cte ON first_cte.race = second_cte.race
FULL JOIN third_cte ON first_cte.race = third_cte.race
FULL JOIN fourth_cte ON first_cte.race = fourth_cte.race
ORDER BY transaction_per_user DESC;
