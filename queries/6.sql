-- SIXTH QUERY
@start_time
@end_time

SELECT  
    citizen.national_id, 
    COUNT(CASE  
        WHEN start_station IN (SELECT start_station FROM traversed_path WHERE trip_id = trip.trip_id) AND 
             end_station NOT IN (SELECT start_station FROM traversed_path WHERE trip_id = trip.trip_id) THEN start_station 
        WHEN start_station NOT IN (SELECT end_station FROM traversed_path WHERE trip_id = trip.trip_id) AND 
             end_station IN (SELECT end_station FROM traversed_path WHERE trip_id = trip.trip_id) THEN end_station 
        ELSE NULL 
    END) AS total_station 
FROM citizen  
JOIN trip_bill ON citizen.national_id = trip_bill.to_account 
JOIN trip ON trip_bill.trip_id = trip.trip_id 
JOIN traversed_path ON trip.trip_id = traversed_path.trip_id 
WHERE trip.start_time BETWEEN @start_time AND @end_time 
AND trip.end_time BETWEEN @start_time AND @end_time
GROUP BY citizen.national_id 
ORDER BY total_station DESC 
LIMIT 5;