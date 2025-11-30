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

  -- Item production statistics
  for name, count in pairs(force.item_production_statistics.input_counts) do
    data.items.produced[name] = count
  end
  for name, count in pairs(force.item_production_statistics.output_counts) do
    data.items.consumed[name] = count
  end

  -- Fluid production statistics
  for name, count in pairs(force.fluid_production_statistics.input_counts) do
    data.fluids.produced[name] = count
  end
  for name, count in pairs(force.fluid_production_statistics.output_counts) do
    data.fluids.consumed[name] = count
  end

  -- Research progress
  if force.current_research then
    data.research.current = force.current_research.name
    data.research.progress = force.research_progress
  end

  game.write_file(
    "factorio-metrics-exporter/metrics.json",
    helpers.table_to_json(data),
    false,
    0
  )
end

script.on_init(function()
  storage.metrics_exporter = {}
end)

script.on_configuration_changed(function(data)
  storage.metrics_exporter = storage.metrics_exporter or {}
end)

local function register_export_handler()
  local interval = settings.global["factorio-metrics-exporter-interval"].value
  script.on_nth_tick(nil)
  script.on_nth_tick(interval, function(event)
    export_metrics()
  end)
end

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "factorio-metrics-exporter-interval" then
    register_export_handler()
  end
end)

script.on_load(function()
  register_export_handler()
end)

script.on_init(function()
  storage.metrics_exporter = {}
  register_export_handler()
end)
