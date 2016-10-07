-- DEPENDS: cjson, file, mdns, net, rtctime, sntp, wifi; nwfnet, nwfnet-sntp
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(t)
  (require "nwfnet"):runnet("wstagoip",t)
  mdns.register(wifi.sta.gethostname())
  dofile("nwfnet-sntp.lc").dosntp(nil)
end)
wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, function(_) (require "nwfnet"):runnet("wstadtmo") end)
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(t) (require "nwfnet"):runnet("wstaconn",t) end)
wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(t) (require "nwfnet"):runnet("wstadscn",t) end)

-- One-shot configuration options; useful to change many things at once
-- at the next boot; all of these options are persisted by the ESP
if file.open("nwfnet.conf","r") then
  local conf = cjson.decode(file.read())
  if type(conf) == "table" then
    local essid = conf["sta_essid"]; local pw = conf["sta_pw"]
    if essid ~= nil and pw ~= nil then wifi.sta.config(essid,pw,0) end

    if conf["ap"] ~= nil then pcall(wifi.ap.config,conf["ap"]) end

    local modestr = conf["wifi_mode"]
    if     modestr == "station"   then wifi.setmode(wifi.STATION)
    elseif modestr == "softap"    then wifi.setmode(wifi.SOFTAP)
    elseif modestr == "stationap" then wifi.setmode(wifi.STATIONAP)
    else                               wifi.setmode(wifi.STATION)
    end

    print("Applied settings from nwfnet.conf; likely, you want to remove this file...")
   else print("nwfnet.conf malformed")
  end
  file.close()
end
-- must come after we've got our event callbacks registered, yeah?
wifi.sta.connect()

if file.open("nwfnet.cert","r") then
  local cert = ""
  local chunk = file.read()
  while chunk ~= nil do cert = cert..chunk; chunk = file.read() end
  ok, res = pcall(net.cert.verify,cert)
  file.close()
  if ok then
    print("Loaded cert from nwfnet.cert; likely, you want to remove this file...")
  else 
    print("Failed to load from nwfnet.cert", res)
  end
end

if file.open("nwfnet.conf2","r") then
  local conf = cjson.decode(file.read())
  if type(conf) == "table" then
    if conf["verify"] == 1 then print("Enabling certificate verification"); pcall(net.cert.verify,true) end
   else print("nwfnet.conf2 malformed")
  end
end
