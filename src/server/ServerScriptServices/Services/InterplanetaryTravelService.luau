--[[
    InterplanetaryTravelService.luau
    ================================
    Server-side service that manages all interplanetary travel.

    Responsibilities:
      • Validate travel requests (ownership, credits, rocket speed)
      • Calculate TravelTime = DistanceAU / RocketSpeedAU_per_s
      • Deduct fuel costs and teleport the player on completion
      • Fire client-facing RemoteEvents for UI updates (countdown, arrival)

    Dependencies (Rojo paths):
      ServerScriptService.Server.Services  ← this file lives here
      ReplicatedStorage.Shared.GameConfigs
      ReplicatedStorage.Shared.RemoteEvents
      ServerScriptService.Server.Services.DataService   (player data / credits)

    NOTE: Never require this module from the client. All calls go through
    RemoteEvents defined in RemoteEvents.luau.
]]

--// ── Services ───────────────────────────────────────────────────────────────
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptStorage = game:GetService("ServerScriptService")

--// ── Shared Modules ─────────────────────────────────────────────────────────
local Shared       = ReplicatedStorage:WaitForChild("Shared")
local GameConfigs  = require(Shared:WaitForChild("GameConfigs"))

--// ── Remote Events ──────────────────────────────────────────────────────────
-- These should be pre-created under ReplicatedStorage.RemoteEvents
local RemoteEvents        = ReplicatedStorage:WaitForChild("RemoteEvents")
local RE_RequestTravel    = RemoteEvents:WaitForChild("RequestTravel")      -- Client → Server
local RE_TravelCountdown  = RemoteEvents:WaitForChild("TravelCountdown")    -- Server → Client
local RE_TravelComplete   = RemoteEvents:WaitForChild("TravelComplete")     -- Server → Client
local RE_TravelFailed     = RemoteEvents:WaitForChild("TravelFailed")       -- Server → Client

--// ── Internal Dependencies ──────────────────────────────────────────────────
-- DataService exposes:
--   DataService.GetData(player)           → PlayerData table
--   DataService.DeductCredits(player, n)  → bool (success)
--   DataService.SetCurrentPlanet(player, planetKey)
local Services     = ServerScriptStorage:WaitForChild("Server"):WaitForChild("Services")
local DataService  = require(Services:WaitForChild("DataService"))

-- TycoonService exposes:
--   TycoonService.SpawnTycoon(player, planetKey, plotIndex)
local TycoonService = require(Services:WaitForChild("TycoonService"))

--// ── Module Definition ───────────────────────────────────────────────────────
local InterplanetaryTravelService = {}

--[[
    Active travel sessions.
    Key   : player.UserId (number)
    Value : { planetKey: string, rocketKey: string, arrivalTime: number }
    Used to prevent duplicate travel requests while one is in-flight.
]]
local activeTravels: { [number]: { planetKey: string, rocketKey: string, arrivalTime: number } } = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- PRIVATE HELPERS
-- ─────────────────────────────────────────────────────────────────────────────

--[[
    _calculateTravelTime(planetKey, rocketKey) → number (seconds)

    Core formula:
        TravelTime = max(MinTravelTime, DistanceAU / RocketSpeed)
]]
local function _calculateTravelTime(planetKey: string, rocketKey: string): number
    local planetData = GameConfigs.Planets[planetKey]
    local rocketData = GameConfigs.Rockets[rocketKey]

    assert(planetData, "[TravelService] Unknown planet key: " .. tostring(planetKey))
    assert(rocketData, "[TravelService] Unknown rocket key: " .. tostring(rocketKey))

    local distanceAU = planetData.DistanceAU   -- number
    local speedAU_s  = rocketData.Speed         -- AU per second

    local rawTime = distanceAU / speedAU_s       -- seconds (may be 0 for Earth)
    local travelSettings = GameConfigs.TravelSettings

    return math.max(travelSettings.MinTravelTimeSeconds, rawTime)
end

--[[
    _calculateFuelCost(planetKey, rocketKey) → number (credits)

    FuelCost = DistanceAU * FuelCostPerAU
    Returns 0 if FuelDeductionEnabled is false.
]]
local function _calculateFuelCost(planetKey: string, rocketKey: string): number
    if not GameConfigs.TravelSettings.FuelDeductionEnabled then
        return 0
    end

    local planetData = GameConfigs.Planets[planetKey]
    local rocketData = GameConfigs.Rockets[rocketKey]

    return math.ceil(planetData.DistanceAU * rocketData.FuelCostPerAU)
end

--[[
    _validateTravelRequest(player, targetPlanetKey, rocketKey)
    → success: boolean, reason: string?

    Checks (in order):
      1. Player is not already travelling
      2. Planet key exists
      3. Rocket key exists and player owns it
      4. Unlock prerequisite satisfied
      5. Player has sufficient credits for fuel
]]
local function _validateTravelRequest(
    player: Player,
    targetPlanetKey: string,
    rocketKey: string
): (boolean, string?)

    -- 1. Already travelling?
    if activeTravels[player.UserId] then
        return false, "Already travelling. Please wait for landing."
    end

    -- 2. Valid planet?
    local planetData = GameConfigs.Planets[targetPlanetKey]
    if not planetData then
        return false, "Unknown destination: " .. tostring(targetPlanetKey)
    end

    -- 3. Valid rocket & ownership?
    local rocketData = GameConfigs.Rockets[rocketKey]
    if not rocketData then
        return false, "Unknown rocket: " .. tostring(rocketKey)
    end

    local playerData = DataService.GetData(player)
    if not playerData then
        return false, "Could not load player data. Try again."
    end

    local ownedRockets: { [string]: boolean } = playerData.OwnedRockets or {}
    if not ownedRockets[rocketKey] then
        return false, "You do not own the " .. rocketData.DisplayName .. "."
    end

    -- 4. Unlock prerequisite?
    local requiredPlanet = planetData.UnlockRequirement
    if requiredPlanet then
        local visitedPlanets: { [string]: boolean } = playerData.VisitedPlanets or {}
        if not visitedPlanets[requiredPlanet] then
            local reqData = GameConfigs.Planets[requiredPlanet]
            return false, "You must visit " .. (reqData and reqData.DisplayName or requiredPlanet) .. " first."
        end
    end

    -- 5. Sufficient credits for fuel?
    local fuelCost = _calculateFuelCost(targetPlanetKey, rocketKey)
    if fuelCost > 0 and (playerData.Credits or 0) < fuelCost then
        return false, string.format(
            "Not enough credits for fuel. Need %d, have %d.",
            fuelCost,
            playerData.Credits or 0
        )
    end

    return true, nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PUBLIC API
-- ─────────────────────────────────────────────────────────────────────────────

--[[
    InterplanetaryTravelService.InitiateTravel(player, targetPlanetKey, rocketKey)

    Called internally after RemoteEvent fires from the client.
    Validates, deducts fuel, starts a countdown coroutine, then teleports.
]]
function InterplanetaryTravelService.InitiateTravel(
    player: Player,
    targetPlanetKey: string,
    rocketKey: string
)
    -- ── Validate ──────────────────────────────────────────────────────────
    local ok, reason = _validateTravelRequest(player, targetPlanetKey, rocketKey)
    if not ok then
        RE_TravelFailed:FireClient(player, reason)
        warn(string.format("[TravelService] %s → travel rejected: %s", player.Name, reason))
        return
    end

    -- ── Deduct fuel cost ──────────────────────────────────────────────────
    local fuelCost = _calculateFuelCost(targetPlanetKey, rocketKey)
    if fuelCost > 0 then
        local deducted = DataService.DeductCredits(player, fuelCost)
        if not deducted then
            RE_TravelFailed:FireClient(player, "Credit deduction failed. Please retry.")
            return
        end
    end

    -- ── Calculate travel time ─────────────────────────────────────────────
    local travelTime = _calculateTravelTime(targetPlanetKey, rocketKey)

    local planetData = GameConfigs.Planets[targetPlanetKey]
    local rocketData = GameConfigs.Rockets[rocketKey]

    print(string.format(
        "[TravelService] %s launching to %s | Rocket: %s | Distance: %.4f AU | Speed: %.4f AU/s | ETA: %.1fs",
        player.Name,
        planetData.DisplayName,
        rocketData.DisplayName,
        planetData.DistanceAU,
        rocketData.Speed,
        travelTime
    ))

    -- ── Register active session ───────────────────────────────────────────
    local arrivalTime = os.clock() + travelTime
    activeTravels[player.UserId] = {
        planetKey  = targetPlanetKey,
        rocketKey  = rocketKey,
        arrivalTime = arrivalTime,
    }

    -- Notify client to start the countdown UI
    RE_TravelCountdown:FireClient(player, {
        TargetPlanet    = targetPlanetKey,
        DisplayName     = planetData.DisplayName,
        TravelTime      = travelTime,
        FuelCostPaid    = fuelCost,
        RocketKey       = rocketKey,
    })

    -- ── Async travel coroutine ────────────────────────────────────────────
    task.spawn(function()
        task.wait(travelTime)

        -- Guard: player may have left during travel
        if not player.Parent then
            activeTravels[player.UserId] = nil
            return
        end

        -- Mark planet as visited and update current planet
        DataService.SetCurrentPlanet(player, targetPlanetKey)

        -- Clear the active session
        activeTravels[player.UserId] = nil

        -- Notify client: travel complete
        RE_TravelComplete:FireClient(player, {
            PlanetKey   = targetPlanetKey,
            DisplayName = planetData.DisplayName,
        })

        print(string.format(
            "[TravelService] %s has arrived at %s.",
            player.Name,
            planetData.DisplayName
        ))
    end)
end

--[[
    InterplanetaryTravelService.IsPlayerTravelling(player) → boolean

    Utility used by other services (e.g. to block purchases mid-flight).
]]
function InterplanetaryTravelService.IsPlayerTravelling(player: Player): boolean
    return activeTravels[player.UserId] ~= nil
end

--[[
    InterplanetaryTravelService.GetETASeconds(player) → number?

    Returns remaining seconds until arrival, or nil if not travelling.
]]
function InterplanetaryTravelService.GetETASeconds(player: Player): number?
    local session = activeTravels[player.UserId]
    if not session then return nil end

    local remaining = session.arrivalTime - os.clock()
    return math.max(0, remaining)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- REMOTE EVENT WIRING
-- ─────────────────────────────────────────────────────────────────────────────
--[[
    Client fires:  RE_RequestTravel:FireServer(targetPlanetKey, rocketKey)
    Server routes it through validation here.
    All inputs from the client are treated as UNTRUSTED.
]]
RE_RequestTravel.OnServerEvent:Connect(function(
    player: Player,
    targetPlanetKey: unknown,
    rocketKey: unknown
)
    -- Type-guard: reject malformed payloads immediately
    if type(targetPlanetKey) ~= "string" or type(rocketKey) ~= "string" then
        RE_TravelFailed:FireClient(player, "Invalid request payload.")
        return
    end

    -- Sanitise: strip leading/trailing whitespace to prevent key spoofing
    targetPlanetKey = targetPlanetKey:match("^%s*(.-)%s*$")
    rocketKey       = rocketKey:match("^%s*(.-)%s*$")

    InterplanetaryTravelService.InitiateTravel(player, targetPlanetKey, rocketKey)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- CLEANUP on player leave
-- ─────────────────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player: Player)
    activeTravels[player.UserId] = nil
end)

return InterplanetaryTravelService
