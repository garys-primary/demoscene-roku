function CreateNavigator(layer as Object, storyline as Object) as Object
    navigator = {
        layer: layer
        routes: storyline.routes
        initialRoute: storyline.initialRoute
        currentRouteName: ""
        currentNode: invalid
        catalog: invalid
        history: []
    }

    navigator.validate = NavigatorValidate
    navigator.mount = NavigatorMount
    navigator.resolve = NavigatorResolve
    navigator.setCatalog = NavigatorSetCatalog
    return navigator
end function

function NavigatorValidate() as Boolean
    if m.routes = invalid or m.initialRoute = invalid then return false
    if m.routes[m.initialRoute] = invalid then return false

    for each routeName in m.routes
        route = m.routes[routeName]
        if route.component = invalid or route.component = "" then return false

        if route.on <> invalid
            for each eventName in route.on
                destination = route.on[eventName]
                if m.routes[destination] = invalid then
                    print "Invalid route destination: "; routeName; "."; eventName; " -> "; destination
                    return false
                end if
            end for
        end if
    end for

    return true
end function

function NavigatorMount(routeName as String, overrides as Dynamic) as Object
    route = m.routes[routeName]
    if route = invalid
        print "Cannot mount unknown route: "; routeName
        return invalid
    end if

    if m.currentNode <> invalid
        m.currentNode.UnobserveField("navEvent")
        m.layer.RemoveChild(m.currentNode)
    end if

    node = CreateObject("roSGNode", route.component)
    if node = invalid
        print "Cannot create component: "; route.component
        return invalid
    end if

    params = {}
    if route.params <> invalid
        for each key in route.params
            params[key] = route.params[key]
        end for
    end if
    if overrides <> invalid
        for each key in overrides
            params[key] = overrides[key]
        end for
    end if

    for each key in params
        if node.HasField(key) then node[key] = params[key]
    end for
    if node.HasField("catalog") then node.catalog = m.catalog

    if m.currentRouteName <> "" and m.currentRouteName <> routeName
        m.history.Push(m.currentRouteName)
    end if

    m.currentRouteName = routeName
    m.currentNode = node
    node.ObserveField("navEvent", "onScreenNavEvent")
    m.layer.AppendChild(node)
    node.SetFocus(true)

    if node.HasField("control") then node.control = "start"
    print "Mounted route: "; routeName
    return node
end function

function NavigatorResolve(event as Dynamic) as Dynamic
    if event = invalid or event.type = invalid then return invalid

    route = m.routes[m.currentRouteName]
    if route = invalid or route.on = invalid then return invalid

    destination = route.on[event.type]
    if destination = invalid
        print "Unhandled navigation event: "; m.currentRouteName; "."; event.type
        return invalid
    end if

    payload = invalid
    if event.payload <> invalid then payload = event.payload
    return {
        destination: destination
        payload: payload
    }
end function

sub NavigatorSetCatalog(catalog as Dynamic)
    m.catalog = catalog
    if m.currentNode <> invalid and m.currentNode.HasField("catalog")
        m.currentNode.catalog = catalog
    end if
end sub

