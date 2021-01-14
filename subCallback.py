import paho.mqtt.client as MQTT
from random import randint
from json import dumps as jsonencode
from datetime import datetime
from math import pi as pie
from cmath import exp as trueExp

# serverIP = '127.0.0.1'
serverIP = '10.60.69.244'
clientname="MLpyDynamic"+str(randint(1000,9999))
client=MQTT.Client(clientname)


is_connected=0

dynamicList = []

# now=str(datetime.now())
# print('loaded '+now)

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

def connectPublisher():
	global client, is_connected
	if not is_connected:
		client.connect(serverIP)
		client.loop_start()
		print("Connected publisher to "+serverIP)
	else:
		print("Already connected")
	is_connected=1
	
	
def mqttML_pubDynamic(data):
	# print("enter Python")
	# print(data)
	msg={}
	connectPublisher()
	topic='OptiTrack/'+data.get('Name','PYTHON_TOPIC_ERROR')+'/Dynamic'
	for obj in dynamicList:
		# print("topic: "+str(topic))
		msg[obj]=data[obj]
		# print("msg: "+str(msg))
		# print(jsonencode(msg))
	client.publish(topic,jsonencode(msg))

def AddObject(data):
	global dynamicList, objectList
	# print("AddObject function")
	msg = data.payload.decode().lower()
	setlist = set(dynamicList)
	for obj in objectList:
		if (msg == obj.lower()):
			print("PYTHON AddObject >> found match to: "+obj)
			setlist.add(obj)
			dynamicList = list(setlist)

def defaultFunction(whatever):
	print("PYTHON >> Discarding. No filter for topic "+str(whatever.topic)+" discovered.")

def dontdonothing():
	lennon=1j
	return trueExp(lennon*pie)

topic_outsourcing={
	'OptiTrack/Control/AddObject':AddObject,
	'OptiTrack/Control/Names':dontdonothing,
	'default':defaultFunction
}
def mqttML_CALLBACK(client,userdata,message):
	################# EXAMPLE START ##################
	# print(message.payload.decode())
	# print(message.topic)
	# msg=message.payload.decode().lower()
	# if (msg.topic == 'OptiTrack/Control/AddObject'):
		# AddObject(message)
	################# EXAMPLE END ####################
	
#	topic=message.topic
#	if (topic=='OptiTrack/Control/AddObject'):
#		AddObject(message)
	topicFunction=topic_outsourcing.get(message.topic,defaultFunction)
	# print(topicFunction)
	topicFunction(message)
	# print("executed")

def debugSubscription():
	global client, is_connected, buffer
########## DEBUG SETTINGS ###########
	# debugServerIP = '127.0.0.1'
	debugServerIP = '10.60.69.244'
	debugFunction = mqttML_CALLBACK
	debugTopics = ['OptiTrack/Control/#','test']
########## DEBUG SETTINGS ###########
	
	buffer = {'Name': 'vroom', 'FrameIndex': 33386087, 'TimeStamp': 531712.59596601, 'FrameLatency': 1.2978, 'isTracked': True, 'Position': [-555.4297566413879, 1133.2718133926392, 580.9705853462219], 'Quaternion': [-0.9823990057235511, 0.03210517614039003, -0.04536310217498993, 0.17833529490184152], 'Rotation': [[0.9322774120833481, -0.35330567107334326, -0.07767837348058937], [0.34748010858269623, 0.9343315498255698, -0.07925988354714225], [0.10058032142786663, 0.04690050946379489, 0.9938228922466537]], 'HgTransform': [[0.9322774120833481, -0.35330567107334326, -0.07767837348058937, -555.4297566413879], [0.34748010858269623, 0.9343315498255698, -0.07925988354714225, 1133.2718133926392], [0.10058032142786663, 0.04690050946379489, 0.9938228922466537, 580.9705853462219], [0, 0, 0, 1]], 'MarkerPosition': [[-534.112811088562, -585.0552916526794, -547.1159219741821], [1073.0293989181519, 1132.2520971298218, 1194.5387125015259], [574.7097134590149, 585.7723355293274, 582.3908448219299]], 'MarkerSize': [12.136011384427547, 15.373353846371174, 11.472992599010468]}
	
	client.connect(debugServerIP)
	client.on_message=mqttML_CALLBACK
	for topic in debugTopics:
		client.subscribe(topic)
		print("Subscribed to: " + topic)
	client.loop_start()
	is_connected=1
	print("Connected debug subscriber to "+debugServerIP)

def mqttTerminate():
	global client, is_connected
	client.loop_stop()
	client.disconnect()
	is_connected=0
	print("Terminated python MQTT")

def MESSAGE_CALLBACK(client,userdata,message):
	print()
	print("mqtt rx:")
	print(message.topic)
	print(message.qos)
	print(message.payload)
	print(message.payload.decode())
	print(message.retain)
	print(client)

if __name__ == "__main__":
	debugSubscription()
	
	