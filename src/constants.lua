return {
  settings = {
    interval = "metrics-exporter-interval",
    per_player = "metrics-exporter-per-player"
  },
  files = {
    metrics = "metrics-exporter/metrics.jsonl"
  },
  limits = {
    slice_size = 200,
    slices_per_tick = 1
  }
}
