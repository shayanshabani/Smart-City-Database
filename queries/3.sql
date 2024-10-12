-- THIRD QUERY
@start_time
@end_time
SELECT driver,        
COALESCE(SUM(total_distance), 0) AS total_distance
FROM public_vehicle LEFT JOIN trip ON public_vehicle.vehicle_id = trip.vehicle_id
WHERE trip.start_time BETWEEN @start_time AND @end_time
AND trip.end_time BETWEEN @start_time AND @end_time
GROUP BY driver
ORDER BY total_distance DESC
LIMIT 5;