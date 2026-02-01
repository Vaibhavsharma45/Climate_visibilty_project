# from pymongo import MongoClient

# uri = "mongodb+srv://climate_user:climate123@cluster0.ri74v18.mongodb.net/?appName=Cluster0"
# client = MongoClient(uri)

# print(client.list_database_names())
from pymongo import MongoClient

uri = "mongodb+srv://climate_user:climate123@cluster0.ri74v18.mongodb.net/?appName=Cluster0"
client = MongoClient(uri)

db = client["climate_db"]
collection = db["weather_data"]

collection.insert_one({"status": "first insert success"})
print("✅ climate_db & weather_data created")
