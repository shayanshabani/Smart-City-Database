-- 15TH QUERY
@distance
@start_time
@end_time


select * from citizen where 
@distance > (select sum(total_distance) from trip where 
trip.start_time > @start_time and trip.end_time < @end_time
and trip.trip_id in (select trip_id from trip_bill where to_account=citizen.national_id) 
and trip.vehicle_id in (select vehicle_id from public_vehicle where network='bus'));