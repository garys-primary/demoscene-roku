sub init()
    m.video = m.top.FindNode("video")
    m.nowLabel = m.top.FindNode("nowLabel")
    m.statusLabel = m.top.FindNode("statusLabel")
    m.nextLabel = m.top.FindNode("nextLabel")
    m.video.ObserveField("state", "onVideoStateChanged")
    m.video.ObserveField("position", "onVideoProgress")
    m.lastProgressSecond = -1
    m.video.enableUI = false
    m.departed = false
    m.sawPlayback = false
    m.failed = false

    m.chrome = m.top.findNode("chromeGroup")
    m.chrome.opacity = 0
    m.chromeAppears = m.top.FindNode("chromeAppears")
    m.chromeDisappears = m.top.FindNode("chromeDisappears")
    m.chromeHidden = true
end sub

sub onControlChanged()
    if m.top.control <> "start" or m.departed then return
    StartPlayback()
end sub

sub StartPlayback()
    exhibit = ExhibitAt(m.top.catalog, m.top.exhibitIndex)
    if exhibit = invalid
        m.nowLabel.text = "WORK UNAVAILABLE"
        m.statusLabel.text = "BACK TO RETURN"
        m.nextLabel.text = "FINISH"
        return
    end if

    m.nowLabel.text = Pad2(exhibit.number) + "   " + exhibit.title
    if HasNextExhibit(m.top.catalog, m.top.exhibitIndex)
        m.nextLabel.text = "NEXT EXHIBIT"
    else
        m.nextLabel.text = "FINISH"
    end if

    url = PreferredHlsUrl(exhibit)
    if url = ""
        m.statusLabel.text = "NO STREAM   •   BACK TO RETURN"
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamformat = "hls"
    content.title = exhibit.title
    print "Player open "; url
    m.statusLabel.text = "LOADING"
    ' ==== TEST ====
    print "Player progress log enabled"
    m.video.content = content
    m.video.control = "play"
end sub

sub onVideoProgress()
    if m.departed then return
    second = Int(m.video.position)
    if second = m.lastProgressSecond then return
    m.lastProgressSecond = second
    duration = 0
    if m.video.duration <> invalid then duration = Int(m.video.duration)
    print "Player progress "; second.ToStr(); "s / "; duration.ToStr(); "s state="; m.video.state
end sub

sub onVideoStateChanged()
    if m.departed then return

    state = m.video.state
    print "Player state "; state
    if state = "playing"
        m.sawPlayback = true
        m.statusLabel.text = "OK  NEXT EXHIBIT    •    PLAY  PAUSE    •    BACK  DETAILS"
    else if state = "buffering"
        m.statusLabel.text = "BUFFERING"
    else if state = "paused"
        m.statusLabel.text = "PAUSED"
    else if state = "finished"
        if m.sawPlayback
            GoToNext()
        else
            print "Player finished before playback"
            MarkPlaybackFailed("STREAM UNAVAILABLE")
        end if
    else if state = "error"
        detail = ""
        if m.video.errorCode <> invalid then detail = m.video.errorCode.ToStr()
        message = ""
        if m.video.errorMsg <> invalid then message = m.video.errorMsg
        print "Player error "; detail; " "; message
        MarkPlaybackFailed("STREAM UNAVAILABLE")
    end if
end sub

sub MarkPlaybackFailed(message as String)
    m.failed = true
    m.statusLabel.text = message + "    •    BACK RETURNS"
end sub

sub GoToNext()
    if m.departed then return
    m.departed = true
    m.video.control = "stop"
    if HasNextExhibit(m.top.catalog, m.top.exhibitIndex)
        EmitNavEvent(m.top, "advance", {
            exhibitIndex: m.top.exhibitIndex + 1
            origin: m.top.origin
            autoplay: true
        })
    else
        EmitNavEvent(m.top, EndEventFor(m.top.origin), invalid)
    end if
end sub

sub BackToInfo()
    if m.departed then return
    m.departed = true
    m.video.control = "stop"
    EmitNavEvent(m.top, "backToInfo", {
        exhibitIndex: m.top.exhibitIndex
        origin: m.top.origin
        autoplay: false
    })
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or m.departed then return false

    if m.chromeHidden
        if key = "OK" or key = "up" or key = "down" or key = "left" or key = "right"
            m.chromeDisappears.control = "stop"
            m.chromeAppears.control = "start"
            m.chromeHidden = false
            return true
        end if
    else

        if key = "OK"
            if m.sawPlayback then GoToNext()
            return true
        end if
        if key = "back"
            BackToInfo()
            return true
        end if
        if key = "play"
            if m.video.state = "playing"
                m.video.control = "pause"
                m.statusLabel.text = "PAUSED"
            else if m.video.state = "paused"
                m.video.control = "resume"
            end if
            return true
        end if
        if key = "down"
            m.chromeAppears.control = "stop"
            m.chromeDisappears.control = "start"
            m.chromeHidden = true
            return true
        end if
    end if

    return false
end function
