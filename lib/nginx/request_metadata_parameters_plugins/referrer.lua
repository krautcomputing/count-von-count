local referrer = {}
local socket_url = require "socket.url"

function referrer:init()
end

function referrer:AddtoArgsFromNginx(args)
  referrer:fromString(args, ngx.req.get_headers()["referer"])
end

function referrer:AddToArgsFromLogPlayer(args, line)
  referrer:fromString(args)
end

function referrer:fromString(args, url)
  local parsed_url = socket_url.parse(url)
  if parsed_url and parsed_url.scheme and parsed_url.host then
    args["referrer"] = parsed_url.scheme .. "://" .. parsed_url.host .. (parsed_url.path or "")
  else
    args["referrer"] = ""
  end
end

return referrer
