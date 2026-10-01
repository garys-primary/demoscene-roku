function FindExhibit(catalog as Dynamic, exhibitId as String) as Dynamic
    if catalog = invalid or catalog.exhibits = invalid then return invalid

    for each exhibit in catalog.exhibits
        if exhibit.id = exhibitId then return exhibit
    end for

    return invalid
end function

function DeviceSupportsHevc4k() as Boolean
    deviceInfo = CreateObject("roDeviceInfo")
    capability = deviceInfo.CanDecodeVideo({
        Codec: "hevc"
        Profile: "main"
        Level: "5.1"
    })

    if Type(capability) = "roBoolean" or Type(capability) = "Boolean"
        return capability
    end if
    if Type(capability) = "roAssociativeArray" and capability.result <> invalid
        return capability.result = true
    end if

    return false
end function

function PreferredHlsUrl(exhibit as Dynamic) as String
    if exhibit = invalid or exhibit.streams = invalid then return ""

    if exhibit.streams.hevc <> invalid and exhibit.streams.hevc <> "" and DeviceSupportsHevc4k()
        return exhibit.streams.hevc
    end if
    if exhibit.streams.h264 <> invalid then return exhibit.streams.h264
    return ""
end function

function ExhibitCount(catalog as Dynamic) as Integer
    if catalog = invalid or catalog.exhibits = invalid then return 0
    return catalog.exhibits.Count()
end function

function ExhibitAt(catalog as Dynamic, exhibitIndex as Integer) as Dynamic
    if exhibitIndex < 0 or exhibitIndex >= ExhibitCount(catalog) then return invalid
    return catalog.exhibits[exhibitIndex]
end function

function HasNextExhibit(catalog as Dynamic, exhibitIndex as Integer) as Boolean
    return exhibitIndex + 1 < ExhibitCount(catalog)
end function

function Pad2(value as Dynamic) as String
    number = Int(value)
    if number < 0 then number = 0
    if number < 10 then return "0" + number.ToStr()
    return number.ToStr()
end function

function EndEventFor(origin as String) as String
    if origin = "browse" then return "endToGrid"
    return "endToMenu"
end function

function InfoBackEventFor(origin as String) as String
    if origin = "browse" then return "backToGrid"
    return "backToMenu"
end function

function EmitNavEvent(node as Object, eventType as String, payload = invalid as Dynamic)
    event = { type: eventType }
    if payload <> invalid then event.payload = payload
    node.navEvent = event
end function

