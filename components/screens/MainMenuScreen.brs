sub init()
    m.focusBar = m.top.FindNode("focusBar")
    m.labels = [
        m.top.FindNode("playLabel"),
        m.top.FindNode("guideLabel"),
        m.top.FindNode("browseLabel")
    ]
    m.positions = [470, 590, 710]
    m.selection = 0
    UpdateMainMenuFocus()
end sub

sub UpdateMainMenuFocus()
    m.focusBar.translation = [165, m.positions[m.selection]]
    for index = 0 to m.labels.Count() - 1
        if index = m.selection
            m.labels[index].color = "0xFFFFFFFF"
        else
            m.labels[index].color = "0xC8C8C8FF"
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    count = m.labels.Count()
    if key = "up"
        m.selection = (m.selection + count - 1) mod count
        UpdateMainMenuFocus()
        return true
    end if
    if key = "down"
        m.selection = (m.selection + 1) mod count
        UpdateMainMenuFocus()
        return true
    end if
    if key = "OK"
        if m.selection = 0
            EmitNavEvent(m.top, "playAll", {
                exhibitIndex: 0
                origin: "playAll"
                autoplay: true
            })
        else if m.selection = 1
            EmitNavEvent(m.top, "quickGuide", invalid)
        else
            EmitNavEvent(m.top, "browse", invalid)
        end if
        return true
    end if
    if key = "back"
        EmitNavEvent(m.top, "cancel", invalid)
        return true
    end if

    return false
end function
