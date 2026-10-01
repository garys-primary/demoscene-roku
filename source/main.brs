sub Main()
    print "App starting..."

    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    input = CreateObject("roInput")
    input.SetMessagePort(port)

    scene = screen.CreateScene("AppScene")
    screen.Show()

    scene.signalBeacon("AppLaunchComplete")

    while true
        msg = wait(0, port)

        if type(msg) = "roInputEvent"
            info = msg.GetInfo()
            print "roInputEvent: "; FormatJSON(info)

            ' Deep link values:
            ' info.contentID
            ' info.mediaType

        else if type(msg) = "roSGScreenEvent"
            if msg.IsScreenClosed()
                exit while
            end if
        end if
    end while
end sub