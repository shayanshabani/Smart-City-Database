-- FOURTH QUERY
@station_id
@start_time
@end_time
SELECT
  EXTRACT(MONTH FROM t.start_time) AS trip_month,  
  COUNT(*) AS trip_count
FROM public_vehicle pv
JOIN trip t ON pv.vehicle_id = t.vehicle_id
WHERE t.start_time BETWEEN @start_time AND @end_time  
AND t.end_time BETWEEN @start_time AND @end_time
  AND (    
	  EXISTS (
      SELECT 1      
		  FROM traversed_path tp1
      WHERE tp1.trip_id = t.trip_id AND tp1.start_station = @station_id    
	  )
    OR    
	  EXISTS (
      SELECT 1      
		  FROM traversed_path tp2
      WHERE tp2.trip_id = t.trip_id AND tp2.end_station = @station_id    
	  )
  )
  GROUP BY trip_month
ORDER BY trip_count desc;