extends Node
## Analytics stub: records structured gameplay events in memory and echoes
## them to stdout. No SDK — later an exporter can flush `events` to any
## backend without gameplay code changes.

var events: Array[Dictionary] = []


func log_event(event_name: String, data: Dictionary = {}) -> void:
	var entry := {
		"t_ms": Time.get_ticks_msec(),
		"event": event_name,
		"data": data,
	}
	events.append(entry)
	print("[Analytics] ", event_name, " ", JSON.stringify(data))
