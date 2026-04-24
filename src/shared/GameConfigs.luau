--[[
    GameConfigs.luau
    ================
    Central data-driven configuration for Galactic Fast-Food Tycoon.
    All gameplay stats live here — never hardcode values in services.

    Usage (anywhere in the project):
        local GameConfigs = require(ReplicatedStorage.Shared.GameConfigs)
        local earthData = GameConfigs.Planets["Earth"]
]]

local GameConfigs = {}

-- ─────────────────────────────────────────────
-- PLANETS
-- Fields:
--   DisplayName   : string  — Pretty UI label
--   Description   : string  — Flavour text shown in Travel Menu
--   DistanceAU    : number  — Distance from "hub" in Astronomical Units
--                             (used by InterplanetaryTravelService)
--   PlotCost      : number  — Credits to purchase a land plot
--   RevenueMultiplier : number — Baseline income multiplier for tycoons here
--   UnlockRequirement : string? — Key of planet that must be visited first
--   Thumbnail     : string  — Asset ID for UI thumbnail ("rbxassetid://...")
-- ─────────────────────────────────────────────
GameConfigs.Planets = {
    ["Earth"] = {
        DisplayName         = "Earth",
        Description         = "Home world. Humble beginnings, greasy dreams.",
        DistanceAU          = 0,        -- Starting planet; no travel needed
        PlotCost            = 0,        -- Free starter plot
        RevenueMultiplier   = 1.0,
        UnlockRequirement   = nil,
        Thumbnail           = "rbxassetid://0000000001",
    },

    ["Luna"] = {
        DisplayName         = "Luna Colony",
        Description         = "Low gravity means your burgers flip themselves.",
        DistanceAU          = 0.0026,   -- ~384,400 km → converted to AU
        PlotCost            = 5_000,
        RevenueMultiplier   = 1.5,
        UnlockRequirement   = "Earth",
        Thumbnail           = "rbxassetid://0000000002",
    },

    ["Mars"] = {
        DisplayName         = "Mars Outpost",
        Description         = "Red dust. Redder hot sauce. Intergalactic gold.",
        DistanceAU          = 0.52,     -- Average Earth-Mars distance
        PlotCost            = 25_000,
        RevenueMultiplier   = 2.8,
        UnlockRequirement   = "Luna",
        Thumbnail           = "rbxassetid://0000000003",
    },

    ["Jupiter"] = {
        DisplayName         = "Jupiter Skydock",
        Description         = "Floating platform in the storm. Premium vibes.",
        DistanceAU          = 4.2,
        PlotCost            = 150_000,
        RevenueMultiplier   = 6.0,
        UnlockRequirement   = "Mars",
        Thumbnail           = "rbxassetid://0000000004",
    },

    ["Kepler452b"] = {
        DisplayName         = "Kepler-452b",
        Description         = "Earth's older cousin. Absolutely starving for fast food.",
        DistanceAU          = 1_400,    -- ~1,400 light-years as AU proxy for gameplay
        PlotCost            = 10_000_000,
        RevenueMultiplier   = 50.0,
        UnlockRequirement   = "Jupiter",
        Thumbnail           = "rbxassetid://0000000005",
    },
}

-- ─────────────────────────────────────────────
-- ROCKETS
-- Fields:
--   DisplayName  : string
--   Description  : string
--   Speed        : number  — AU per second (used: TravelTime = Distance / Speed)
--   Cost         : number  — Credits to purchase
--   FuelCostPerAU: number  — Credits burned per AU travelled
--   Capacity     : number  — Max players per trip (cosmetic / future use)
--   ModelAsset   : string  — Asset ID for the rocket Model in Workspace
-- ─────────────────────────────────────────────
GameConfigs.Rockets = {
    ["StarterPod"] = {
        DisplayName     = "Starter Pod",
        Description     = "Barely held together with duct tape. Gets you to Luna.",
        Speed           = 0.005,        -- AU/s → ~8.6 min to Luna
        Cost            = 0,            -- Free starter rocket
        FuelCostPerAU   = 10,
        Capacity        = 1,
        ModelAsset      = "rbxassetid://0000000010",
    },

    ["CosmoCourier"] = {
        DisplayName     = "Cosmo Courier",
        Description     = "Reliable workhorse. Mars awaits.",
        Speed           = 0.05,
        Cost            = 20_000,
        FuelCostPerAU   = 8,
        Capacity        = 2,
        ModelAsset      = "rbxassetid://0000000011",
    },

    ["NebulaDasher"] = {
        DisplayName     = "Nebula Dasher",
        Description     = "Afterburners included. Jupiter in style.",
        Speed           = 0.3,
        Cost            = 120_000,
        FuelCostPerAU   = 5,
        Capacity        = 4,
        ModelAsset      = "rbxassetid://0000000012",
    },

    ["WarpBurrito"] = {
        DisplayName     = "Warp Burrito",
        Description     = "Experimental FTL drive. Smells like burritos inside.",
        Speed           = 50.0,         -- Near-FTL; needed for Kepler-452b
        Cost            = 5_000_000,
        FuelCostPerAU   = 1,
        Capacity        = 8,
        ModelAsset      = "rbxassetid://0000000013",
    },
}

-- ─────────────────────────────────────────────
-- SHOP ITEMS  (Planet-specific cooking equipment)
-- Each entry is keyed by a unique ItemId.
-- Fields:
--   DisplayName       : string
--   Description       : string
--   Planet            : string  — Key in Planets; which shop sells this
--   Price             : number  — Credits
--   RevenueBoost      : number  — Additive multiplier added to tycoon output
--   Category          : "Equipment" | "Decoration" | "Upgrade"
--   MaxOwned          : number  — Max copies a single tycoon can own (0 = unlimited)
--   ModelAsset        : string  — Asset ID placed in the tycoon template
-- ─────────────────────────────────────────────
GameConfigs.ShopItems = {

    -- ── EARTH SHOP ──────────────────────────────
    ["BasicFryer"] = {
        DisplayName   = "Basic Fryer",
        Description   = "It fries. That's all.",
        Planet        = "Earth",
        Price         = 500,
        RevenueBoost  = 0.10,
        Category      = "Equipment",
        MaxOwned      = 1,
        ModelAsset    = "rbxassetid://0000000020",
    },
    ["NeonSignEarth"] = {
        DisplayName   = "Neon Sign",
        Description   = "Attracts customers like moths to a flame.",
        Planet        = "Earth",
        Price         = 300,
        RevenueBoost  = 0.05,
        Category      = "Decoration",
        MaxOwned      = 3,
        ModelAsset    = "rbxassetid://0000000021",
    },

    -- ── LUNA SHOP ────────────────────────────────
    ["LowGravGrill"] = {
        DisplayName   = "Low-Grav Grill",
        Description   = "Patties hover for even cooking. 15% crispier.",
        Planet        = "Luna",
        Price         = 8_000,
        RevenueBoost  = 0.20,
        Category      = "Equipment",
        MaxOwned      = 1,
        ModelAsset    = "rbxassetid://0000000022",
    },
    ["MoonDustSeasoner"] = {
        DisplayName   = "Moon Dust Seasoner",
        Description   = "Proprietary mineral blend. Customers are obsessed.",
        Planet        = "Luna",
        Price         = 4_500,
        RevenueBoost  = 0.12,
        Category      = "Upgrade",
        MaxOwned      = 2,
        ModelAsset    = "rbxassetid://0000000023",
    },

    -- ── MARS SHOP ────────────────────────────────
    ["VolcanicOven"] = {
        DisplayName   = "Volcanic Oven",
        Description   = "Geo-thermal heat. Zero electricity cost. Big revenue.",
        Planet        = "Mars",
        Price         = 40_000,
        RevenueBoost  = 0.45,
        Category      = "Equipment",
        MaxOwned      = 1,
        ModelAsset    = "rbxassetid://0000000024",
    },
    ["DustStormVentHood"] = {
        DisplayName   = "Dust-Storm Vent Hood",
        Description   = "Keeps sand out. Required for Volcanic Oven efficiency.",
        Planet        = "Mars",
        Price         = 15_000,
        RevenueBoost  = 0.10,
        Category      = "Equipment",
        MaxOwned      = 1,
        ModelAsset    = "rbxassetid://0000000025",
    },

    -- ── JUPITER SHOP ─────────────────────────────
    ["StormCoreReactor"] = {
        DisplayName   = "Storm-Core Reactor",
        Description   = "Harnesses Jupiter's eternal storm. Insane power output.",
        Planet        = "Jupiter",
        Price         = 500_000,
        RevenueBoost  = 1.50,
        Category      = "Equipment",
        MaxOwned      = 1,
        ModelAsset    = "rbxassetid://0000000026",
    },
    ["HolographicMenu"] = {
        DisplayName   = "Holographic Menu Board",
        Description   = "Customers order 30% faster. Revenue flows.",
        Planet        = "Jupiter",
        Price         = 200_000,
        RevenueBoost  = 0.30,
        Category      = "Decoration",
        MaxOwned      = 4,
        ModelAsset    = "rbxassetid://0000000027",
    },

    -- ── KEPLER-452b SHOP ─────────────────────────
    ["QuantumDeepFryer"] = {
        DisplayName   = "Quantum Deep Fryer",
        Description   = "Exists in multiple states simultaneously. Very crispy.",
        Planet        = "Kepler452b",
        Price         = 8_000_000,
        RevenueBoost  = 5.00,
        Category      = "Equipment",
        MaxOwned      = 1,
        ModelAsset    = "rbxassetid://0000000028",
    },
    ["AlienSpiceRack"] = {
        DisplayName   = "Alien Spice Rack",
        Description   = "23 spices undiscovered by science. Customers cry (good tears).",
        Planet        = "Kepler452b",
        Price         = 3_000_000,
        RevenueBoost  = 2.00,
        Category      = "Upgrade",
        MaxOwned      = 3,
        ModelAsset    = "rbxassetid://0000000029",
    },
}

-- ─────────────────────────────────────────────
-- TYCOON TEMPLATE CONFIG
-- Controls how Single-Template Instancing works.
-- ─────────────────────────────────────────────
GameConfigs.TycoonSettings = {
    TemplateName        = "TycoonTemplate",   -- Name of the template Model in ServerStorage
    BaseTickRate        = 1,                  -- Seconds between revenue ticks
    BaseRevenuePerTick  = 10,                 -- Credits earned per tick before multipliers
    MaxTycoonPerPlanet  = 10,                 -- Hard cap on spawned tycoons per planet
    PlotModelName       = "LandPlotTemplate", -- Template for purchasable land plots
}

-- ─────────────────────────────────────────────
-- TRAVEL CONSTANTS
-- ─────────────────────────────────────────────
GameConfigs.TravelSettings = {
    MinTravelTimeSeconds = 5,   -- Floor; even adjacent planets take at least this long
    FuelDeductionEnabled = true,
    LoadingScreenFadeTime = 1.5,
}

return GameConfigs
