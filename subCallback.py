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


def mqttML_CALLBACK(client,userdata,message):
	global dynamicList, objectList
	setlist = set(dynamicList)
	msg=message.payload.decode().lower()
	print(msg)
	for obj in objectList:
		if (msg == obj.lower()):
			print("found match to: "+obj)
			setlist.add(obj)
			dynamicList = list(setlist)


debugServerIP = '127.0.0.1'
# debugServerIP = '10.60.69.244'
debugFunction = mqttML_CALLBACK
debugTopics = ['OptiTrack/#','test']
def debugSubscription():
	import paho.mqtt.client as MQTT
	clientname='debugPython'
	client=MQTT.Client(clientname)
	client.connect(debugServerIP)
	client.on_message=debugFunction
	for topic in debutTopics:
		client.subscribe(debugTopic)
		print("Subscribed to: " + topic)
	client.loop_start()
	print("Connected to "+debugServerIP)


def MESSAGE_CALLBACK(client,userdata,message):
	print()
	print("mqtt rx:")
	print(message.topic)
	print(message.qos)
	print(message.payload)
	print(message.payload.decode())
	print(message.retain)
	print(client)
