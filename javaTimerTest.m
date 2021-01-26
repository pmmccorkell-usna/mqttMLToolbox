% javaTimerTest(frequency, duration)
function javaTimerTest(varargin)
    publisher=mqttML('auto');
    freq=100; % Hz
    if nargin>0
        freq=varargin{1}; % Hz
    end
    period = 1000/freq % ms
    
    duration = 10 * 1000; % ms
    if nargin>1
        duration = varargin{2}*1000;
    end
    samples=duration/period
    
    tic;
    for i=1:samples
        java.lang.Thread.sleep(period);
       % publisher.publishRigidBody;
        publisher.publishPosQua;
    end
    time=toc
    effectiveFreq=samples/time
end

