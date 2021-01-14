function test()
    pub = mqttML('auto')
    buffer = pub.opti.RigidBody(1)
    mystr = num2str(buffer.Quaternion)
    mydict = py.dict(pyargs('Quaternion',jsonencode(buffer.Quaternion)))
    myjson = jsonencode(buffer)
    objlist = fieldnames(buffer)
    quajson=jsonencode(buffer.Quaternion)
    thefinalcountdown = py.json.loads(jsonencode(buffer))
    class(thefinalcountdown)
end

