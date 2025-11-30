local settings_accessor = require("settings_accessor")
local constants = require("constants")

-- Upvalue caching for performance (only pure Lua globals - NOT game/helpers)
local pairs = pairs
local math_floor = math.floor
local math_max = math.max

-- Storage schema version - increment when structure changes
local STORAGE_VERSION = 4

-- Forward declaration for process_tick (needed due to circular dependency with register functions)
local process_tick

local function create_fresh_storage()
  return {
    version = STORAGE_VERSION,
    surface_names = {},
    surface_index = 1,
    tick_interval = nil,
    cycle = nil
  }
end

-- Migration function: transforms old storage structures to current version
-- Safe to call multiple times - only migrates if needed
local function migrate_storage()
  local state = storage.metrics_exporter
  local version = state and state.version or 0

  if version >= STORAGE_VERSION then
    return -- already up to date
  end

  -- Any old version gets replaced with fresh structure
  -- Version 0/1: had {phase, pending} from 3-phase approach
  -- Version 2: had {surface_names, surface_index, pending, tick_interval}
  -- Version 3: has {surface_names, surface_index, tick_interval} - no pending (per-surface export)
  storage.metrics_exporter = create_fresh_storage()
end

local function collect_surface_stats(surface)
  local forces = {}

  -- Collect per-force stats so consumers can attribute production
  for _, force in pairs(game.forces) do
    local item_stats = force.get_item_production_statistics(surface)
    local fluid_stats = force.get_fluid_production_statistics(surface)

    forces[#forces + 1] = {
      force = force.name,
      items_produced = item_stats.input_counts,
      items_consumed = item_stats.output_counts,
      fluids_produced = fluid_stats.input_counts,
      fluids_consumed = fluid_stats.output_counts,
      research = {
        current = force.current_research and force.current_research.name or nil,
        progress = force.current_research and force.research_progress or 0
      }
    }
  end

  return forces
end

local function export_surface_metrics(surface_name, force_data, player_targets)
  local game_tick = game.tick

  local entry = {
    surface = surface_name,
    tick_collected = game_tick,
    timestamp = game_tick / 60,
    forces = force_data
  }

  return entry
end

-- Calculate tick interval based on surface count (only call when game is available)
local function calculate_tick_interval()
  local export_interval = settings_accessor.get_interval()

  -- Count surfaces
  local surface_count = 0
  for _ in pairs(game.surfaces) do
    surface_count = surface_count + 1
  end

  -- Divide interval by surface count so full cycle completes in ~interval ticks
  local tick_interval = math_floor(export_interval / math_max(surface_count, 1))
  if tick_interval < 60 then
    -- Clamp to at most one file per second (60 ticks)
    tick_interval = 60
  end

  return tick_interval
end

-- Register with a specific interval (used by on_load with stored value)
local function register_handler_with_interval(tick_interval)
  if tick_interval < 60 then
    tick_interval = 60
  end
  script.on_nth_tick(nil) -- clear existing handlers
  script.on_nth_tick(tick_interval, process_tick)
end

-- Full registration: calculate interval, store it, and register (requires game)
local function register_export_handler()
  local tick_interval = calculate_tick_interval()

  -- Store for on_load to use
  storage.metrics_exporter.tick_interval = tick_interval

  register_handler_with_interval(tick_interval)
end

local function get_opted_in_player_indices()
  local player_targets = {}

  for _, player in pairs(game.connected_players) do
    if settings_accessor.should_export_for_player(player) then
      player_targets[#player_targets + 1] = player.index
    end
  end

  return player_targets
end

local function export_cycle(cycle, player_targets)
  if not cycle or not cycle.surfaces or #cycle.surfaces == 0 then
    return
  end

  local data = {
    tick = cycle.completed_tick or game.tick,
    cycle_started_tick = cycle.started_tick,
    cycle_completed_tick = cycle.completed_tick,
    surfaces = cycle.surfaces,
    players = #game.connected_players
  }

  local filename = "metrics-exporter/metrics.json"
  local payload = helpers.table_to_json(data)

  -- Always write to server output
  helpers.write_file(filename, payload, false, 0)

  -- Optionally mirror to opted-in players for debugging
  player_targets = player_targets or {}
  for i = 1, #player_targets do
    helpers.write_file(filename, payload, false, player_targets[i])
  end
end

-- Main tick handler: process one surface per tick
process_tick = function()
  -- Ensure storage is migrated (idempotent - only migrates if needed)
  migrate_storage()

  -- If tick_interval wasn't set (e.g., after migration), calculate and re-register
  if not storage.metrics_exporter.tick_interval then
    register_export_handler()
  end

  local state = storage.metrics_exporter

  -- Start of new cycle: rebuild surface list from game.surfaces
  if state.surface_index == 1 then
    state.cycle = {
      started_tick = game.tick,
      surfaces = {}
    }
    state.surface_names = {}
    for name, _ in pairs(game.surfaces) do
      state.surface_names[#state.surface_names + 1] = name
    end
  end

  -- Get current surface
  local surface_name = state.surface_names[state.surface_index]
  local surface = game.surfaces[surface_name]

  -- Surface might have been deleted mid-cycle
  if surface then
    local surface_data = collect_surface_stats(surface)
    local entry = export_surface_metrics(surface_name, surface_data)
    state.cycle.surfaces[#state.cycle.surfaces + 1] = entry
  end

  -- Advance to next surface (cycle back to 1 at end)
  local surface_count = #state.surface_names
  if surface_count == 0 then
    -- Nothing to export; reset and try again next tick
    state.surface_index = 1
    state.cycle = nil
    return
  end

  if state.surface_index >= surface_count then
    state.surface_index = 1

    -- Complete cycle: write aggregated file and reset cycle
    state.cycle.completed_tick = game.tick
    local player_targets = get_opted_in_player_indices()
    export_cycle(state.cycle, player_targets)
    state.cycle = nil
  else
    state.surface_index = state.surface_index + 1
  end
end

script.on_init(function()
  storage.metrics_exporter = create_fresh_storage()
  register_export_handler()
end)

script.on_configuration_changed(function()
  migrate_storage()
  register_export_handler()
end)

script.on_load(function()
  -- Note: DO NOT access game here - it's nil during on_load!
  -- Use stored tick_interval since we can't access game.surfaces here
  local tick_interval = storage.metrics_exporter and storage.metrics_exporter.tick_interval
  if tick_interval then
    register_handler_with_interval(tick_interval)
  else
    -- Fallback: use default interval, will be corrected on first tick
    register_handler_with_interval(settings_accessor.get_interval())
  end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == constants.settings.interval then
    register_export_handler()
  end
end)

-- Re-register handler when surfaces are created/deleted to maintain correct timing
script.on_event(defines.events.on_surface_created, function()
  register_export_handler()
end)

script.on_event(defines.events.on_surface_deleted, function()
  register_export_handler()
end)
