classdef mqttML < matlab.mixin.SetGet % Handle
    properties(GetAccess='public', SetAccess='public')
        opti                % OptiTrack object
		modeNAT				% unicast vs multicast for use with OptiTrack
        localIP             % Client IP address
        defaultserver       % The default settings for Motive and MQTT server connections
        mqtt                % MQTT client object
        mqtt_server         % MQTT server
        mqtt_connected      % MQTT connection status
        Pythoncallback      % object of python script with function
        MESSAGE_CALLBACK    % MQTT callback function
    end % end properties
        
    % --------------------------------------------------------------------
    % Constructor/Destructor
    % --------------------------------------------------------------------
    methods(Access='public')
        function obj = mqttML(varargin)
            % Create OptiTrack object.
			obj.getIP();
            obj.defaultserver='10.60.69.244';	% OptiTrack server in Hopper208, Jan 4 2021
            obj.initMQTT();
            autostart=0;
            obj.importPython();
            if nargin >= 1
                switch lower(varargin{1})
                    case 'multicast'
                        obj.modeNAT = lower(varargin{1});
                    case 'unicast'
                        obj.modeNAT = lower(varargin{1});
                    case 'auto'
                        autostart=1;
                        obj.modeNAT = 'unicast';
                    otherwise
                       error('mqttML:Init:BadConnectionType',...
                            'Connection property "%s" not recognized.',varargin{1});
                end
            else
                obj.modeNAT = 'unicast';
            end
            if (autostart)
                obj.initOptiTrack();
                obj.subscribe('OptiTrack/Control/#')
            end
        end
        
        function reloadPython(obj)
            obj.Pythoncallback.mqttTerminate()
            obj.Pythoncallback=py.importlib.reload(obj.Pythoncallback);
        end
        
        function importPython(obj)
            % Get directory of the OptiTrack toolbox.
            [installPath, ~] = fileparts(which('mqttML'));

            % Create placeholder of system path for Python in Matlab
            % Changes to this placeholder are dynamically and automatically
            % applied to the original py.sys.path
            pathlist = py.sys.path;

            % See if the toolbox directory is already in the
            % Python default path list. Add the directory if it is not.
            pathexists=0;
            try
                % .index method returns an integer if the string is found.
                % If not found, in MatLab it throws a Python Exception.
                % Behavior is not different outside Matlab.
                pathexists=pathlist.index(installPath);
            catch ME
                %fprintf(ME.identifier+"\r\n")
                % If the exception is Python, assume it's because the
                % directory string was not found in the list.
                % And add it to the list.
                if (ME.identifier == 'MATLAB:Python:PyException')
                    pathlist.append(installPath);
                    fprintf("Added mqttML directory to py.sys.path\r\n");
                end
            end
            %py.print(pathexists)
            % Now that we know the toolbox directory is in the
            % Python default path list, we can import subCallback.py
            obj.Pythoncallback=py.importlib.import_module('subCallback');
            
            % Assign MQTT subscription interrupt to subCallback.py
            obj.MESSAGE_CALLBACK=obj.Pythoncallback.mqttML_CALLBACK;
            %obj.MESSAGE_CALLBACK=obj.callback
        end
        
        function callback(obj,client,userdata,message)
            fprintf(message);
        end
        
        function initMQTT(obj)
            mqttClass = py.importlib.import_module('paho.mqtt.client');
            obj.mqtt = mqttClass.Client(obj.localIP+"/"+string(randi(1000)));
            obj.mqtt_connected=0;
            obj.mqtt_server=0;
        end

		function uninitMQTT(obj)
			fprintf('Uninitializing MQTT object...');
            if (obj.mqtt_connected)
                obj.mqtt.loop_stop();
                obj.mqtt.disconnect();
            end
            obj.mqtt=[];
			fprintf('[COMPLETE]\n');
		end
		
		function uninitOpti(obj)
			obj.opti.delete();
			obj.opti=[];
		end
        
        function delete(obj)
            % delete function destructor
			obj.uninitMQTT();
            optiInstantiated = class(obj.opti);
            if (optiInstantiated == "OptiTrack")
                obj.uninitOpti();
            end
        end
		
		
    end % end methods
    
    % --------------------------------------------------------------------
    % Initialization
    % --------------------------------------------------------------------
    methods(Access='public')
        % Initialize(hostIP,mode)
        function initOptiTrack(obj,varargin)
            % narginchk(1,3);
            mode = obj.modeNAT;  % Set default cType to the object property
            clientIP=obj.localIP;
            if nargin > 1
                % Designated host IP
                hostIP = varargin{1};
            else
                % hostIP = '127.0.0.1';		% Local loop-back
				% hostIP = '10.60.69.244';	% OptiTrack server in Hopper208, Jan 4 2021
                hostIP = obj.defaultserver;
            end
            if nargin > 2
                mode = lower(varargin{2});
            end
           
            % Check IP
            % TODO - check for valid IP address
            if ~ischar(hostIP)
                error('OptiTrack:Init:BadIP',...
                    'The host IP must be specified as a character/string input (e.g. ''192.168.1.1'').');
            end
            if ~ischar(clientIP)
                error('OptiTrack:Init:BadIP',...
                    'The client IP must be specified as a character/string input (e.g. ''192.168.1.1'').');
            end

			obj.opti=OptiTrack;
			obj.opti.Initialize(hostIP,mode);
        end

        function timerSampleJSON(obj,nExecution)
            % nExecution=varargin{1}
            filename = sprintf('C:/Python/rigidbody %s.txt',(datestr(now,'yyyymmdd-HHMM.SS.FFF')))
            samplefile = fopen(filename,'w');
            interrupt = timer('ExecutionMode','fixedRate','TimerFcn',@(src,evt)obj.SampleJSONfile(samplefile),'Period',.001,'TasksToExecute',nExecution,'UserData',samplefile);
            % Starts a stopwatch when timer Starts.
            interrupt.StartFcn='tic';
            % Stops the stopwatch when timer Stops.
            interrupt.StopFcn=@(src,evt)obj.printtoc(nExecution,samplefile)
            interrupt.start
            %fprintf(samplefile,"\r\n%d samples",nExecution)
            fclose(samplefile);
            interrupt.delete
        end
        
        % Appends the output of the stopwatch to the end of the logfile.
        function printtoc(obj,nsample,thefile)
            fprintf(thefile,"\r\n%d samples in %f seconds",nsample,toc);
        end
        
        function SampleJSONfile(obj,thefile)
            % thefile = varargin{1};
            len = numel(obj.opti.RigidBody);
            for i=1:len
                fprintf(thefile,jsonencode(obj.opti.RigidBody(i)));
                fprintf(thefile,'\r');
            end
        end
        
        % Saves the entire RigidBody data to a file.
        % arg1: Sample rate in Hz
        % arg2=infinity, # of Samples to send.
        function SampleJSONfileloop(obj,varargin)
            filename = sprintf('C:/Python/rigidbody %s.txt',(datestr(now,'yyyymmdd-HHMM.SS.FFF')))
            samplefile = fopen(filename,'w');
            if (nargin>1)
                sleeptime=1/varargin{1};
            else
                sleeptime=0;
            end
            if (nargin>2)
                samples=varargin{2};
                for i=0:1:samples
                    len = numel(obj.opti.RigidBody);
                    for i=1:len
                        fprintf(samplefile,jsonencode(obj.opti.RigidBody(i)));
                        fprintf('\r');
                    end
                    pause(sleeptime);
                end
            else
                while (true)
                    len = numel(obj.opti.RigidBody);
                    for i=1:len
                        fprintf(samplefile,jsonencode(obj.opti.RigidBody(i)));
                        fprintf(samplefile,'\r');
                    end
                    pause(sleeptime);
                end
            end
            fclose(filename)
        end

        function publishAll(obj)
            publishRigidBody(obj)
            publishPosQua(obj)
        end

		function publishRigidBody(obj)
			obj.serverConnect('10.60.17.244');
			topicPrefix = "OptiTrack/";
			topicSuffix = "/RigidBody";
            if (class(obj.opti.RigidBody) == "struct")
                message = jsonencode(obj.opti.RigidBody);
    			pub(topicPrefix+obj.opti.RigidBody.Name+topicSuffix,message);
            end
        end
        
        function publishPosQua(obj,varargin)
            % obj.serverConnect('10.60.17.244');
            topicPrefix = "OptiTrack/";
            topicSuffix = "/PosQua";
            if (class(varargin{1}) == "struct")
                length = numel(varargin{1});
                for i=1:length
                    msg.FrameIndex = varargin{1}(i).FrameIndex
                    msg.Position = varargin{1}(i).Position
                    msg.Quaternion = varargin{1}(i).Quaternion
                    topic=topicPrefix+varargin{1}(i).Name+topicSuffix
                    obj.mqtt.publish(topic,jsonencode(msg))
                end
            end
        end
        
        function publishNames(obj,varargin)
            % obj.serverConnect('10.60.17.244');
            topic = "OptiTrack/Control/Names";
            if (class(obj.opti.RigidBody)=="struct")
                length = numel(obj.opti.RigidBody);
                msg = strings(1,length);
                for i=1:length
                    msg(i) = obj.opti.RigidBody(i).Name;
                end
                obj.mqtt.publish(topic,jsonencode(msg));
            end
        end

        % pubDynamic(stringarray of objects in RigidBody to pull)
        function pubDynamic(obj,varargin)
            % Assign dynamicMatch to the list passed in.
            dynamicMatch = varargin{1};
            
            % Check that MQTT client is connected to broker.
            obj.serverConnect('10.60.17.244');
            
            % load the latest RigidBody data into a buffer
            buffer = obj.opti.RigidBody;
            
            if (class(buffer)=="struct")
                switch(class(dynamicMatch))
                    case 'py.set'
                        fprintf("python type found\r\n");
                        nBodies = numel(buffer);
                        msgNames = strings(1,nBodies);
                        for i=1:nBodies
                            msgNames(i)=buffer(i).Name;
                            pydict = py.json.loads(jsonencode(buffer(i)));
                            class(pydict);
                            obj.Pythoncallback.mqttML_pubDynamic(pydict);
                        end
                        obj.mqtt.publish("OptiTrack/Control/Names",jsonencode(msgNames));
                        
                    case 'string'
                        fprintf("Matlab type found\r\n");
                        % How many Rigid Bodies?
                        % nBodies = numel(buffer);
                        nBodies = numel(buffer);

                        % How many fields in RigidBody are being populated into
                        % MQTT?
                        nFields = numel(dynamicMatch);

                        % Create a string array for the Rigid Body names
                        msgNames = strings(1,nBodies);

                        % Critically, this is the all important step: instantiate
                        % msg as an empty struct and we can fill it with things all
                        % day
                        %msg=struct

                        % Iterate through the Rigid Bodies
                        for i=1:nBodies
                            msg=struct;
                            % Add e/ Rigid Body's name to the string array of Names
                            msgNames(i)=buffer(i).Name;

                            % Iterate through each of the string array fields and
                            % populate the MQTT message.
                            for j=1:nFields
                                msg = setfield(msg,dynamicMatch(j),getfield(buffer,{i},dynamicMatch(j)));
                            end
                            % Publish the Dynamic message for each Rigid Body.
                            obj.mqtt.publish("OptiTrack/"+msgNames(i)+"/Dynamic",jsonencode(msg));
                        end
                        % Publish the Control list of Rigid Body Names.
                        obj.mqtt.publish("OptiTrack/Control/Names",jsonencode(msgNames));

                    otherwise
                        fprintf("Not a valid class/n/r");
                end
            end
        end
        
        function pubStreamlined(obj)
            obj.serverConnect('10.60.17.244');
            buffer = obj.opti.RigidBody;
            if (class(buffer)=="struct")
                length = numel(buffer);
                msgNames = strings(1,length);
                for i=1:length
                    msgNames(i)=buffer(i).Name;
                    msgPosQua.FrameIndex = buffer(i).FrameIndex;
                    msgPosQua.Position = buffer(i).Position;
                    msgPosQua.Quaternion = buffer(i).Quaternion;
                    obj.mqtt.publish("OptiTrack/"+msgNames(i)+"/PosQua",jsonencode(msgPosQua))
                    obj.mqtt.publish("OptiTrack/"+msgNames(i)+"/PosRot",jsonencode(msgPosRot))
                    obj.mqtt.publish("OptiTrack/"+msgNames(i)+"/Mark",jsonencode(msgPosQua))
                    obj.mqtt.publish("OptiTrack/"+msgNames(i)+"/PosQuaMark",jsonencode(msgPosQua))
                    obj.mqtt.publish("OptiTrack/"+msgNames(i)+"/PosRotMark",jsonencode(msgPosQua))
                end
                obj.mqtt.publish("OptiTrack/Control/Names",jsonencode(msgNames))
            end
        end
        
        % subscribe(topic='test',server=obj.defaultserver)
        function subscribe(obj,varargin)
            if nargin>1
                topic = varargin{1};
            else
                topic = 'test';
            end
			
			% If there's an argument for server IP, use it.
			% Else if a mqtt_server is already set, use it.
			% Else use the default server.
            if nargin>2
                server=varargin{2};
            elseif (obj.mqtt_server)
                server=obj.mqtt_server;
            else
                server=obj.defaultserver;
            end
			% Set the callback function() when a message on the topic is received.
			% This is global for all MQTT subscribed Topics.
            obj.mqtt.on_message=obj.MESSAGE_CALLBACK;
			% Connect to MQTT broker.
            obj.serverConnect(server);
			% Subscribe to the MQTT topic on broker.
            obj.mqtt.subscribe(topic);
            fprintf("subscribed to "+topic+" on "+server+".\r\n");
        end
		
		% Stop live MQTT functions.
		function stopMQTT(obj)
            obj.uninitMQTT();
            obj.initMQTT();
            % obj.mqtt.reinitialise(obj.localIP);
            obj.mqtt_connected=0;
            obj.mqtt_server=0;
            obj.mqtt.on_message=0;
            obj.Pythoncallback.mqttTerminate();
        end

		% Connect to MQTT broker
		% serverConnect(server)
        function serverConnect(obj,varargin)
			% Make sure MQTT python class is loaded
			if (class(obj.mqtt) ~= "py.paho.mqtt.client.Client");
                obj.initMQTT();
            end
			
            % Only update server if one isn't already loaded.
            server=varargin{1};
            if (~obj.mqtt_server)
                 obj.mqtt_server=server;
            end
            
			% Only connect if not already connected.
            if (~obj.mqtt_connected)
                obj.mqtt.connect(obj.mqtt_server);
                % Start the MQTT loop looking for new messages on topic.
                obj.mqtt.loop_start();
                obj.mqtt_connected=1;
            end
        end

		% Get Local IP of machine and store as property localIP
		function getIP(obj)
			% Search ipconfig for IPv4 line starting with a "10." IP address.
            [~,IP] = system('ipconfig | findstr "IPv4 Address" | findstr "10."');
			% Parse out the IP address from the rest of the string.
            obj.localIP=IP((strfind(IP,'10.')):(length(IP)-1));
        end

	end %end methods
    
end % end classdef

