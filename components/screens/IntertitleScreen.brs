sub init()
    m.label = m.top.FindNode("intertitleLabel")
    m.fadeIn = m.top.FindNode("fadeIn")
    m.fadeOut = m.top.FindNode("fadeOut")
    m.holdTimer = m.top.FindNode("holdTimer")
    m.exitTimer = m.top.FindNode("exitTimer")
    m.completed = false

    m.holdTimer.ObserveField("fire", "onHoldTimerFired")
    m.exitTimer.ObserveField("fire", "onExitTimerFired")
end sub

sub onControlChanged()
    if m.top.control <> "start" or m.completed then return

    m.label.text = m.top.text
    m.label.opacity = 0.0
    m.fadeIn.control = "stop"
    m.fadeIn.control = "start"

    seconds = m.top.holdMs / 1000.0
    if seconds < 0.4 then seconds = 0.4
    m.holdTimer.duration = 0.75 + seconds
    m.holdTimer.control = "stop"
    m.holdTimer.control = "start"
end sub

sub onHoldTimerFired()
    if m.completed then return
    m.fadeOut.control = "stop"
    m.fadeOut.control = "start"
    m.exitTimer.control = "stop"
    m.exitTimer.control = "start"
end sub

sub onExitTimerFired()
    CompleteIntertitle("complete")
end sub

sub CompleteIntertitle(eventType as String)
    if m.completed then return
    m.completed = true
    m.fadeIn.control = "stop"
    m.fadeOut.control = "stop"
    m.holdTimer.control = "stop"
    m.exitTimer.control = "stop"
    EmitNavEvent(m.top, eventType, invalid)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        CompleteIntertitle("cancel")
        return true
    end if
    if key = "OK" or key = "play"
        CompleteIntertitle("complete")
        return true
    end if

    return false
end function
