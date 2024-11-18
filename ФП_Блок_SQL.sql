#Блок SQL

#Используя данные таблиц customer_info.xlsx (информация о клиентах) и transactions_info.xlsx (информация о транзакциях за период с 01.06.2015 по 01.06.2016), нужно вывести:
#список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период, средний чек за период с 01.06.2015
# по 01.06.2016, средняя сумма покупок за месяц, количество всех операций по клиенту за период;

#Создаю временную таблицу с суммой покупок каждого клиента по месяцам:
CREATE TEMPORARY TABLE monthly_transactions AS
SELECT id_client, DATE_FORMAT(date_new, '%Y-%m') AS month, SUM(sum_payment) AS total_sum
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY id_client, month;

DROP TABLE monthly_transactions;

#Создаю временную таблицу для отбора клиентов, имеющих транзакции каждый месяц в течение 12 подряд идущих месяцев:
CREATE TEMPORARY TABLE continuous_clients AS
SELECT id_client
FROM monthly_transactions
GROUP BY id_client
HAVING COUNT(DISTINCT month) = 12;

#Создаю временную таблицу с транзакциями клиентов, имеющих непрерывную историю:
CREATE TEMPORARY TABLE transactions_continuous_clients AS
SELECT t.ID_client, t.Id_check, t.Sum_payment, DATE_FORMAT(t.date_new, '%Y-%m') AS month
FROM  transactions t
JOIN continuous_clients cc ON t.ID_client = cc.ID_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01';

#Запускаю запрос для подсчета среднего чека, средней суммы покупок за месяц и общего количества транзакций для каждого клиента:
SELECT c.Id_client,
    AVG(tcc.Sum_payment) AS avg_check,  #средний чек за транзакцию
    AVG(mt.total_sum) AS avg_monthly_amount,  #средняя сумма покупок за месяц
    COUNT(tcc.Id_check) AS total_transactions  #общее количество транзакций
FROM customers AS c
JOIN transactions_continuous_clients AS tcc ON c.Id_client = tcc.ID_client
JOIN monthly_transactions AS mt ON c.Id_client = mt.id_client
GROUP BY c.Id_client
ORDER BY c.Id_client;

#2.информацию в разрезе месяцев:
#a.средняя сумма чека в месяц;
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month,  
    AVG(sum_payment) AS avg_check  
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month
ORDER BY month;

#b. Среднее количество операций в месяц
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month, COUNT(id_check) / COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) AS avg_operations_per_month 
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month
ORDER BY month;

 #c.среднее количество клиентов, которые совершали операции;
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month, COUNT(DISTINCT id_client) AS avg_clients_per_month
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month
ORDER BY month;

#d.долю от общего количества операций за год и долю в месяц от общей суммы операций;
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month, COUNT(id_check) AS total_operations,  SUM(sum_payment) AS total_sum,  
    COUNT(id_check) / (SELECT COUNT(id_check) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01') AS operations_share,  
    SUM(sum_payment) / (SELECT SUM(sum_payment) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01') AS sum_share  
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month
ORDER BY month;

#e.вывести % соотношение M/F/NA в каждом месяце с их долей затрат;
SELECT DATE_FORMAT(t.date_new, '%Y-%m') AS month, c.Gender, COUNT(t.id_check) AS total_operations,  SUM(t.sum_payment) AS total_sum,  
    COUNT(t.id_check) / (SELECT COUNT(id_check) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01') AS operations_share,
    SUM(t.sum_payment) / (SELECT SUM(sum_payment) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01') AS sum_share,
    (COUNT(t.id_check) / (SELECT COUNT(id_check) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01')) * 100 AS operations_percentage,
    (SUM(t.sum_payment) / (SELECT SUM(sum_payment) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01')) * 100 AS sum_percentage
FROM transactions t
JOIN customers c ON t.ID_client = c.Id_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month, c.Gender
ORDER BY month, c.Gender;

#3.возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, с параметрами сумма и количество операций за весь период,
# и поквартально - средние показатели и %.

#Cоздаю запрос для подсчета суммы и количества операций клиентов, сгруппированных по возрастным категориям с шагом в 10 лет
SELECT 
    CASE
        WHEN AGE BETWEEN 0 AND 9 THEN '0-9'
        WHEN AGE BETWEEN 10 AND 19 THEN '10-19'
        WHEN AGE BETWEEN 20 AND 29 THEN '20-29'
        WHEN AGE BETWEEN 30 AND 39 THEN '30-39'
        WHEN AGE BETWEEN 40 AND 49 THEN '40-49'
        WHEN AGE BETWEEN 50 AND 59 THEN '50-59'
        WHEN AGE BETWEEN 60 AND 69 THEN '60-69'
        WHEN AGE BETWEEN 70 AND 79 THEN '70-79'
        WHEN AGE BETWEEN 80 AND 89 THEN '80-89'
        ELSE '90+'
    END AS age_group,
    COUNT(t.id_check) AS total_transactions,  
    SUM(t.sum_payment) AS total_amount  
FROM transactions t
JOIN customers c ON t.ID_client = c.Id_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01' AND c.AGE IS NOT NULL  
GROUP BY age_group
ORDER BY age_group;

#Создаю запрос для клиентов, у которых отсутствуют данные о возрасте. Также рассчитаю общее количество операций и сумму всех транзакций за весь период:

SELECT 'Unknown Age' AS age_group, COUNT(t.id_check) AS total_transactions, SUM(t.sum_payment) AS total_amount
FROM transactions t
JOIN customers c ON t.ID_client = c.Id_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01' AND c.AGE IS NULL  
GROUP BY age_group;


#Создаю запрос для поквартальных данных по сумме и количеству операций:
SELECT CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter,  COUNT(t.id_check) AS total_transactions, SUM(t.sum_payment) AS total_amount  
FROM transactions t
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY quarter
ORDER BY quarter;

#Запрос для расчета средних показателей (средняя сумма и количество операций) по поквартально:
SELECT CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS  quarter, AVG(t.sum_payment) AS avg_check, 
    COUNT(t.id_check) / COUNT(DISTINCT t.ID_client) AS avg_operations_per_client 
FROM transactions t
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY quarter
ORDER BY quarter;

#Запрос для расчета процентов для каждой возрастной группы по количеству операций:
SELECT age_group,
(total_transactions / (SELECT COUNT(id_check) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01')) * 100 AS operations_percentage
FROM 
    (SELECT 
            CASE
                WHEN AGE BETWEEN 0 AND 9 THEN '0-9'
                WHEN AGE BETWEEN 10 AND 19 THEN '10-19'
                WHEN AGE BETWEEN 20 AND 29 THEN '20-29'
                WHEN AGE BETWEEN 30 AND 39 THEN '30-39'
                WHEN AGE BETWEEN 40 AND 49 THEN '40-49'
                WHEN AGE BETWEEN 50 AND 59 THEN '50-59'
                WHEN AGE BETWEEN 60 AND 69 THEN '60-69'
                WHEN AGE BETWEEN 70 AND 79 THEN '70-79'
                WHEN AGE BETWEEN 80 AND 89 THEN '80-89'
                ELSE '90+'
            END AS age_group,
            COUNT(t.id_check) AS total_transactions  
        FROM transactions t
        JOIN customers c ON t.ID_client = c.Id_client
        WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01' AND c.AGE IS NOT NULL  
        GROUP BY age_group) AS age_groups;
        
#Запрос для расчета процентов для клиентов с неопределенным возрастом по количеству операций:
SELECT 'Unknown Age' AS age_group,
    (total_transactions / (SELECT COUNT(id_check) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01')) * 100 AS operations_percentage
FROM 
    (SELECT COUNT(t.id_check) AS total_transactions
        FROM transactions t
        JOIN customers c ON t.ID_client = c.Id_client
        WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01' AND c.AGE IS NULL ) AS unknown_age_group;