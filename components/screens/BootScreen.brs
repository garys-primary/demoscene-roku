sub init()
    'm.spin = m.top.FindNode("spin")
    m.bootTimer = m.top.FindNode("bootTimer")
    m.bootTimer.ObserveField("fire", "onBootTimerFired")
    print("[init] STARTING")

    drawLogo()
    
    m.frame = 0
    m.frameTimer = m.top.findNode("frameTimer")
    m.frameTimer.ObserveField("fire", "onFrame")
end sub

sub onControlChanged()
    if m.top.control <> "start" then return
    m.bootTimer.control = "start"
    m.frameTimer.control = "start"
end sub

sub onBootTimerFired()
    print("[splash] splash timeout")

    m.frameTimer.control = "stop"
    EmitNavEvent(m.top, "complete", invalid)
    print("[splash] Cleared stuff")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        EmitNavEvent(m.top, "cancel", invalid)
        return true
    end if
    if key = "OK" or key = "play"
        EmitNavEvent(m.top, "complete", invalid)
        return true
    end if

    return false
end function

sub drawLogo()
    numSlices = 36

    rem sceneGraph and animation nodes
    m.logo = m.top.findNode("logo")
    m.logoAnim = m.top.findNode("logoAnimations")

    m.stripVelocities = []
    m.stripDelays = []
    m.stripsCrossed = []

    for i = 0 to numSlices - 1
        rem create scene graph item
        strip = CreateObject("roSGNode", "Poster")
        
        index = i.toStr()
        while index.Len() < 2
            index = "0" + index
        end while
        strip.uri = "pkg:/content/splash/strip_" + index + ".png"
        strip.opacity = 0.9
        'strip.id = "strip_"+index

        strip.translation = [i*8, -150]
        m.stripVelocities.push(0.0)
        m.stripDelays.push(i)
        m.stripsCrossed.push(false)

        m.logo.appendChild(strip)

    end for

    m.logo.scale = [1.5, 6.0]
    
    print("[splash] logo drawn")

end sub

sub onFrame()
    strips = m.top.findNode("logo")
    m.frame++

    'if m.frame < 10 return

    numSlices = strips.getChildCount()
    attractor = -10

    for i=0 to numSlices - 1
        if m.stripDelays[i] > m.frame return

        slice = strips.GetChild(i)
        
        velocity = m.stripVelocities[i]
        currY = slice.translation[1]
        
        accel = (attractor - currY) / 100
        'delta = attractor - currY
        'if delta >= 0
        '    accel = (delta * delta) / 7000.0
        'else
        '    accel = -(delta * delta) / 7000.0
        'end if
        
        if  currY > attractor AND NOT m.stripsCrossed[i]
            velocity /= 20
            velocity += accel
        else
            velocity += accel
        end if

        if currY > attractor m.stripsCrossed[i] = true

        currY += velocity
        velocity *= 0.98

        'slice.translation[1] = currY + velocity
        slice.translation = [slice.translation[0], currY] 

        m.stripVelocities[i] = velocity

    end for

end sub
