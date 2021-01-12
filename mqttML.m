classdef mqttML < matlab.mixin.SetGet % Handle
    properties(GetAccess='public', SetAccess='private')
        opti                % OptiTrack object
		modeNAT				% unicast vs multicast for use with OptiTrack
        localIP             % Client IP address
        defaultserver       % The default settings for Motive and MQTT server connections
        mqtt                % MQTT client object
        mqtt_server         % MQTT server
        mqtt_connected      % MQTT connection status
        MESSAGE_CALLBACK    % MQTT callback function
    end % end properties
    
    properties(GetAccess='public', SetAccess='public')
        RigidBodySettings   % User specified rigid body settings
    end % end properties
    
    % --------------------------------------------------------------------
    % Constructor/Destructor
    % --------------------------------------------------------------------
    methods(Access='public')
        function obj = mqttML(varargin)
            % Create OptiTrack object.
			obj.getIP()
            obj.defaultserver='10.60.69.244';	% OptiTrack server in Hopper208, Jan 4 2021
            autostart=0;
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
                obj.startOptiTrack(obj.localIP,obj.modeNAT)
            end
            mqttClass = py.importlib.import_module('paho.mqtt.client');
            obj.mqtt = mqttClass.Client(obj.localIP);
            obj.mqtt_connected=0;
            obj.mqtt_server=0;
            obj.importPython();
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
                    fprintf("Added mqttML directory to py.sys.path\r\n")
                end
            end
            %py.print(pathexists)
            % Now that we know the toolbox directory is in the
            % Python default path list, we can import subCallback.py
            Pythoncallback=py.importlib.import_module('subCallback');
            
            % Assign MQTT subscription interrupt to subCallback.py
            obj.MESSAGE_CALLBACK=Pythoncallback.MESSAGE_CALLBACK;
        end

		function uninitMQTT(obj)
			fprintf('Uninitializing MQTT object...');
			obj.mqtt.loop_stop();
			obj.mqtt.disconnect();
			fprintf('[COMPLETE]\n');
		end
		
		function uninitOpti(obj)
			fprintf('Uninitialize OptiTrack object...');
			obj.opti.delete();
			obj.opti=[];
			fprintf('[COMPLETE]\n');
		end
        
        function delete(obj)
            % delete function destructor
			uninitMQTT()
			if (obj.opti)
				uninitOpti();
            end
        end
		
		
    end % end methods
    
    % --------------------------------------------------------------------
    % Initialization
    % --------------------------------------------------------------------
    methods(Access='public')
        % Initialize(hostIP,cType)
        function startOptiTrack(obj,varargin)
            % Initialize initializes an OptiTrack client assuming the
            % NatNet server is set to local loop-back (127.0.0.1) and there
            % is a multicast connection.
            %
            % Note this is the case if the current instance of MATLAB and
            % Motive/Arena are running on the same machine.
            %
            % Initialize(obj,IP) initializes an OptiTrack client for a
            % designated Host IP address with a multicast connection.
            %
            % Initialize(obj,IP,ConnectionType) initializes an OptiTrack
            % client for a designated Host IP address, and a specified
            % connection type {'Multicast', 'Unicast'}.
            
            % Check inputs
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
                % Define connection type
                switch lower(varargin{2})
                    case 'multicast'
                        mode = lower(varargin{2});
                    case 'unicast'
                        mode = lower(varargin{2});
                    otherwise
                        error('OptiTrack:Init:BadConnectionType',...
                            'Connection property "%s" not recognized.',varargin{2});
                end
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
        
        % Saves the entire RigidBody data to a file.
        % arg1: Sample rate in Hz
        % arg2=infinity, # of Samples to send.
        function SampletoJSONfile(obj,varargin)
            samplefile = fopen('C:/Python/rigidbody.txt','w');
            sleeptime=1/varargin{1};
            if (nargin>2)
                samples=varargin{2};
                for i=0:1:samples
                    fprintf(samplefile,jsonencode(obj.opti.RigidBody))
                    pause(sleeptime);
                end
            else
                while (true)
                    fprintf(samplefile,jsonencode(obj.opti.RigidBody))
                    pause(sleeptime);
                end
            end
        end

        % publish(frequency=50Hz, n samples=infinity, server=127.0.0.1)
        % Publishes the entire RigidBody data as a JSON message.
        % arg1: Sample rate in Hz
        % arg2=infinity, # of Samples to send.
        function publish(obj,varargin)
            %clientname=obj.localIP
			%mqtt = py.paho.mqtt.client.Client(clientname)
            %mqtt.reinitialise(clientname)
            if (nargin>3)
                server=varargin{3};
            else
                if (obj.mqtt_server)
                    server=obj.mqtt_server;
                else
                    server=obj.defaultserver;
                end
            end
            obj.serverConnect(server);
            sleeptime=1/varargin{1};
            nsamples=0;
            if (nargin>2)
                nsamples=varargin{2};
            end
            if (nsamples)
                for i=0:1:nsamples
                    obj.mqtt.publish('RigidBody',jsonencode(obj.opti.RigidBody));
                    pause(sleeptime);
                end
            else
                while (true)
                    obj.mqtt.publish('RigidBody',jsonencode(obj.opti.RigidBody));
                    pause(sleeptime);
                end
            end
        end
        
        % subscribe(topic='test',server=obj.defaultserver)
        function subscribe(obj,varargin)
            if nargin>1
                topic = varargin{1};
            else
                topic = 'test';
            end
            if nargin>2
                server=varargin{2};
            else
                if (obj.mqtt_server)
                    server=obj.mqtt_server;
                else
                    server=obj.defaultserver;
                end
            end
            obj.mqtt.on_message=obj.MESSAGE_CALLBACK;
            obj.serverConnect(server);
            obj.mqtt.subscribe(topic);
            obj.mqtt.loop_start();
            fprintf("subscribed to "+topic+" on "+server+".\r\n");
        end
		        function stopMQTT(obj)
            obj.mqtt.reinitialise(obj.localIP);
            obj.mqtt_connected=0;
            obj.mqtt_server=0;
            obj.mqtt.on_message=0;
        end
        function serverConnect(obj,varargin)
            % Only update server if one isn't already loaded.
            server=varargin{1};
            if (~obj.mqtt_server)
                 obj.mqtt_server=server;
            end
            % Only (re)connect if not already connected.
            if (~obj.mqtt_connected)
                obj.mqtt.connect(obj.mqtt_server);
                obj.mqtt_connected=1;
            end
        end
        function getIP(obj)
            [~,IP] = system('ipconfig | findstr "IPv4 Address" | findstr "10."')
            obj.localIP=IP((strfind(IP,'10.')):(length(IP)-1))
        end

	end %end methods
    
end % end classdef

