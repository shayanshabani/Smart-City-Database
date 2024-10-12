from random import randint
import random
import string

def random_n(n):
    range_start = 10**(n-1)
    range_end = (10**n)-1
    return randint(range_start, range_end)

def gender():
    if randint(0, 1) == 0:
        return 'male'
    return 'female'

def dob():
    month = str(randint(1, 12))

    day = str(randint(1, 28))
    
    return str(randint(1900, 2022)) + '-' + month + '-' + day

def randomword(length):
   letters = string.ascii_lowercase
   return ''.join(random.choice(letters) for i in range(length))

def x(s):
    return '\'' + s + '\''


query = ''
id_citizen = []
citizens = 'insert into citizen values'
for i in range(1, 1001):
    citizens += '(\''
    citizens += str(i)
    id_citizen.append(str(i))
    citizens += '\',\''
    citizens += gender()
    citizens += '\',\''
    citizens += dob()
    citizens += '\',\''
    citizens += randomword(randint(5, 10))
    citizens += '\',\''
    citizens += randomword(randint(5, 10))
    citizens += '\',\''
    citizens += random.choice(id_citizen)
    citizens += '\'),\n'

query += citizens

houses = 'insert into house values'
id_house = []
for i in range(1, 501):
    houses += '(\''
    houses += str(i)
    houses += '\',\''
    id_house.append(str(i))
    houses += str(i)
    houses += '\',\''
    houses += randomword(randint(5, 10))
    houses += '\',\''
    houses += randomword(randint(5, 10))
    houses += '\',\''
    houses += str(random_n(12))
    houses += '\','
    houses += 'point(' + str(randint(0, 1000)) + ',' + str(randint(0, 1000)) + ')'
    houses += '),\n'

query += houses

accounts = 'insert into account values'
acc_no = []
for i in range(1, 1001):
    accounts += '(\''
    accounts += str(i)
    acc_no.append(str(i))
    accounts += '\','
    accounts += str(randint(0, 1000000))
    accounts += '),\n'

query += accounts

h_s_request = 'insert into house_service_request values'
for i in range(1, 501):
    h_s_request += '(\''
    h_s_request += str(i)
    h_s_request += '\',\''
    h_s_request += 'water'
    h_s_request += '\',\''
    h_s_request += '1970-1-1'
    h_s_request += '\','
    h_s_request += '1'
    h_s_request += ','
    h_s_request += 'TRUE'
    h_s_request += '),\n'
for i in range(1, 301):
    k = 1
    for j in ('power', 'gas'):
        k += 1
        if randint(0, 10) < 5: 
            h_s_request += '(\''
            h_s_request += str(i)
            h_s_request += '\',\''
            h_s_request += j
            h_s_request += '\',\''
            h_s_request += dob()
            h_s_request += '\','
            h_s_request += str(k)
            h_s_request += ','
            h_s_request += random.choice(['TRUE', 'FALSE'])
            h_s_request += '),\n'

query += h_s_request

d_usage = 'insert into daily_usage values'
usages = [0]
for i in range(101, 201):
    usages.append(randint(1,3))
    for j in range(1, 15):
        d_usage += '(\''
        d_usage += str(i)
        d_usage += '\',\''
        d_usage += 'water'
        d_usage += '\',\''
        d_usage += '1970-1-1'
        d_usage += '\',\''
        d_usage += '2023-12-' + str(j)
        d_usage += '\','
        d_usage += str(usages[-1])
        d_usage += ',\''
        d_usage += str(i)
        d_usage += '\'),\n'


h_bill = 'insert into house_bill values'
id_bill = []
for i in range(201, 301):
    h_bill += '(\''
    h_bill += str(i)
    id_bill.append(str(i))
    h_bill += '\',\''
    h_bill += str(i)
    h_bill += '\',\''
    start_year = 2023
    start_month = 12
    h_bill += str(start_year) + '-' + str(start_month) + '-' + '15'
    h_bill += '\','
    h_bill += str(usages[i - 200] * 7)
    h_bill += ',\''
    h_bill += str(start_year) + '-' + str(start_month) + '-' + '1'
    h_bill += '\',\''
    h_bill += str(start_year) + '-' + str(start_month) + '-' + '8'
    h_bill += '\'),\n'
for i in range(301, 401):
    h_bill += '(\''
    h_bill += str(i)
    id_bill.append(str(i))
    h_bill += '\',\''
    h_bill += str(i - 100)
    h_bill += '\',\''
    start_year = 2020
    start_month = 1
    h_bill += str(start_year) + '-' + str(start_month) + '-' + '16'
    h_bill += '\','
    h_bill += str(usages[i - 300] * 7)
    h_bill += ',\''
    h_bill += str(start_year) + '-' + str(start_month) + '-' + '8'
    h_bill += '\',\''
    h_bill += str(start_year) + '-' + str(start_month) + '-' + '15'
    h_bill += '\'),\n'

query += h_bill

query += d_usage


p_vehicle = 'insert into personal_vehicle values'
id_p_vehicle = []
for i in range(1,101):
    p_vehicle += '(\''
    p_vehicle += str(i)
    id_p_vehicle.append(str(i))
    p_vehicle += '\',\''
    p_vehicle += str(i)
    p_vehicle += '\',\''
    p_vehicle += randomword(5)
    p_vehicle += '\',\''
    p_vehicle += randomword(6)
    p_vehicle += '\'),\n'

query += p_vehicle

parking = 'insert into parking values'
id_parking = []
for i in range(1, 11):
    parking += '(\''
    parking += str(i)
    id_parking.append(str(i))
    parking += '\',\''
    parking += '8:00:00'
    parking += '\',\''
    parking += '22:00:00'
    parking += '\',\''
    parking += randomword(6)
    parking += '\','
    parking += 'point(' + str(randint(0, 1000)) + ',' + str(randint(0, 1000)) + ')'
    parking += ','
    parking += str(randint(100, 200))
    parking += ','
    parking += str(i)
    parking += '),\n'

query += parking

p_bill = 'insert into parking_bill values'
id_p_bill = []
for i in range(1, 101):
    p_bill += '(\''
    p_bill += str(i)
    id_p_bill.append(str(i))
    p_bill += '\',\''
    p_bill += str(i)
    p_bill += '\',\''
    p_bill += str(i % 10 + 1)
    p_bill += '\',\''
    p_bill += str(i)
    p_bill += '\',\''
    p_bill += '2020-1-15'
    p_bill += '\','
    p_bill += str(5 * (i % 10 + 1))
    p_bill += ',\''
    p_bill += '2022-1-1 12:00:00'
    p_bill += '\',\''
    p_bill += '2022-1-1 17:00:00'
    p_bill += '\'),\n'

query += p_bill

network = 'insert into network values(\'bus\',1),(\'metro\',2),(\'taxi\',3);'

query += network

networks = ['bus', 'metro', 'taxi']

pu_vehicle = 'insert into public_vehicle values'
id_pu_vehicle = []
for i in range(1,91):
    pu_vehicle += '(\''
    pu_vehicle += str(i)
    pu_vehicle += '\',\''
    pu_vehicle += str(i)
    pu_vehicle += '\',\''
    pu_vehicle += networks[i % 3]
    pu_vehicle += '\',\''
    pu_vehicle += randomword(5)
    pu_vehicle += '\',\''
    pu_vehicle += randomword(5)
    pu_vehicle += '\'),\n'

query += pu_vehicle

path = 'insert into path values'
id_path = []
for i in range(1, 7):
    path += '(\''
    path += str(i)
    id_path.append(str(i))
    path += '\',\''
    path += networks[i % 3]
    path += '\',\''
    path += 'khat-' + str(i % 3)
    path += '\'),\n'

query += path

station = 'insert into station values'
id_station = []
for i in range(1, 31):
    station += '('
    station += str(i)
    id_station.append(str(i))
    station += ','
    station += 'point(' + str(randint(0, 1000)) + ',' + str(randint(0, 1000)) + ')'
    station += ',\''
    station += randomword(6)
    station += '\'),\n'

query += station

s_path = 'insert into station_path values'
e_i_path = 'insert into edge_in_path values'
for j in range(1, len(id_path) + 1):
    for k in range(1,len(id_station) // len(id_path) + 1):
        i = (j - 1) * (len(id_station) // len(id_path)) + k
        s_path += '(\''
        s_path += str(j)
        s_path += '\','
        s_path += str(i)
        s_path += '),\n'

        e_i_path += '(\''
        e_i_path += str(j)
        e_i_path += '\','
        e_i_path += str(i)
        e_i_path += ','
        e_i_path += str(i % 30 + 1)
        e_i_path += ','
        e_i_path += str(randint(10,30))
        e_i_path += ','
        e_i_path += str(i % 2 + 1)
        e_i_path += '),\n'

    s_path += '(\''
    s_path += str(j)
    s_path += '\','
    s_path += str(i % len(id_station) + 1)
    s_path += '),\n'

query += s_path
query += e_i_path

t_path = 'insert into traversed_path values(5,1,1,2,\'2023-12-17 12:0:0\'),\n'
t_path += '(5,1,2,3,\'2023-12-17 12:0:10\'),\n'
t_path += '(5,1,3,4,\'2023-12-17 12:0:20\'),\n'

t_path += '(6,1,2,3,\'2023-12-17 12:0:10\'),\n'
t_path += '(6,1,3,4,\'2023-12-17 12:0:20\'),\n'
t_path += '(6,1,4,5,\'2023-12-17 12:0:30\'),\n'

t_path += '(7,2,1,2,\'2023-12-17 13:0:0\'),\n'
t_path += '(7,2,2,3,\'2023-12-17 13:0:10\'),\n'
t_path += '(7,2,3,4,\'2023-12-17 13:0:20\'),\n'

t_path += '(8,2,2,3,\'2023-12-17 13:0:10\');'

query += t_path

trip = 'insert into trip values(5,\'1\',\'2023-12-17 12:0:0\',\'2023-12-17 12:0:30\',5),\n'
trip += '(6,\'1\',\'2023-12-17 12:0:10\',\'2023-12-17 12:0:40\',4),\n'
trip += '(7,\'2\',\'2023-12-17 13:0:0\',\'2023-12-17 13:0:30\',5),\n'
trip += '(8,\'2\',\'2023-12-17 13:0:10\',\'2023-12-17 13:0:20\',1);'

query += trip

t_bill = 'insert into trip_bill values(\'5\',5,\'1\',\'2023-12-8\',5),\n'
t_bill += '(\'6\',6,\'2\',\'2023-12-9\',4),\n'
t_bill += '(\'7\',7,\'1\',\'2023-12-10\',10),\n'
t_bill += '(\'8\',8,\'3\',\'2023-12-10\',2);'

query += t_bill

f = open("F:\Term4\DB\cos1.sql", 'w+')
f.write(t_path + trip + t_bill)
f.close()
