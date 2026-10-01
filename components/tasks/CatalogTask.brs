sub init()
    m.top.functionName = "fetchCatalog"
end sub

sub fetchCatalog()
    if m.top.uri = ""
        m.top.error = "Catalog URI is empty"
        return
    end if

    transfer = CreateObject("roUrlTransfer")
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetUrl(m.top.uri)
    transfer.AddHeader("Accept", "application/json")

    response = transfer.GetToString()
    if response = invalid or response = ""
        m.top.error = "Empty catalog response"
        return
    end if

    catalog = ParseJson(response)
    if catalog = invalid or catalog.exhibits = invalid
        m.top.error = "Catalog JSON is invalid"
        return
    end if

    m.top.result = catalog
end sub

