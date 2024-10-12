-- NINTH QUERY
@parking_id
WITH TimePoints AS (
    SELECT DISTINCT start_time AS time_point FROM parking_bill where parking_bill.parking_id = @parking_id
    UNION
    SELECT DISTINCT end_time FROM parking_bill where parking_bill.parking_id = @parking_id
),
OverlappingIntervals AS (
    SELECT 
        tp.time_point AS interval_time,
        COUNT(*) AS overlapping_intervals
    FROM 
        TimePoints tp
    JOIN 
        parking_bill pb ON tp.time_point BETWEEN pb.start_time AND pb.end_time
    GROUP BY 
        tp.time_point
)
SELECT 
    interval_time,
    overlapping_intervals
FROM 
    OverlappingIntervals
ORDER BY 
    overlapping_intervals DESC
LIMIT 1;