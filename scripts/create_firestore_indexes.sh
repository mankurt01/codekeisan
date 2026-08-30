#!/bin/bash

# Script to create Firestore indexes for device registration
# Make sure firebase-tools is installed globally and you're logged in

# Display current project
firebase use

# Create indexes
echo "Creating Firestore indexes for device registration..."

# Index on deviceId field
firebase firestore:indexes --project keisan-4bf8e --add '{
  "collectionGroup": "device_registrations",
  "queryScope": "COLLECTION", 
  "fields": [{ 
    "fieldPath": "deviceId", 
    "order": "ASCENDING" 
  }]
}'

# Index on email field
firebase firestore:indexes --project keisan-4bf8e --add '{
  "collectionGroup": "device_registrations",
  "queryScope": "COLLECTION",
  "fields": [{
    "fieldPath": "email",
    "order": "ASCENDING"
  }]
}'

echo "Indexes created successfully"
