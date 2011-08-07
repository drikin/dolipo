function FindProxyForURL(url, host)
{
// variable strings to return
var proxy_yes = "PROXY 127.0.0.1:8123; DIRECT";
var proxy_no  = "DIRECT";

    if (isPlainHostName(host) ||
        isInNet(host, "10.0.0.0", "255.0.0.0") ||
        isInNet(host, "127.0.0.0", "255.0.0.0") ||
        isInNet(host, "169.254.0.0", "255.255.0.0") ||
        isInNet(host, "192.168.0.0", "255.255.0.0")
      ) { return proxy_no; }
    if (url.substring(0, 4) == "ftp:")
        { return proxy_no; }
    if (localHostOrDomainIs(host, "idisk.mac.com"))
        { return proxy_no; }

return proxy_yes;
}
