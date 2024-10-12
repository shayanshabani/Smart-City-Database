-- TENTH QUERY
@national_id
SELECT 
    citizen.national_id,
    citizen.first_name,
	SUM(bills.price) AS total_price,
    EXTRACT(MONTH FROM bills.issue_date) AS month,
    EXTRACT(YEAR FROM bills.issue_date) AS year
FROM citizen
LEFT JOIN (
    SELECT to_account, price, issue_date
    FROM house_bill
    UNION ALL
    SELECT to_account, price, issue_date
    FROM parking_bill
    UNION ALL
    SELECT to_account, price, issue_date
    FROM trip_bill
) AS bills ON citizen.national_id = bills.to_account
WHERE citizen.national_id = @national_id
GROUP BY citizen.national_id, citizen.first_name, EXTRACT(MONTH FROM bills.issue_date), EXTRACT(YEAR FROM bills.issue_date)
ORDER BY year, month;