sub init()
    m.numberLabel = m.top.FindNode("workNumber")
    m.yearLabel = m.top.FindNode("workYear")
    m.titleLabel = m.top.FindNode("workTitle")
    m.metaLabel = m.top.FindNode("workMeta")
    m.descriptionLabel = m.top.FindNode("workDescription")
    m.focusBar = m.top.FindNode("focusBar")
    m.watchLabel = m.top.FindNode("watchLabel")
    m.nextLabel = m.top.FindNode("nextLabel")
    m.countLabel = m.top.FindNode("countLabel")
    m.countCaption = m.top.FindNode("countCaption")
    m.hintLabel = m.top.FindNode("hintLabel")
    m.timer = m.top.FindNode("countdownTimer")
    m.timer.ObserveField("fire", "onCountdownTick")
    m.labels = [m.watchLabel, m.nextLabel]
    m.selection = 0
    m.optionCount = 1
    m.remaining = 15
    m.departed = false
end sub

sub onControlChanged()
    if m.top.control <> "start" or m.departed then return

    m.selection = 0
    RenderIntro()
    if m.top.autoplay and CurrentExhibit() <> invalid
        m.remaining = 15
        m.countCaption.text = "PLAYS IN"
        m.countLabel.text = Pad2(m.remaining)
        m.timer.control = "start"
    else
        m.timer.control = "stop"
        m.countLabel.text = ""
        m.countCaption.text = "READY"
    end if
    UpdateIntroFocus()
end sub

sub onCatalogChanged()
    if m.departed then return
    RenderIntro()
    UpdateIntroFocus()
end sub

function CurrentExhibit() as Dynamic
    return ExhibitAt(m.top.catalog, m.top.exhibitIndex)
end function

sub RenderIntro()
    exhibit = CurrentExhibit()
    m.optionCount = 1
    m.nextLabel.visible = false

    if exhibit = invalid
        m.numberLabel.text = ""
        m.yearLabel.text = ""
        m.titleLabel.text = "WORK UNAVAILABLE"
        m.metaLabel.text = ""
        m.descriptionLabel.text = "This entry is not in the catalog."
        m.watchLabel.visible = false
        m.focusBar.visible = false
        m.hintLabel.text = "BACK TO RETURN"
        return
    end if

    m.watchLabel.visible = true
    m.focusBar.visible = true
    m.numberLabel.text = Pad2(exhibit.number)
    m.yearLabel.text = exhibit.year.ToStr()
    m.titleLabel.text = exhibit.title
    m.metaLabel.text = exhibit.artist + "   •   " + exhibit.platform
    m.descriptionLabel.text = exhibit.description
    if m.top.origin = "browse"
        m.hintLabel.text = "OK TO CHOOSE   •   BACK TO BROWSE"
    else
        m.hintLabel.text = "OK TO CHOOSE   •   BACK TO MENU"
    end if

    if HasNextExhibit(m.top.catalog, m.top.exhibitIndex)
        m.optionCount = 2
        m.nextLabel.visible = true
    else if m.selection > 0
        m.selection = 0
    end if
end sub

sub onCountdownTick()
    if m.departed or not m.top.autoplay then return

    m.remaining = m.remaining - 1
    if m.remaining <= 0
        PlayCurrent()
        return
    end if
    m.countLabel.text = Pad2(m.remaining)
end sub

sub UpdateIntroFocus()
    if not m.focusBar.visible then return
    if m.selection >= m.optionCount then m.selection = 0

    yPositions = [760, 848]
    m.focusBar.translation = [150, yPositions[m.selection]]
    for index = 0 to m.labels.Count() - 1
        if m.labels[index].visible and index = m.selection
            m.labels[index].color = "0xFFFFFFFF"
        else
            m.labels[index].color = "0xB8B8B8FF"
        end if
    end for
end sub

sub PlayCurrent()
    if m.departed or CurrentExhibit() = invalid then return
    m.departed = true
    m.timer.control = "stop"
    EmitNavEvent(m.top, "play", {
        exhibitIndex: m.top.exhibitIndex
        origin: m.top.origin
    })
end sub

sub SkipToNext()
    if m.departed then return
    m.departed = true
    m.timer.control = "stop"
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

sub LeaveIntro()
    if m.departed then return
    m.departed = true
    m.timer.control = "stop"
    EmitNavEvent(m.top, InfoBackEventFor(m.top.origin), invalid)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or m.departed then return false

    if key = "up"
        if m.optionCount > 1
            m.selection = (m.selection + m.optionCount - 1) mod m.optionCount
            UpdateIntroFocus()
        end if
        return true
    end if
    if key = "down"
        if m.optionCount > 1
            m.selection = (m.selection + 1) mod m.optionCount
            UpdateIntroFocus()
        end if
        return true
    end if
    if key = "OK"
        if m.selection = 0
            PlayCurrent()
        else
            SkipToNext()
        end if
        return true
    end if
    if key = "back"
        LeaveIntro()
        return true
    end if

    return false
end function
