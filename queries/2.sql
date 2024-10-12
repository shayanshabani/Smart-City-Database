-- SECOND QUERY
@start_date
@end_date
SELECT headman,
       COALESCE(SUM(house_price), 0) + COALESCE(SUM(parking_price), 0) + COALESCE(SUM(trip_price), 0) AS total
FROM citizen
JOIN account ON citizen.national_id = account.owner
LEFT JOIN (
    SELECT to_account,            
	SUM(price) AS house_price
    FROM house_bill    
	WHERE issue_date BETWEEN @start_date AND @end_date
    GROUP BY to_account) AS house_bills ON citizen.national_id = house_bills.to_account
LEFT JOIN (    
	SELECT to_account, 
           SUM(price) AS parking_price    
	FROM parking_bill
    WHERE issue_date BETWEEN @start_date AND @end_date    
	GROUP BY to_account
) AS parking_bills ON citizen.national_id = parking_bills.to_account
LEFT JOIN (
    SELECT to_account,            
	SUM(price) AS trip_price
    FROM trip_bill    
	WHERE issue_date BETWEEN @start_date AND @end_date
    GROUP BY to_account) AS trip_bills ON citizen.national_id = trip_bills.to_account
GROUP BY headman
ORDER BY total DESC
LIMIT 5;