sub init()
    m.layer = m.top.FindNode("screenLayer")
    m.overlay = m.top.FindNode("transitionOverlay")
    m.catalogTask = m.top.FindNode("catalogTask")
    m.pendingNavigation = invalid
    m.liveFade = invalid
    m.fadePurpose = ""
    m.acceptFadeStop = false

    m.catalogTask.ObserveField("result", "onRemoteCatalogChanged")
    m.catalogTask.ObserveField("error", "onCatalogErrorChanged")

    catalog = LoadBundledCatalog()
    storyline = BuildStoryline()
    m.navigator = CreateNavigator(m.layer, storyline)
    m.navigator.setCatalog(catalog)

    if not m.navigator.validate()
        print "Storyline validation failed"
        return
    end if

    m.testPlayback = false
    ' ==== TEST ====
    ' Set m.testPlayback = true to open exhibit 01 immediately on launch.
    ' m.testPlayback = true
    ' ==== TEST ====
    if m.testPlayback = true
        print "TEST playback launch exhibit 0"
        m.navigator.mount("player", { exhibitIndex: 0, origin: "playAll" })
    else
        m.navigator.mount(storyline.initialRoute, invalid)
    end if
    StartOverlayFade(1.0, 0.0, 0.45, "reveal")
    StartRemoteCatalogRequest()
end sub

sub StartOverlayFade(fromOpacity as Float, toOpacity as Float, duration as Float, purpose as String)
    if m.liveFade <> invalid
        m.liveFade.UnobserveField("state")
        m.top.RemoveChild(m.liveFade)
        m.liveFade = invalid
    end if

    m.acceptFadeStop = false
    m.overlay.opacity = fromOpacity
    m.fadePurpose = purpose

    animation = CreateObject("roSGNode", "Animation")
    animation.duration = duration
    animation.easeFunction = "inOutQuad"

    interpolator = CreateObject("roSGNode", "FloatFieldInterpolator")
    interpolator.key = [0.0, 1.0]
    interpolator.keyValue = [fromOpacity, toOpacity]
    interpolator.fieldToInterp = "transitionOverlay.opacity"
    animation.AppendChild(interpolator)

    m.top.AppendChild(animation)
    m.liveFade = animation
    animation.ObserveField("state", "onLiveFadeStateChanged")
    animation.control = "start"
    m.acceptFadeStop = true
end sub

function LoadBundledCatalog() as Dynamic
    catalogText = ReadAsciiFile("pkg:/content/catalog.sample.json")
    if catalogText = "" then return invalid
    return ParseJson(catalogText)
end function

sub StartRemoteCatalogRequest()
    appInfo = CreateObject("roAppInfo")
    catalogUrl = appInfo.GetValue("catalog_url")
    if catalogUrl = invalid or catalogUrl = "" then return

    m.catalogTask.uri = catalogUrl
    m.catalogTask.control = "run"
end sub

sub onRemoteCatalogChanged()
    catalog = m.catalogTask.result
    if catalog <> invalid
        print "Using remote catalog"
        m.navigator.setCatalog(catalog)
    end if
end sub

sub onCatalogErrorChanged()
    if m.catalogTask.error <> ""
        print "Remote catalog unavailable; using bundled catalog: "; m.catalogTask.error
    end if
end sub

sub onScreenNavEvent()
    if m.pendingNavigation <> invalid or m.navigator.currentNode = invalid then return

    result = m.navigator.resolve(m.navigator.currentNode.navEvent)
    if result = invalid then return

    m.pendingNavigation = result
    StartOverlayFade(m.overlay.opacity, 1.0, 0.35, "cover")
end sub

sub onLiveFadeStateChanged()
    if not m.acceptFadeStop or m.liveFade = invalid then return
    if m.liveFade.state <> "stopped" then return
    if m.fadePurpose <> "cover" or m.pendingNavigation = invalid then return

    m.acceptFadeStop = false
    destination = m.pendingNavigation.destination
    payload = m.pendingNavigation.payload
    m.pendingNavigation = invalid
    m.fadePurpose = ""

    m.navigator.mount(destination, payload)
    StartOverlayFade(1.0, 0.0, 0.45, "reveal")
end sub
