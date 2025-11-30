local settings_accessor = require("settings_accessor")

local function export_metrics()
  local data = {
    tick = game.tick,
    timestamp = game.tick / 60,
    items = {
      produced = {},
      consumed = {}
    },
    fluids = {
      produced = {},
      consumed = {}
    },
    research = {
      current = nil,
      progress = 0
    },
    players = #game.connected_players
  }

  local force = game.forces["player"]

  -- Collect stats from all surfaces
  for _, surface in pairs(game.surfaces) do
    local item_stats = force.get_item_production_statistics(surface)
    for name, count in pairs(item_stats.input_counts) do
      data.items.produced[name] = (data.items.produced[name] or 0) + count
    end
    for name, count in pairs(item_stats.output_counts) do
      data.items.consumed[name] = (data.items.consumed[name] or 0) + count
    end

    local fluid_stats = force.get_fluid_production_statistics(surface)
    for name, count in pairs(fluid_stats.input_counts) do
      data.fluids.produced[name] = (data.fluids.produced[name] or 0) + count
    end
    for name, count in pairs(fluid_stats.output_counts) do
      data.fluids.consumed[name] = (data.fluids.consumed[name] or 0) + count
    end
  end

  -- Research progress
  if force.current_research then
    data.research.current = force.current_research.name
    data.research.progress = force.research_progress
  end

  helpers.write_file(
    "factorio-metrics-exporter/metrics.json",
    helpers.table_to_json(data),
    false,
    0
  )
end

local function register_export_handler()
  local interval = settings_accessor.get_interval()
  script.on_nth_tick(nil) -- clear existing handlers to prevent duplicates
  script.on_nth_tick(interval, function(event)
    export_metrics()
  end)
end

script.on_init(function()
  storage.metrics_exporter = {}
  register_export_handler()
end)

script.on_configuration_changed(function(data)
  storage.metrics_exporter = storage.metrics_exporter or {}
end)

script.on_load(function()
  register_export_handler()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "factorio-metrics-exporter-interval" then
    register_export_handler()
  end
end)
