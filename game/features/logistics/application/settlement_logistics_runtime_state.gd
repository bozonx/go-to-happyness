class_name SettlementLogisticsRuntimeState
extends RefCounted

## Mutable coordination state shared by logistics and citizen-arrival services.
## It is deliberately owned by the logistics feature, rather than by the root
## scene controller, so bootstrap only composes the services that use it.

var pending_arrivals: Array[Dictionary] = []
var arrival_greeters: Dictionary[int, Dictionary] = {}
var arrival_waiting_greeters: Dictionary[int, Dictionary] = {}
var arrival_escort_ids: Dictionary[int, bool] = {}

## worker ai_id -> TradeOrder. Kept RefCounted until TradeOrder becomes a
## global typed annotation in all supported Godot import paths.
var pending_trades: Dictionary[int, RefCounted] = {}
var queued_trades: Array[RefCounted] = []
