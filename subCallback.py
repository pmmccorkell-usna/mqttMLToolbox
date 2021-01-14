import paho.mqtt.client as MQTT
from random import randint
from json import dumps as jsonencode

is_connected=0

dynamicList = []

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
	global client
	# serverIP = '127.0.0.1'
	serverIP = '10.60.69.244'
	clientname="MLpyDynamic"+str(randint(1000,9999))
	client=MQTT.Client(clientname)
	client.connect(serverIP)
	client.loop_start()
	is_connected=1
	print("Connected publisher to "+serverIP)
	

def mqttML_pubDynamic(data):
	print(data)
	msg={}
	connectPublisher()
	for obj in dynamicList:
		topic='OptiTrack/'+data['Name']+'/Dynamic'
		print("topic: "+str(topic))
		msg[obj]=data[obj]
		print("msg: "+str(msg))
		print(jsonencode(msg))
		client.publish(topic,jsonencode(msg))

def AddObject(message):
	msg = message.payload.decode().lower()
	setlist = set(dynamicList)
	global dynamicList, objectList
	for obj in objectList:
		if (msg == obj.lower()):
			print("found match to: "+obj)
			setlist.add(obj)
			dynamicList = list(setlist)

def defaultFunction(whatever):
	print("Discarding. No filter for topic "+str(whatever.topic)+" discovered.")

def mqttML_CALLBACK(client,userdata,message):
	#msg=message.payload.decode().lower()
	#print(msg)
	#if msg.topic == 'OptiTrack/Control/AddObject'
	topic_outsourcing={
		'OptiTrack/Control/AddObject':AddObject,
		'default':defaultFunction
	}
	topic_outsourcing.get(message.topic,default)(message)


debugServerIP = '127.0.0.1'
# debugServerIP = '10.60.69.244'
debugFunction = mqttML_CALLBACK
debugTopics = ['OptiTrack/#','test']
def debugSubscription():
	clientname='debugPython'
	client=MQTT.Client(clientname)
	client.connect(debugServerIP)
	client.on_message=debugFunction
	for topic in debutTopics:
		client.subscribe(debugTopic)
		print("Subscribed to: " + topic)
	client.loop_start()
	is_connected=1
	print("Connected debug subscriber to "+debugServerIP)


def MESSAGE_CALLBACK(client,userdata,message):
	print()
	print("mqtt rx:")
	print(message.topic)
	print(message.qos)
	print(message.payload)
	print(message.payload.decode())
	print(message.retain)
	print(client)
