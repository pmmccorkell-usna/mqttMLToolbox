# Patrick McCorkell
# April 2021
# US Naval Academy
# Robotics and Control TSD

import paho.mqtt.client as MQTT
from random import randint
from json import dumps
from math import pi as pie
from cmath import exp as trueExp

# The set of RigidBody objects which will be published.
# Starts empty. See 'objectList' for the totality of possible contents.
dynamicList = set()

############################################################
################# MQTT CONNECTION HANDLING #################
############################################################

is_connected=0

clientname="MLpyDynamic"+str(randint(1000,9999))
client=MQTT.Client(clientname)

# Connect to MQTT broker.
def mqttConnect():
	global client, is_connected

	# Some settings for MQTT connection.
	# serverIP = '127.0.0.1'	# loopback
	serverIP = 'YOUR_SERVER'	# OptiTrack server
	
	# Unique clientname. Random element to prevent collisions during
	# frequent reconnections, outages, intermittent issues, etc.
	

	# Only connect if not already connected.
	if not is_connected:
		client.connect(serverIP)
		client.loop_start()
		print("Connected to "+serverIP)
		is_connected=1
	# else:
		# shhhh
		# print("Already connected")

# Break connection to MQTT broker.
# Called from within Matlab to properly deconstruct MQTT client.
def mqttTerminate():
	global client
	client.loop_stop()
	client.disconnect()
	is_connected=0
	print("Terminated python MQTT")


#####################################################################
####################### SUBSCRIPTION CALLBACK #######################
#####################################################################

# A list of objects in a RigidBody struct.
# For pattern matching and error checking.
# See Professor Kutzer's OptiTrack Toolbox for Matlab.
objectList= [
	'Name',
	'FrameIndex',
	'TimeStamp',
	'FrameLatency',
	'isTracked',
	'Position',
	'Quaternion',
	'Rotation',
	'HgTransform',
	'MarkerPosition',
	'MarkerSize'
]

# Receives message data from MQTT callback function.
# Scans and adds matches to dynamicList.
def AddObject(data):
	global dynamicList, objectList
	msg = data.payload.decode().lower()
	for obj in objectList:
		if (msg == obj.lower()):
			print("PYTHON AddObject >> found match to: "+obj)
			dynamicList.add(obj)

# Receives message data from MQTT callback function.
# Scans and removes matches from dynamicList.
def RemObject(data):
	global dynamicList, objectList
	msg = data.payload.decode().lower()
	for obj in dynamicList:
		if (msg == obj.lower()):
			print("PYTHON RemObject >> found match to: "+obj)
			dynamicList.remove(obj)

# Redirect from MQTT callback function.
# Error checking.
def defaultFunction(whatever):
	print("PYTHON >> Discarding. No filter for topic "+str(whatever.topic)+" discovered.")

# Redirect from MQTT callback function when no action is required.
def dontdonothing():
	lennon=1j
	nothingtoseehere=trueExp(lennon*pie)
	print(nothingtoseehere)

# Dictionary used to store function() locations.
# MQTT topics are the keys, and they're associated to the 
# respective function location to be executed for that topic.
topic_outsourcing={
	'OptiTrack/Control/AddObject':AddObject,
	'OptiTrack/Control/RemObject':RemObject,
	'OptiTrack/Control/Names':dontdonothing,
	'default':defaultFunction
}
# Callback for MQTT subscriptions.
# Called as Interrupt by paho-mqtt when a subscribed topic is received.
# 
def mqttML_CALLBACK(client,userdata,message):
	################# EXAMPLE START ##################
	# print(message.payload.decode())
	# print(message.topic)
	# msg=message.payload.decode().lower()
	# if (msg.topic == 'OptiTrack/Control/AddObject'):
		# AddObject(message)
	################# EXAMPLE END ####################
	
	# Get the function associated to the MQTT topic.
	# load the defaultFunction if an associated topic is not found.
	topicFunction=topic_outsourcing.get(message.topic,defaultFunction)
	
	# Execute the function associated to the MQTT topic, 
	# passing the MQTT message.
	topicFunction(message)


############################################################
####################### PUBLISHER ##########################
############################################################

	
# Called from Matlab.
# Accepts 1 RigidBody struct at a time, passed in as a python dict.
# Publishes the objects that match dynamicList from the RigidBody struct.
def mqttML_pubDynamic(data):
	msg={}
	mqttConnect()
	
	# Construct the topic from the RigidBody's Name.
	ObjName = "PYTHONERROR_RigidBody_corrupted"
	ObjName = data.get('Name')
	dynamictopic='OptiTrack/'+ObjName+'/Dynamic'
	
	# Populate msg with the objects in dynamicList
	for obj in dynamicList:
		msg[obj]=data[obj]
	
	# Publish json-ified msg to MQTT broker.
	client.publish(dynamictopic,dumps(msg))
	# print('published msg: '+dumps(msg) + ' on topic: '+dynamictopic)


############################################################
###################### DEBUGGING ###########################
############################################################

# Topics for Debugger to subscribe to.
# Global so user can edit list w/o reloading script.
debugTopics = ['OptiTrack/Control/#','test']

# Passthrough for debugging in Python environment.
def debugSubscription():
	global client, buffer

	# Create a global dummy buffer to simulate a RigidBody object from Matlab.
	buffer = {'Name': 'vroom', 'FrameIndex': 33386087, 'TimeStamp': 531712.59596601, 'FrameLatency': 1.2978, 'isTracked': True, 'Position': [-555.4297566413879, 1133.2718133926392, 580.9705853462219], 'Quaternion': [-0.9823990057235511, 0.03210517614039003, -0.04536310217498993, 0.17833529490184152], 'Rotation': [[0.9322774120833481, -0.35330567107334326, -0.07767837348058937], [0.34748010858269623, 0.9343315498255698, -0.07925988354714225], [0.10058032142786663, 0.04690050946379489, 0.9938228922466537]], 'HgTransform': [[0.9322774120833481, -0.35330567107334326, -0.07767837348058937, -555.4297566413879], [0.34748010858269623, 0.9343315498255698, -0.07925988354714225, 1133.2718133926392], [0.10058032142786663, 0.04690050946379489, 0.9938228922466537, 580.9705853462219], [0, 0, 0, 1]], 'MarkerPosition': [[-534.112811088562, -585.0552916526794, -547.1159219741821], [1073.0293989181519, 1132.2520971298218, 1194.5387125015259], [574.7097134590149, 585.7723355293274, 582.3908448219299]], 'MarkerSize': [12.136011384427547, 15.373353846371174, 11.472992599010468]}

	# client.on_message=MESSAGE_CALLBACK
	mqttConnect()
	# Setup MQTT connection
	client.on_message=mqttML_CALLBACK

	# Subscribe to topics
	for topic in debugTopics:
		client.subscribe(topic)
		print("Subscribed to: " + topic)

# Sample. Not used. Available to reroute Debugging Subscriber here.
def MESSAGE_CALLBACK(client,userdata,message):
	print()
	print("mqtt rx:")
	print(message.topic)
	print(message.qos)
	print(message.payload)
	print(message.payload.decode())
	print(message.retain)
	print(client)

# If this script is being called directly, it's gonna need 
# its own MQTT subscription service.
if __name__ == "__main__":
	debugSubscription()


