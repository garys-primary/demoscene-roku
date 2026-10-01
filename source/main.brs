sub Main()
    print "App starting..."
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    scene = screen.CreateScene("AppScene")
    screen.Show()

    while true
        message = Wait(0, port)
        if Type(message) = "roSGScreenEvent" and message.IsScreenClosed()
            exit while
        end if
    end while
end sub

