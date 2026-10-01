sub init()
    m.video = m.top.FindNode("video")
    m.nowLabel = m.top.FindNode("nowLabel")
    m.statusLabel = m.top.FindNode("statusLabel")
    m.nextLabel = m.top.FindNode("nextLabel")
    m.partButton = m.top.FindNode("partButton")
    m.partFocus = m.top.FindNode("partFocus")
    m.partLabel = m.top.FindNode("partLabel")
    m.exhibitButton = m.top.FindNode("exhibitButton")
    m.nextFocus = m.top.FindNode("nextFocus")
    m.normalChrome = m.top.FindNode("normalChrome")
    m.guideChrome = m.top.FindNode("guideChrome")
    m.guideTitle = m.top.FindNode("guideTitle")
    m.guideText = m.top.FindNode("guideText")
    m.guideHint = m.top.FindNode("guideHint")
    m.guideRestartButton = m.top.FindNode("guideRestartButton")
    m.guideRestartFocus = m.top.FindNode("guideRestartFocus")
    m.guideNextButton = m.top.FindNode("guideNextButton")
    m.guideNextFocus = m.top.FindNode("guideNextFocus")
    m.guideNextLabel = m.top.FindNode("guideNextLabel")
    m.video.ObserveField("state", "onVideoStateChanged")
    m.video.ObserveField("position", "onVideoProgress")
    m.lastProgressSecond = -1
    m.video.enableUI = false
    if m.video.HasField("seekMode") then m.video.seekMode = "accurate"
    if m.video.HasField("autoplayAfterSeek") then m.video.autoplayAfterSeek = true
    m.departed = false
    m.sawPlayback = false
    m.failed = false
    m.parts = []
    m.hasParts = false
    m.currentPartIndex = 0
    m.partAvailable = false
    m.selectedAction = "exhibit"
    m.guideMode = false
    m.guideSelectedAction = "next"
    m.guideSeekPending = false
    m.nextGuideIndex = -1

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
    m.guideMode = (m.top.mode = "guide")
    exhibit = ExhibitAt(m.top.catalog, m.top.exhibitIndex)
    if exhibit = invalid
        m.nowLabel.text = "WORK UNAVAILABLE"
        m.statusLabel.text = "BACK TO RETURN"
        m.nextLabel.text = "FINISH"
        return
    end if

    if m.guideMode
        ConfigureGuide(exhibit)
    else
        m.nowLabel.text = Pad2(exhibit.number) + "   " + exhibit.title
        if HasNextExhibit(m.top.catalog, m.top.exhibitIndex)
            m.nextLabel.text = "NEXT EXHIBIT"
        else
            m.nextLabel.text = "FINISH"
        end if
        ConfigureParts(exhibit)
    end if

    url = PreferredHlsUrl(exhibit)
    if url = ""
        if m.guideMode
            m.guideHint.text = "NO STREAM    •    BACK TO RETURN"
        else
            m.statusLabel.text = "NO STREAM   •   BACK TO RETURN"
        end if
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamformat = "hls"
    if m.guideMode
        content.title = exhibit.title + " - Quick Guide"
    else
        content.title = exhibit.title
    end if
    print "Player open "; url
    m.statusLabel.text = "LOADING"
    ' ==== TEST ====
    print "Player progress log enabled"
    m.video.content = content
    m.video.control = "play"
end sub

sub ConfigureGuide(exhibit as Dynamic)
    if exhibit.guide = invalid
        m.guideHint.text = "GUIDE ENTRY UNAVAILABLE    •    BACK TO RETURN"
        return
    end if

    m.hasParts = false
    m.partButton.visible = false
    m.normalChrome.visible = false
    m.guideChrome.visible = true
    m.guideStart = exhibit.guide.start
    m.guideSeekPending = m.guideStart > 0
    m.nextGuideIndex = NextGuideExhibitIndex(m.top.catalog, m.top.exhibitIndex)
    m.guideSelectedAction = "next"

    m.guideTitle.text = "QUICK GUIDE  •  " + Pad2(exhibit.number) + "  " + exhibit.title
    m.guideText.text = exhibit.guide.text
    m.guideHint.text = "DOWN TO HIDE INFO"
    if m.nextGuideIndex >= 0
        m.guideNextLabel.text = "NEXT EXHIBIT"
    else
        m.guideNextLabel.text = "FINISH GUIDE"
    end if

    m.chrome.opacity = 1.0
    m.chromeHidden = false
    UpdateGuideFocus()
    print "Guide open exhibit "; exhibit.id; " start="; m.guideStart
end sub

sub UpdateGuideFocus()
    if m.guideSelectedAction = "restart"
        m.guideRestartButton.opacity = 1.0
        m.guideRestartFocus.opacity = 0.28
        m.guideNextButton.opacity = 0.75
        m.guideNextFocus.opacity = 0.08
    else
        m.guideRestartButton.opacity = 0.75
        m.guideRestartFocus.opacity = 0.08
        m.guideNextButton.opacity = 1.0
        m.guideNextFocus.opacity = 0.28
    end if
end sub

sub RestartGuideVideo()
    if not m.sawPlayback then return
    print "Guide restart from beginning"
    m.guideSeekPending = false
    m.video.seek = 0
    if m.video.state = "paused" then m.video.control = "resume"
    HideChrome()
end sub

sub HideChrome()
    m.chromeAppears.control = "stop"
    m.chromeDisappears.control = "stop"
    m.chromeDisappears.control = "start"
    m.chromeHidden = true
end sub

sub ShowChrome()
    m.chromeDisappears.control = "stop"
    m.chromeAppears.control = "stop"
    m.chromeAppears.control = "start"
    m.chromeHidden = false
end sub

sub ConfigureParts(exhibit as Dynamic)
    m.parts = []
    if exhibit.parts <> invalid
        for each timestamp in exhibit.parts
            m.parts.Push(timestamp)
        end for
    end if

    m.hasParts = m.parts.Count() > 1
    m.currentPartIndex = 0
    m.partAvailable = m.hasParts
    m.partButton.visible = m.hasParts

    if m.hasParts
        m.exhibitButton.translation = [1430, 948]
        m.nextFocus.width = 400
        m.nextLabel.width = 400
        m.selectedAction = "part"
        print "Player parts loaded "; m.parts.Count()
    else
        m.exhibitButton.translation = [1288, 948]
        m.nextFocus.width = 500
        m.nextLabel.width = 500
        m.selectedAction = "exhibit"
    end if

    UpdateButtonFocus()
end sub

sub UpdatePartState(position as Double)
    if not m.hasParts then return

    while m.currentPartIndex + 1 < m.parts.Count()
        nextStart = m.parts[m.currentPartIndex + 1]
        if position < nextStart then exit while
        m.currentPartIndex++
    end while

    wasAvailable = m.partAvailable
    m.partAvailable = m.currentPartIndex + 1 < m.parts.Count()
    if not m.partAvailable and m.selectedAction = "part"
        m.selectedAction = "exhibit"
    end if

    if wasAvailable <> m.partAvailable
        UpdateButtonFocus()
    end if
end sub

sub UpdateButtonFocus()
    if m.hasParts
        if not m.partAvailable
            m.partButton.opacity = 0.35
            m.partFocus.opacity = 0.04
        else if m.selectedAction = "part"
            m.partButton.opacity = 1.0
            m.partFocus.opacity = 0.28
        else
            m.partButton.opacity = 0.75
            m.partFocus.opacity = 0.08
        end if
    end if

    if m.selectedAction = "exhibit"
        m.exhibitButton.opacity = 1.0
        m.nextFocus.opacity = 0.28
    else
        m.exhibitButton.opacity = 0.75
        m.nextFocus.opacity = 0.08
    end if
end sub

sub GoToNextPart()
    if not m.sawPlayback or not m.partAvailable then return

    m.currentPartIndex++
    target = m.parts[m.currentPartIndex]
    print "Player next part "; (m.currentPartIndex + 1); "/"; m.parts.Count(); " seek="; target
    m.video.seek = target
    if m.video.state = "paused" then m.video.control = "resume"

    m.partAvailable = m.currentPartIndex + 1 < m.parts.Count()
    if not m.partAvailable then m.selectedAction = "exhibit"
    UpdateButtonFocus()
    UpdatePartStatus()
end sub

sub UpdatePartStatus()
    if not m.hasParts or not m.sawPlayback or m.failed then return

    partText = "PART " + (m.currentPartIndex + 1).ToStr() + "/" + m.parts.Count().ToStr()
    if m.video.state = "paused"
        m.statusLabel.text = partText + "    •    PAUSED    •    LEFT/RIGHT SELECT    •    OK CHOOSE"
    else
        m.statusLabel.text = partText + "    •    LEFT/RIGHT SELECT    •    OK CHOOSE    •    PLAY PAUSE"
    end if
end sub

sub onVideoProgress()
    if m.departed then return
    second = Int(m.video.position)
    if second = m.lastProgressSecond then return
    m.lastProgressSecond = second
    UpdatePartState(m.video.position)
    UpdatePartStatus()
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
        if m.guideMode
            if m.guideSeekPending
                m.guideSeekPending = false
                print "Guide seek "; m.guideStart
                m.video.seek = m.guideStart
            end if
        else if m.hasParts
            UpdatePartStatus()
        else
            m.statusLabel.text = "OK  NEXT EXHIBIT    •    PLAY  PAUSE    •    BACK  DETAILS"
        end if
    else if state = "buffering"
        m.statusLabel.text = "BUFFERING"
    else if state = "paused"
        if not m.guideMode
            if m.hasParts
                UpdatePartStatus()
            else
                m.statusLabel.text = "PAUSED"
            end if
        end if
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
    if m.guideMode
        m.guideHint.text = message + "    •    BACK RETURNS"
    else
        m.statusLabel.text = message + "    •    BACK RETURNS"
    end if
end sub

sub GoToNext()
    if m.departed then return
    m.departed = true
    m.video.control = "stop"
    if m.guideMode
        if m.nextGuideIndex >= 0
            EmitNavEvent(m.top, "advance", {
                exhibitIndex: m.nextGuideIndex
                origin: "guide"
                mode: "guide"
            })
        else
            EmitNavEvent(m.top, "endToMenu", invalid)
        end if
        return
    end if

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
    if m.guideMode
        EmitNavEvent(m.top, "backToInfo", invalid)
        return
    end if

    EmitNavEvent(m.top, "backToInfo", {
        exhibitIndex: m.top.exhibitIndex
        origin: m.top.origin
        autoplay: false
    })
end sub

function HandleGuideKey(key as String) as Boolean
    if key = "OK"
        if m.guideSelectedAction = "restart"
            RestartGuideVideo()
        else if m.sawPlayback
            GoToNext()
        end if
        return true
    end if
    if key = "left"
        m.guideSelectedAction = "restart"
        UpdateGuideFocus()
        return true
    end if
    if key = "right"
        m.guideSelectedAction = "next"
        UpdateGuideFocus()
        return true
    end if
    if key = "down"
        HideChrome()
        return true
    end if
    if key = "back"
        BackToInfo()
        return true
    end if
    if key = "play"
        if m.video.state = "playing"
            m.video.control = "pause"
        else if m.video.state = "paused"
            m.video.control = "resume"
        end if
        return true
    end if

    return false
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or m.departed then return false

    if key = "back"
        BackToInfo()
        return true
    end if

    if m.chromeHidden
        if key = "OK" or key = "up" or key = "down" or key = "left" or key = "right"
            ShowChrome()
            return true
        end if
    else
        if m.guideMode then return HandleGuideKey(key)

        if key = "OK"
            if m.selectedAction = "part"
                GoToNextPart()
            else if m.sawPlayback
                GoToNext()
            end if
            return true
        end if
        if key = "left" and m.hasParts and m.partAvailable
            m.selectedAction = "part"
            print "Player action selected next part"
            UpdateButtonFocus()
            return true
        end if
        if key = "right" and m.hasParts
            m.selectedAction = "exhibit"
            print "Player action selected next exhibit"
            UpdateButtonFocus()
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
            HideChrome()
            return true
        end if
    end if

    return false
end function
