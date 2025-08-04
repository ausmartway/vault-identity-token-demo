-- Simple JWT claim validator for Kong (sandbox-safe)
-- This validates audience and department without external libraries

-- Get the Authorization header
local auth_header = kong.request.get_header("authorization")
if not auth_header then
    return kong.response.exit(401, {message = "Missing Authorization header"})
end

-- Extract the token (remove "Bearer " prefix)
local token = auth_header:match("Bearer%s+(.+)")
if not token then
    return kong.response.exit(401, {message = "Invalid Authorization header format"})
end

-- Simple JWT payload extraction (base64 decode)
local function base64_decode_simple(input)
    -- Replace URL-safe chars
    input = input:gsub('-', '+'):gsub('_', '/')
    -- Add padding if needed
    local padding = 4 - (string.len(input) % 4)
    if padding ~= 4 then
        input = input .. string.rep('=', padding)
    end
    return ngx.decode_base64(input)
end

-- Extract JWT parts
local header, payload, signature = token:match("([^%.]+)%.([^%.]+)%.([^%.]+)")
if not header or not payload or not signature then
    return kong.response.exit(401, {message = "Invalid JWT format"})
end

-- Decode payload
local payload_json = base64_decode_simple(payload)
if not payload_json then
    return kong.response.exit(401, {message = "Could not decode JWT payload"})
end

-- Simple JSON parsing for specific fields (avoid requiring cjson)
-- Look for specific patterns in the JSON string
local aud_match = payload_json:match('"aud"%s*:%s*"([^"]+)"')
local dept_match = payload_json:match('"department"%s*:%s*"([^"]+)"')
local role_match = payload_json:match('"role"%s*:%s*"([^"]+)"')
local entity_match = payload_json:match('"entity_name"%s*:%s*"([^"]+)"')
local sub_match = payload_json:match('"sub"%s*:%s*"([^"]+)"')

-- Validate audience
local expected_audience = "spiffe://kong-api-gateway"
if not aud_match or aud_match ~= expected_audience then
    kong.log.err("Invalid audience. Expected: " .. expected_audience .. ", Got: " .. tostring(aud_match))
    return kong.response.exit(403, {
        message = "Access denied: Invalid audience claim",
        expected = expected_audience,
        received = aud_match
    })
end

-- Validate department
local allowed_departments = {"engineering", "security", "devops"}
if not dept_match then
    return kong.response.exit(403, {message = "Access denied: Missing department claim"})
end

local department_allowed = false
for _, dept in ipairs(allowed_departments) do
    if dept_match == dept then
        department_allowed = true
        break
    end
end

if not department_allowed then
    kong.log.err("Department not allowed: " .. dept_match)
    return kong.response.exit(403, {
        message = "Access denied: Department not authorized",
        department = dept_match,
        allowed_departments = allowed_departments
    })
end

-- Log successful validation
kong.log.info("JWT validation successful - User: " .. tostring(entity_match) .. 
              ", Department: " .. dept_match .. 
              ", Role: " .. tostring(role_match))

-- Add custom headers
kong.service.request.set_header("X-User-Department", dept_match)
if role_match then
    kong.service.request.set_header("X-User-Role", role_match)
end
if entity_match then
    kong.service.request.set_header("X-User-Entity", entity_match)
end
if sub_match then
    kong.service.request.set_header("X-User-ID", sub_match)
end
