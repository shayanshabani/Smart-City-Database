-- 13TH QUERY
@start_time
@end_time

select * from citizen where national_id in (
    SELECT DISTINCT b1.to_account
    FROM parking_bill b1 JOIN parking_bill b2 ON b1.to_account = b2.to_account
                AND DATE(b1.start_time) = DATE(b2.start_time - INTERVAL '1 day')
                AND b1.start_time > @start_time AND b2.end_time<@end_time
)
