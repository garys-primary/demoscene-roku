sub init()
    m.video = m.top.FindNode("guideVideo")
    m.status = m.top.FindNode("guideStatus")
    m.placeholder = m.top.FindNode("placeholder")
    m.chrome = m.top.FindNode("chrome")
    m.video.ObserveField("position", "onGuidePositionChanged")
    m.video.ObserveField("state", "onGuideVideoStateChanged")
    m.configured = false
    m.segmentPlaying = false
    m.card = invalid
    ShowGuidePlaceholder()
end sub

sub ShowGuidePlaceholder()
    m.placeholder.visible = true
    m.video.visible = false
    m.chrome.visible = false
    m.video.control = "stop"
end sub

sub configureGuide()
    if m.configured then return

    exhibit = FindExhibit(m.top.catalog, m.top.exhibitId)
    if exhibit = invalid
        ShowGuidePlaceholder()
        return
    end if
    url = PreferredHlsUrl(exhibit)
    if url = ""
        ShowGuidePlaceholder()
        return
    end if
    if exhibit.quickGuide = invalid
        ShowGuidePlaceholder()
        return
    end if
    if exhibit.quickGuide.Count() = 0
        ShowGuidePlaceholder()
        return
    end if

    m.placeholder.visible = false
    m.video.visible = true
    m.chrome.visible = true
    m.exhibit = exhibit
    m.segments = exhibit.quickGuide
    m.segmentIndex = 0
    m.configured = true

    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamformat = "hls"
    content.title = exhibit.title + " — Quick Guide"
    m.video.content = content
    ShowCurrentGuideCard()
end sub

sub ShowCurrentGuideCard()
    m.segmentPlaying = false
    m.video.control = "pause"

    if m.segmentIndex >= m.segments.Count()
        m.video.control = "stop"
        EmitNavEvent(m.top, "complete", invalid)
        return
    end if

    segment = m.segments[m.segmentIndex]
    m.status.text = "QUICK GUIDE  •  " + (m.segmentIndex + 1).ToStr() + " / " + m.segments.Count().ToStr() + "  •  BACK TO RETURN"

    m.card = CreateObject("roSGNode", "IntertitleScreen")
    m.card.text = segment.text
    m.card.holdMs = 2400
    m.card.ObserveField("navEvent", "onGuideCardEvent")
    m.top.AppendChild(m.card)
    m.card.SetFocus(true)
    m.card.control = "start"
end sub

sub onGuideCardEvent()
    if m.card = invalid then return
    event = m.card.navEvent

    m.card.UnobserveField("navEvent")
    m.top.RemoveChild(m.card)
    m.card = invalid
    m.top.SetFocus(true)

    if event.type = "cancel"
        m.video.control = "stop"
        EmitNavEvent(m.top, "cancel", invalid)
        return
    end if

    segment = m.segments[m.segmentIndex]
    m.seekTarget = segment.start
    m.seekConfirmed = false
    m.video.control = "play"
    m.video.seek = segment.start
    m.segmentPlaying = true
end sub

sub onGuidePositionChanged()
    if not m.segmentPlaying then return

    position = m.video.position
    segment = m.segments[m.segmentIndex]
    if not m.seekConfirmed
        if Abs(position - m.seekTarget) <= 2.0
            m.seekConfirmed = true
        else
            return
        end if
    end if

    if position >= segment.end
        m.segmentPlaying = false
        m.segmentIndex++
        ShowCurrentGuideCard()
    end if
end sub

sub onGuideVideoStateChanged()
    if m.video.state = "error"
        m.status.text = "QUICK GUIDE PLAYBACK ERROR  •  BACK TO RETURN"
        m.segmentPlaying = false
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.video.control = "stop"
        EmitNavEvent(m.top, "cancel", invalid)
        return true
    end if
    if key = "play"
        if m.video.state = "playing"
            m.video.control = "pause"
        else
            m.video.control = "resume"
        end if
        return true
    end if

    return false
end function

