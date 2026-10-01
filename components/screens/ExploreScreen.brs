sub init()
    m.cardLayer = m.top.FindNode("cardLayer")
    m.focusFrame = m.top.FindNode("focusFrame")
    m.emptyLabel = m.top.FindNode("emptyLabel")
    m.countLabel = m.top.FindNode("countLabel")
    m.enterAnim = m.top.FindNode("enterAnim")
    m.enterDelay = m.top.FindNode("enterDelay")
    m.enterDelay.ObserveField("fire", "onEnterDelay")
    m.columns = 3
    m.visibleRows = 3
    m.cardW = 500
    m.cardH = 208
    m.gapX = 36
    m.gapY = 26
    m.index = 0
    m.scrollRow = 0
    m.started = false
    m.cards = []
    m.positions = []
end sub

sub onControlChanged()
    if m.top.control <> "start" then return
    m.started = true
    BuildGrid()
    m.enterDelay.control = "start"
end sub

sub onCatalogChanged()
    if m.started then BuildGrid()
end sub

sub onEnterDelay()
    m.enterAnim.control = "start"
end sub

sub BuildGrid()
    while m.cardLayer.GetChildCount() > 0
        m.cardLayer.RemoveChildIndex(0)
    end while
    m.cardLayer.AppendChild(m.focusFrame)

    m.cards = []
    m.positions = []
    m.scrollRow = 0
    m.cardLayer.translation = [0, 0]

    count = ExhibitCount(m.top.catalog)
    m.countLabel.text = count.ToStr() + " WORKS READY"
    if count = 0
        m.emptyLabel.visible = true
        m.focusFrame.visible = false
        return
    end if

    m.emptyLabel.visible = false
    m.focusFrame.visible = true
    if m.index >= count then m.index = 0

    fontNum = MakeFont(22)
    fontTitle = MakeFont(28)
    fontMeta = MakeFont(22)

    for index = 0 to count - 1
        exhibit = m.top.catalog.exhibits[index]
        column = index mod m.columns
        row = index \ m.columns
        x = 16 + column * (m.cardW + m.gapX)
        y = 16 + row * (m.cardH + m.gapY)
        card = CreateExhibitCard(exhibit, fontNum, fontTitle, fontMeta)
        card.group.translation = [x, y]
        m.cardLayer.AppendChild(card.group)
        m.cards.Push(card)
        m.positions.Push({ x: x, y: y })
    end for

    UpdateBrowseFocus()
end sub

function CreateExhibitCard(exhibit as Object, fontNum as Object, fontTitle as Object, fontMeta as Object) as Object
    group = CreateObject("roSGNode", "Group")

    bg = CreateObject("roSGNode", "Rectangle")
    bg.width = m.cardW
    bg.height = m.cardH
    bg.color = "0x121212FF"
    group.AppendChild(bg)

    accent = CreateObject("roSGNode", "Rectangle")
    accent.width = 6
    accent.height = m.cardH
    accent.color = "0xFFFFFFFF"
    accent.visible = false
    group.AppendChild(accent)

    numberLabel = CreateObject("roSGNode", "Label")
    numberLabel.font = fontNum
    numberLabel.text = Pad2(exhibit.number)
    numberLabel.translation = [28, 18]
    numberLabel.width = 140
    numberLabel.height = 36
    numberLabel.color = "0x8A8A8AFF"
    group.AppendChild(numberLabel)

    yearLabel = CreateObject("roSGNode", "Label")
    yearLabel.font = fontMeta
    yearLabel.text = exhibit.year.ToStr()
    yearLabel.translation = [280, 18]
    yearLabel.width = 192
    yearLabel.height = 36
    yearLabel.horizAlign = "right"
    yearLabel.color = "0x8A8A8AFF"
    group.AppendChild(yearLabel)

    titleLabel = CreateObject("roSGNode", "Label")
    titleLabel.font = fontTitle
    titleLabel.text = exhibit.title
    titleLabel.translation = [28, 62]
    titleLabel.width = 444
    titleLabel.height = 84
    titleLabel.wrap = true
    titleLabel.color = "0xD6D6D6FF"
    group.AppendChild(titleLabel)

    artistLabel = CreateObject("roSGNode", "Label")
    artistLabel.font = fontMeta
    artistLabel.text = exhibit.artist
    artistLabel.translation = [28, 156]
    artistLabel.width = 444
    artistLabel.height = 36
    artistLabel.color = "0x9A9A9AFF"
    group.AppendChild(artistLabel)

    return {
        group: group
        bg: bg
        accent: accent
        title: titleLabel
    }
end function

function MakeFont(size as Integer) as Object
    font = CreateObject("roSGNode", "Font")
    font.uri = "pkg:/assets/fonts/ShareTechMono-Regular.ttf"
    font.size = size
    return font
end function

sub UpdateBrowseFocus()
    count = m.cards.Count()
    if count = 0 then return
    if m.index < 0 then m.index = 0
    if m.index >= count then m.index = count - 1

    row = m.index \ m.columns
    maxScroll = ((count - 1) \ m.columns) - (m.visibleRows - 1)
    if maxScroll < 0 then maxScroll = 0
    if row < m.scrollRow then m.scrollRow = row
    if row >= m.scrollRow + m.visibleRows then m.scrollRow = row - m.visibleRows + 1
    if m.scrollRow > maxScroll then m.scrollRow = maxScroll
    if m.scrollRow < 0 then m.scrollRow = 0
    m.cardLayer.translation = [0, -m.scrollRow * (m.cardH + m.gapY)]

    cardPosition = m.positions[m.index]
    m.focusFrame.translation = [cardPosition.x - 10, cardPosition.y - 10]
    m.focusFrame.width = m.cardW + 20
    m.focusFrame.height = m.cardH + 20

    for index = 0 to count - 1
        card = m.cards[index]
        if index = m.index
            card.bg.color = "0x242424FF"
            card.accent.visible = true
            card.title.color = "0xFFFFFFFF"
        else
            card.bg.color = "0x121212FF"
            card.accent.visible = false
            card.title.color = "0xD0D0D0FF"
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or not m.started then return false

    if key = "back"
        EmitNavEvent(m.top, "cancel", invalid)
        return true
    end if

    count = m.cards.Count()
    if count = 0 then return false

    column = m.index mod m.columns
    row = m.index \ m.columns
    rowCount = ((count - 1) \ m.columns) + 1

    if key = "left"
        if column > 0 then m.index = m.index - 1
        UpdateBrowseFocus()
        return true
    end if
    if key = "right"
        if column < m.columns - 1 and m.index + 1 < count then m.index = m.index + 1
        UpdateBrowseFocus()
        return true
    end if
    if key = "up"
        if row > 0 then m.index = m.index - m.columns
        UpdateBrowseFocus()
        return true
    end if
    if key = "down"
        if row < rowCount - 1 and m.index + m.columns < count then m.index = m.index + m.columns
        UpdateBrowseFocus()
        return true
    end if
    if key = "OK"
        EmitNavEvent(m.top, "selectExhibit", {
            exhibitIndex: m.index
            origin: "browse"
            autoplay: true
        })
        return true
    end if

    return false
end function
