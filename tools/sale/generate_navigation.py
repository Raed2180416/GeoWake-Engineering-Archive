#!/usr/bin/env python3
"""Index tracked paths at a pinned Git commit; never read the working tree.

This is deliberately a conservative, lexical navigation index. It does not
claim compiler-level symbol resolution, executable coverage, or runtime calls.
"""

from __future__ import annotations

import argparse
import csv
import json
import posixpath
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath


REF = "HEAD"
FEATURES = {
    "app_shell": "Flutter entry, lifecycle, navigation, theme and shared foundation",
    "localization": "Authored translation resources and generated locale accessors",
    "destination_search": "Places search, recent destinations and destination selection",
    "route_planning": "Directions retrieval, metro endpoints, polyline decoding and route request",
    "metro_data": "Metro station/line catalogs, validation and derived station data",
    "route_cache": "Route result cache, offline pinning and offline continuation",
    "route_session": "Route compilation, events, transfers, active-route registry and switching",
    "route_deviation": "Position snapping, lateral deviation and wrong-direction signals",
    "rerouting": "Remote reroute policy, constraints and termination after deviation",
    "tracking_lifecycle": "Background service, state handoff, session persistence and recovery",
    "position_sensors": "GPS provider, health, sensor and battery-aware position input",
    "ekf": "GPS-denied route-progress estimation, sensor fusion and replay",
    "reachability": "Reachability bounds and related timing physics",
    "alarm_evaluation": "Alarm thresholds, ETA, stop/distance/time decisions and event state",
    "preboarding": "Approach/boarding alert before a metro leg; cross-cutting evaluator/UI/state references",
    "alarm_delivery": "Notification, sound, vibration, exact-alarm backstop and ringtone UI",
    "permissions_reliability": "Permissions, OEM settings and arming preflight",
    "arrival": "Final alarm, teardown and post-arrival hooks",
    "saved_routes_widget": "Automatic route memory and home-screen widget quick entry",
    "journey_share_guardian": "Journey sharing, guardian and followed rides",
    "anti_theft": "Optional sensor-based anti-theft feature",
    "monetization": "Entitlements, ads, purchase handling and paywall",
    "mobility_data": "Consent-gated mobility aggregates and privacy controls",
    "telemetry": "Local/HTTP telemetry, diagnostics and report flow",
    "simulation_dashboard": "Dev dashboards, simulation, OSM testing and route replay UI",
    "backend_maps_auth": "Maps proxy, authentication, quota and server security",
    "backend_billing": "Server-side billing verification and entitlement routes",
    "backend_share": "Standalone journey-share backend service",
    "backend_aggregates": "Server aggregate ingest and merge logic",
    "website_marketing": "Separate promotional website",
    "platform_android": "Android app/project integration and resources not mapped elsewhere",
    "platform_ios": "iOS app/project integration and backstop planning",
    "platform_desktop_web": "Flutter desktop/web bootstrap and resources",
    "deployment_ci": "Deployment, CI and operational configuration",
    "data_tooling": "Scripts for metro data extraction, validation and transformation",
    "dev_tooling": "Developer automation, static indexes, lint and test infrastructure",
    "archive_package": "Archived-codebase sale checks and reproducibility tooling",
    "repository_documentation": "Cross-cutting documentation and repository guidance",
    "repository_assets": "Unparsed tracked media and supporting data",
    "unclassified": "Files whose specific subsystem cannot be established from path/import evidence",
}

CODE_SUFFIXES = {".dart", ".js", ".mjs", ".py", ".sh", ".kt", ".java", ".swift", ".cc", ".h", ".html", ".nix"}
BINARY_SUFFIXES = {".png", ".jpeg", ".jpg", ".wav", ".ogg", ".wkp", ".scip", ".svg"}
CONFIG_SUFFIXES = {".yaml", ".yml", ".toml", ".plist", ".gradle", ".properties", ".xcconfig", ".pbxproj", ".xcsettings", ".xcscheme", ".xcworkspacedata", ".storyboard", ".xib", ".entitlements", ".cmake", ".pro", ".lock", ".arb", ".xml"}
GENERATED_PATHS = {"lib/all_india_stops.dart", "lib/data/metro_line_sequences.dart"}
PREBOARDING_REFS = {
    "lib/services/alarm_evaluator.dart", "lib/services/tracking/alarm_controller.dart",
    "lib/services/tracking_state_store.dart", "lib/screens/settingsdrawer.dart",
    "lib/services/transfer_utils.dart", "test/preboarding_semantics_test.dart",
    "test/preboarding_toggle_test.dart", "test/destination_only_metro_time_test.dart",
}


def git(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *args])


def tree(repo: Path):
    raw = git(repo, "ls-tree", "-r", "-l", "-z", REF)
    rows = []
    for item in raw.split(b"\0"):
        if not item:
            continue
        meta, path = item.split(b"\t", 1)
        mode, obj_type, oid, size = meta.decode().split()
        rows.append({"path": path.decode(), "mode": mode, "object_type": obj_type,
                     "blob_oid": oid, "size_bytes": int(size) if size != "-" else None})
    return rows


def file_kind(p: str) -> str:
    suffix = PurePosixPath(p).suffix.lower()
    name = PurePosixPath(p).name
    if p.startswith(".wake/") or p.startswith(".codebase-memory/"):
        return "generated_index"
    if p.startswith("docs/Sandalsoap-whitefield/"):
        return "data"
    if p.startswith(("test/fixtures/", "assets/", "pics/", "image/")):
        return "asset" if suffix in BINARY_SUFFIXES else "data"
    if p in {"route_log_extracted.json", "repro_mumbai_alarm_trace.txt", "scripts/scraped_metro_data.json", "scripts/coverage_report.json", "scripts/extract_log.txt"} or suffix == ".csv":
        return "data"
    if name == "gradle_version.txt":
        return "config"
    if p in GENERATED_PATHS:
        return "generated_data_source"
    if suffix in {".md", ".txt"} and name not in {"gradle_version.txt"}:
        return "documentation" if suffix == ".md" else "data"
    if p.startswith(("test/", "integration_test/", "patrol_test/", "test_driver/")) and (suffix in CODE_SUFFIXES or suffix in {".yaml", ".yml"}):
        return "test"
    if name.endswith(".test.js"):
        return "test"
    if "/test/" in p or "/androidTest/" in p or "/RunnerTests/" in p:
        return "test" if suffix in CODE_SUFFIXES else "config"
    if suffix in BINARY_SUFFIXES:
        return "asset"
    if p.startswith("lib/l10n/") and suffix == ".arb":
        return "localization"
    if suffix in CODE_SUFFIXES or p.startswith((".githooks/", "autopilot/bin/")):
        return "source"
    if suffix in CONFIG_SUFFIXES or suffix in {".json", ".example"} or name in {"Dockerfile", "Caddyfile", ".gitignore", ".gitattributes", ".metadata", ".heartbeat"}:
        return "config"
    return "asset" if suffix in BINARY_SUFFIXES else "other"


def authorship(p: str, kind: str) -> str:
    name = PurePosixPath(p).name
    if kind == "generated_index" or p in GENERATED_PATHS or p == "patrol_test/test_bundle.dart" or p.startswith("lib/l10n/app_localizations") or name in {"pubspec.lock", "package-lock.json", "generated_plugins.cmake", "generated_plugin_registrant.cc", "generated_plugin_registrant.h", "GeneratedPluginRegistrant.swift"}:
        return "generated"
    if p.startswith(("android/app/src/main/res/drawable-", "android/app/src/main/res/mipmap-", "ios/Runner/Assets.xcassets/", "macos/Runner/Assets.xcassets/")):
        return "unknown"
    if kind in {"source", "test", "documentation", "localization"}:
        return "authored"
    if kind in {"data", "asset", "other"}:
        return "unknown"
    return "authored"


def execution_context(p: str, kind: str) -> str:
    if kind == "test":
        return "test"
    if kind in {"documentation", "data", "generated_index", "other"}:
        return "reference"
    if p.startswith(("lib/dashboard/", "lib/debug/", "lib/testing/", "lib/services/testing/")) or p in {"lib/main_playground.dart", "lib/main_unified_dashboard.dart", "lib/main_aggregate_dashboard.dart", "lib/simulation_engine.dart", "lib/services/simulation_client.dart"}:
        return "tooling"
    if p.startswith(("scripts/", "tools/", "autopilot/", ".githooks/", ".github/", ".vscode/", ".agent/", ".claude/", "deploy/")):
        return "tooling"
    if p.startswith(("lib/", "android/app/src/main/", "ios/Runner/", "linux/runner/", "macos/Runner/", "web/", "website/", "backend/share/server.js", "geowake-server/src/", "packages/wakepoint_native/lib/", "packages/wakepoint_native/android/src/")):
        return "runtime"
    if p.startswith(("geowake-server/", "backend/", "android/", "ios/", "linux/", "macos/", "packages/")):
        return "tooling"
    return "tooling" if kind == "config" else "reference"


def choose_test_feature(p: str):
    s = p.lower()
    exact = {
        "integration_test/backstop_doze_ondevice_test.dart": "alarm_delivery",
        "patrol_test/test_bundle.dart": "alarm_delivery",
        "test/comprehensive_real_world_scenarios_test.dart": "alarm_evaluation",
        "test/direction_service_behavior_test.dart": "route_planning",
        "test/driving_coalesce_test.dart": "route_session",
        "test/flutter_test_config.dart": "dev_tooling",
        "test/integration/lifecycle_restore_scenario_test.dart": "tracking_lifecycle",
        "test/log_helper.dart": "dev_tooling",
        "test/maestro/persona_arm.yaml": "tracking_lifecycle",
        "test/maestro/persona_critic_tour.yaml": "app_shell",
        "test/maestro/persona_firsttime.yaml": "permissions_reliability",
        "test/maestro/persona_redteam_deeplink.yaml": "journey_share_guardian",
        "test/minimal_test.dart": "dev_tooling",
        "test/mixed_mode_regression_test.dart": "route_session",
        "test/regression_prod_data_test.dart": "alarm_evaluation",
        "test/report_problem_screen_test.dart": "telemetry",
        "test/route_journey_fixes_test.dart": "route_session",
        "test/services/background_handlers_ack_test.dart": "tracking_lifecycle",
        "test/services/projection_correction_test.dart": "route_deviation",
        "test/simplified_polyline_present_test.dart": "route_planning",
        "test/soft_lock_manager_test.dart": "route_deviation",
        "test/tool_fetch_route.dart": "route_planning",
        "test_driver/integration_test.dart": "dev_tooling",
    }
    if p in exact:
        return exact[p], "explicit_test_review"
    directory_rules = [
        ("/core/ekf/", "ekf"), ("/ekf/", "ekf"), ("/ekf_integration/", "ekf"),
        ("/reachability/", "reachability"), ("/scale/", "reachability"),
        ("/monetization/", "monetization"), ("/data_asset/", "mobility_data"),
        ("/share/", "journey_share_guardian"), ("/telemetry/", "telemetry"),
        ("/widget/", "saved_routes_widget"), ("/dashboard/", "simulation_dashboard"),
        ("/reliability/", "permissions_reliability"), ("/ios/", "platform_ios"),
        ("/services/testing/", "simulation_dashboard"), ("/core/clock/", "app_shell"),
    ]
    for needle, feature in directory_rules:
        if needle in s:
            return feature, "test_directory"
    rules = [
        (r"preboard|boarding", "preboarding"),
        (r"reachability|never_late|vline|dwell_cap|fractile", "reachability"),
        (r"ekf|sensor_fusion|gps_recovery|station_association|zupt|imu|tilt", "ekf"),
        (r"monetiz|premium|paywall|purchase|post_arrival_interstitial|ad_policy|pass_ladder", "monetization"),
        (r"consent|data_asset|dp_and|kanon|aggregate|station_binner", "mobility_data"),
        (r"guardian|share|followed_ride", "journey_share_guardian"),
        (r"anti_theft", "anti_theft"),
        (r"saved_route|home_widget|widget_field|recent_route", "saved_routes_widget"),
        (r"route_cache|offline|direction_service_caching", "route_cache"),
        (r"place|recent_location|destination_only", "destination_search"),
        (r"reroute|termination", "rerouting"),
        (r"deviation|wrong_snap|snap_to_route|polyline_projection|polyline_simplifier", "route_deviation"),
        (r"route_registry|active_route|route_session|route_event|switch_point|transfer|segment_builder|transit_leg|route_continuity", "route_session"),
        (r"notification|alarm_player|alarm_haptic|ringtone", "alarm_delivery"),
        (r"alarm|sound|haptic|stop_logic|stop_match|eta|time_mode|stops_prior|stops_mode", "alarm_evaluation"),
        (r"tracking|process_death|persistence|pending_ack|shared_prefs_reload|power_policy", "tracking_lifecycle"),
        (r"location|gps_health|position", "position_sensors"),
        (r"metro|station|vehicle_type", "metro_data"),
        (r"arrival|post_arrival", "arrival"),
        (r"permission|preflight|reliability", "permissions_reliability"),
        (r"dashboard|playground|simulation|mock|test_routes|test_service|harness|repro|debug|bug_repro|compare_routes", "simulation_dashboard"),
        (r"app_config|clock|navigation|maptracking|home|splash|theme", "app_shell"),
        (r"auth|maps|cost_protection|token_issuance", "backend_maps_auth"),
        (r"billing", "backend_billing"),
    ]
    for pattern, feature in rules:
        if re.search(pattern, s):
            return feature, "test_filename"
    return "unclassified", "test_no_path_match"


def choose_feature(p: str, kind: str):
    if p.startswith("evaluation/"):
        return "archive_package", "explicit historical evaluation artifact"
    s = p.lower()
    name = PurePosixPath(p).stem.lower()
    if kind == "test":
        if p.startswith("backend/share/"):
            return "backend_share", "backend_test_path"
        if p.startswith("geowake-server/"):
            if "billing" in name:
                return "backend_billing", "backend_test_name"
            if "aggregate" in name:
                return "backend_aggregates", "backend_test_name"
            return "backend_maps_auth", "backend_test_path"
        if p.startswith("android/"):
            return "platform_android", "platform_test_path"
        if p.startswith(("ios/", "macos/")):
            return "platform_ios" if p.startswith("ios/") else "platform_desktop_web", "platform_test_path"
        return choose_test_feature(p)
    if p in PREBOARDING_REFS and kind != "test":
        # These have broader primary owners; preboarding is a secondary feature.
        pass
    if p.startswith("lib/"):
        if p.startswith("lib/l10n/"): return "localization", "lib_directory"
        if p.startswith(("lib/core/ekf/",)): return "ekf", "lib_directory"
        if p.startswith("lib/core/reachability/"): return "reachability", "lib_directory"
        if p.startswith(("lib/dashboard/", "lib/debug/", "lib/testing/", "lib/services/testing/")) or name.startswith("main_") or p in {"lib/simulation_engine.dart", "lib/services/simulation_client.dart", "lib/services/test_service_instance.dart"}: return "simulation_dashboard", "lib_directory_or_name"
        if p.startswith("lib/services/data_asset/") or "mobility_data_consent" in p: return "mobility_data", "lib_directory_or_name"
        if p.startswith("lib/services/monetization/") or "/monetization/" in p or "gated_banner_ad" in p or "pro_gate" in p: return "monetization", "lib_directory_or_name"
        if p.startswith("lib/services/share/") or "/share/" in p or any(x in name for x in ("guardian", "friends_rides")): return "journey_share_guardian", "lib_directory_or_name"
        if p.startswith("lib/services/telemetry/") or "report_problem" in p: return "telemetry", "lib_directory_or_name"
        if p.startswith("lib/services/widget/") or "/widget/" in p or name.startswith("saved_route"): return "saved_routes_widget", "lib_directory_or_name"
        if "anti_theft" in p: return "anti_theft", "lib_filename"
        if p.startswith("lib/services/position/") or name in {"location_manager", "gps_health_monitor"}: return "position_sensors", "lib_directory_or_name"
        if p.startswith("lib/services/reliability/") or name in {"permission_service", "oem_autostart_service"}: return "permissions_reliability", "lib_directory_or_name"
        if name in {"route_cache", "offline_coordinator"}: return "route_cache", "lib_filename"
        if name in {"places_service", "recent_locations_service"}: return "destination_search", "lib_filename"
        if name in {"direction_service", "polyline_decoder", "polyline_simplifier", "preload_map_screen"}: return "route_planning", "lib_filename"
        if name in {"metro_stop_service", "metro_vehicle_types", "all_india_stops", "metro_line_sequences", "metro_color_map"}: return "metro_data", "lib_filename"
        if name in {"deviation_detection", "deviation_monitor", "snap_to_route", "soft_lock_manager"} or name == "deviation_config": return "route_deviation", "lib_filename"
        if name in {"reroute_policy", "reroute_constraints", "tracking_termination_policy"}: return "rerouting", "lib_filename"
        if name in {"sensor_fusion"}: return "ekf", "lib_filename"
        if name in {"alarm_evaluator", "alarm_threshold_validator", "eta_engine", "eta_utils", "stop_logic_engine", "stop_matcher", "fire_decision_config", "alarm_context_builder", "alarm_controller"}: return "alarm_evaluation", "lib_filename"
        if name in {"notification_service", "notification_updater", "alarm_player", "alarm_haptics", "ringtones_screen", "ios_backstop_planner"}: return "alarm_delivery", "lib_filename"
        if name in {"arrival_hooks", "post_arrival_screen", "post_arrival_card"}: return "arrival", "lib_filename"
        if name in {"active_route_manager", "route_registry", "route_session_manager", "route_queue", "route_logger", "transfer_utils", "route_models"}: return "route_session", "lib_filename"
        if name in {"trackingservice", "tracking_state_store", "tracking_recovery_policy", "pending_ack_manager", "soft_lock_manager", "tracking", "background_handlers", "foreground_bridge", "heartbeat_monitor", "location_stream_handler", "snapshot_route_restorer", "post_alarm_multicast", "maptracking"} or p.startswith("lib/services/tracking/"): return "tracking_lifecycle", "lib_filename_or_directory"
        if name in {"homescreen"}: return "destination_search", "lib_filename"
        if name in {"settingsdrawer"}: return "app_shell", "lib_filename"
        if name in {"api_client", "app_config"}: return "backend_maps_auth", "lib_filename"
        if name in {"power_policy"}: return "position_sensors", "lib_filename"
        if name in {"test_mode_flag", "playground_bridge", "platform_test_flag_io", "platform_test_flag_stub"}: return "simulation_dashboard", "lib_filename"
        if p.startswith(("lib/core/clock/", "lib/core/logging/", "lib/themes/")) or name in {"main", "splash_screen", "navigation_service", "appthemes", "pulsing_dots"}: return "app_shell", "lib_directory_or_name"
        return "unclassified", "lib_no_path_match"
    if p.startswith("geowake-server/"):
        if "billing" in s or "playbilling" in s: return "backend_billing", "backend_path"
        if "aggregate" in s or "mergeengine" in s: return "backend_aggregates", "backend_path"
        return "backend_maps_auth", "backend_path"
    if p.startswith("backend/share/"): return "backend_share", "backend_path"
    if p.startswith("website/"): return "website_marketing", "website_path"
    if p.startswith("android/"):
        if "alarmreceiver" in s or "notificationchannels" in s: return "alarm_delivery", "android_filename"
        if "widget" in s: return "saved_routes_widget", "android_filename"
        return "platform_android", "android_path"
    if p.startswith("ios/"): return "platform_ios", "ios_path"
    if p.startswith(("linux/", "macos/", "web/")): return "platform_desktop_web", "platform_path"
    if p.startswith("packages/wakepoint_native/"): return "alarm_delivery", "native_plugin_path"
    if p.startswith("assets/"):
        if "ringtones" in s: return "alarm_delivery", "asset_path"
        if "india_metro" in s: return "metro_data", "asset_path"
        if "ekf_test_routes" in s: return "ekf", "asset_path"
        if "osm" in s: return "simulation_dashboard", "asset_path"
        return "app_shell", "asset_path"
    if p.startswith("test/fixtures/"):
        if "replay" in s or "scale" in s or "imu" in s or "rail_geometry" in s: return "ekf", "fixture_path"
        return "repository_assets", "fixture_path"
    if p.startswith("scripts/"):
        if "coverage" in s or "headers" in s: return "dev_tooling", "script_filename"
        return "data_tooling", "script_path"
    if p.startswith("tools/sale/"): return "archive_package", "tool_path"
    if p.startswith("tools/"):
        if "replay" in s: return "ekf", "tool_filename"
        if "metro" in s: return "metro_data", "tool_filename"
        return "dev_tooling", "tool_path"
    if p.startswith(("autopilot/", ".wake/", ".codebase-memory/", ".githooks/", ".vscode/", ".agent/", ".claude/")): return "dev_tooling", "tooling_path"
    if p.startswith((".github/", "deploy/")): return "deployment_ci", "deployment_path"
    if p.startswith("docs/sale/"): return "archive_package", "sale_doc_path"
    if p.startswith("docs/Sandalsoap-whitefield/"): return "repository_assets", "recording_path"
    if p.startswith("docs/"):
        if "research/underground" in s or "/ekf" in s: return "ekf", "doc_path"
        if "monet" in s or "pricing" in s: return "monetization", "doc_path"
        if "backend" in s: return "backend_maps_auth", "doc_path"
        if "testing" in s: return "dev_tooling", "doc_path"
        return "repository_documentation", "doc_path"
    if p.startswith(("pics/", "image/")): return "repository_assets", "asset_path"
    if p in {"pubspec.yaml", "pubspec.lock", "l10n.yaml"}: return "app_shell" if p != "l10n.yaml" else "localization", "root_config"
    if p in {"package.json", "package-lock.json", "analysis_options.yaml", "devtools_options.yaml", "qodana.yaml", "shell.nix", ".semgrep.yml", ".gitleaks.toml", ".mcp.json"}: return "dev_tooling", "root_config"
    if p in {".env.example", "gradle.properties"}: return "deployment_ci", "root_config"
    if p in {"route_log_extracted.json", "repro_mumbai_alarm_trace.txt"}: return "ekf" if p.startswith("route_") else "alarm_evaluation", "root_data"
    if PurePosixPath(p).suffix == ".md": return "repository_documentation", "root_doc"
    if p.startswith("."): return "dev_tooling", "root_dotfile"
    return "unclassified", "no_path_match"


def secondaries(p: str, primary: str):
    ans = set()
    if p in PREBOARDING_REFS and primary != "preboarding": ans.add("preboarding")
    if p in {"lib/screens/homescreen.dart", "lib/screens/settingsdrawer.dart"}: ans.update({"alarm_evaluation", "tracking_lifecycle", "permissions_reliability", "saved_routes_widget"})
    if p == "lib/screens/maptracking.dart": ans.update({"arrival", "alarm_delivery", "route_session"})
    if p == "lib/services/trackingservice.dart": ans.update({"alarm_evaluation", "route_deviation", "rerouting", "reachability", "alarm_delivery"})
    if p == "lib/services/transfer_utils.dart": ans.update({"alarm_evaluation", "metro_data"})
    if p == "lib/services/active_route_manager.dart": ans.add("route_deviation")
    if p == "lib/services/direction_service.dart": ans.add("route_cache")
    if p == "lib/services/tracking/location_stream_handler.dart": ans.update({"position_sensors", "ekf"})
    if p == "lib/services/tracking/alarm_controller.dart": ans.update({"alarm_delivery", "reachability"})
    if p == "lib/services/notification_service.dart": ans.add("permissions_reliability")
    if p == "lib/main.dart": ans.update({"tracking_lifecycle", "monetization", "mobility_data", "journey_share_guardian"})
    ans.discard(primary)
    return sorted(ans)


def language(p: str):
    suffix = PurePosixPath(p).suffix.lower()
    return {".dart":"Dart", ".js":"JavaScript", ".mjs":"JavaScript", ".py":"Python", ".kt":"Kotlin", ".java":"Java", ".swift":"Swift", ".cc":"C++", ".h":"C/C++", ".sh":"Shell", ".html":"HTML", ".nix":"Nix", ".gradle":"Gradle", ".xml":"XML", ".yaml":"YAML", ".yml":"YAML", ".json":"JSON", ".arb":"ARB"}.get(suffix, "")


def symbols(p: str, text: str):
    lang = language(p)
    if lang not in {"Dart", "JavaScript", "Python", "Kotlin", "Java", "Swift", "C++", "C/C++", "Shell"}:
        return []
    out = []
    for line_no, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith(("//", "#", "*", "/*")):
            continue
        match = None
        kind = None
        if lang == "Dart":
            match = re.match(r"^\s*(?:(?:abstract|base|final|sealed|interface)\s+)?(class|enum|mixin|extension|typedef)\s+(\w+)", line)
            if match:
                kind, name = match.group(1), match.group(2)
            else:
                match = re.match(r"^ {0,2}(?:(?:static|external|factory|const)\s+)*(?:[A-Za-z_]\w*(?:<[^(){};=]+>)?[?]?|void)\s+(_?\w+)\s*\(", line)
                control_heads = {"return", "if", "for", "while", "switch", "throw", "await", "yield", "else", "case", "assert", "try", "catch", "new", "required", "final", "var", "const"}
                first_word = re.match(r"\s*(\w+)", line)
                if match and (not first_word or first_word.group(1) not in control_heads):
                    kind, name = "callable_candidate", match.group(1)
                else:
                    match = re.search(r"\b(test|testWidgets|group)\s*\(\s*['\"]([^'\"]{1,160})['\"]", line) if p.startswith(("test/", "integration_test/")) else None
                    if match: kind, name = "test_label", match.group(2)
        elif lang == "Python":
            match = re.match(r"^\s*(async\s+def|def|class)\s+(\w+)", line)
            if match: kind, name = match.group(1).replace(" ", "_"), match.group(2)
        elif lang == "JavaScript":
            match = re.match(r"^\s*(?:export\s+(?:default\s+)?)?(?:async\s+)?(function|class)\s+(\w+)", line)
            if match: kind, name = match.group(1), match.group(2)
            else:
                match = re.match(r"^(?:export\s+)?(?:const|let)\s+(\w+)\s*=", line)
                if match: kind, name = "binding_candidate", match.group(1)
        elif lang in {"Kotlin", "Java", "Swift"}:
            match = re.search(r"\b(class|interface|enum|object|struct|protocol|fun|func)\s+(\w+)", line)
            if match: kind, name = match.group(1), match.group(2)
        elif lang in {"C++", "C/C++"}:
            match = re.match(r"^\s*(?:class|struct)\s+(\w+)", line)
            if match: kind, name = "type_candidate", match.group(1)
            else:
                match = re.match(r"^\s*(?:[\w:*<>]+\s+)+([\w:]+)\s*\([^;]*\)\s*\{?", line)
                if match: kind, name = "callable_candidate", match.group(1)
        elif lang == "Shell":
            match = re.match(r"^\s*(?:function\s+)?([\w-]+)\s*\(\)\s*\{", line)
            if match: kind, name = "function", match.group(1)
        if match:
            out.append({"path": p, "line": line_no, "symbol": name, "kind": kind,
                        "language": lang, "extraction": "regex_candidate"})
    return out


def local_target(p: str, spec: str, paths: set[str], lang: str):
    if lang == "Dart" and spec.startswith("package:geowake2/"):
        candidate = "lib/" + spec[len("package:geowake2/"):]
        return candidate if candidate in paths else None, "first_party_package"
    if lang == "Dart" and spec.startswith("package:wakepoint_native/"):
        candidate = "packages/wakepoint_native/lib/" + spec[len("package:wakepoint_native/"):]
        return candidate if candidate in paths else None, "first_party_package"
    if lang in {"C++", "C/C++", "HTML"} and not spec.startswith(("http:", "https:", "data:", "//", "#", "/")):
        clean = spec.split("?", 1)[0].split("#", 1)[0]
        candidates = [posixpath.normpath(posixpath.join(posixpath.dirname(p), clean))]
        if lang in {"C++", "C/C++"}:
            candidates.append(posixpath.normpath(posixpath.join(p.split("/", 1)[0], clean)))
        for candidate in candidates:
            if candidate in paths: return candidate, "quoted_relative_asset_or_include"
        return None, "external_or_dynamic"
    if spec.startswith("./") or spec.startswith("../") or (lang == "Dart" and ":" not in spec):
        candidate = posixpath.normpath(posixpath.join(posixpath.dirname(p), spec))
        possibilities = [candidate]
        if lang == "JavaScript": possibilities += [candidate + ".js", candidate + ".mjs", candidate + "/index.js", candidate + ".json"]
        if lang == "Python": possibilities += [candidate + ".py", candidate + "/__init__.py"]
        for target in possibilities:
            if target in paths: return target, "relative"
        return None, "missing_relative"
    return None, "external_or_dynamic"


def dependencies(p: str, text: str, paths: set[str]):
    lang = language(p)
    found = []
    for line_no, line in enumerate(text.splitlines(), 1):
        if lang == "Dart":
            head = re.match(r"^\s*(import|export|part)\s+['\"]([^'\"]+)['\"]", line)
            if head:
                specs = [(head.group(1), head.group(2))]
                for more in re.findall(r"\bif\s*\([^)]*\)\s*['\"]([^'\"]+)['\"]", line): specs.append(("conditional_import", more))
            else: specs = []
        elif lang == "JavaScript":
            specs = [("require", x) for x in re.findall(r"\brequire\s*\(\s*['\"]([^'\"]+)['\"]", line)]
            specs += [("import", x) for x in re.findall(r"\b(?:import|export)\b(?:[^;]*?\bfrom\s*)?['\"]([^'\"]+)['\"]", line)]
        elif lang == "Python":
            m = re.match(r"^\s*from\s+([.\w]+)\s+import\b", line)
            specs = [("from_import", m.group(1))] if m else []
            m = re.match(r"^\s*import\s+([.\w]+)", line)
            if m: specs.append(("import", m.group(1)))
        elif lang in {"C++", "C/C++"}:
            specs = [("include", x) for x in re.findall(r"^\s*#include\s+\"([^\"]+)\"", line)]
        elif lang == "Shell":
            specs = [("source", x) for x in re.findall(r"^\s*(?:source|\.)\s+(['\"]?[^\s'\"]+['\"]?)", line)]
        elif lang == "HTML":
            specs = [("asset_reference", x) for x in re.findall(r"\b(?:src|href)\s*=\s*['\"]([^'\"]+)['\"]", line)]
        else:
            specs = []
        for relation, spec in specs:
            if lang == "Python":
                # Only explicit relative Python imports are treated as local.
                if spec.startswith("."):
                    base = posixpath.dirname(p)
                    dots = len(spec) - len(spec.lstrip("."))
                    for _ in range(max(0, dots - 1)): base = posixpath.dirname(base)
                    rest = spec[dots:].replace(".", "/")
                    candidate = posixpath.join(base, rest)
                    to = next((x for x in (candidate + ".py", candidate + "/__init__.py") if x in paths), None)
                    basis = "python_relative" if to else "missing_relative"
                else: to, basis = None, "external_or_dynamic"
            else:
                to, basis = local_target(p, spec.strip("'\""), paths, lang)
            if to or basis in {"missing_relative", "first_party_package"}:
                found.append({"from_path": p, "line": line_no, "relation": relation,
                              "specifier": spec, "to_path": to or "",
                              "resolution": "local" if to else "unresolved_local",
                              "basis": basis})
    return found


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]):
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main():
    global REF
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=Path, default=Path.cwd())
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--ref", default="HEAD")
    args = ap.parse_args()
    repo = args.repo
    REF = git(repo, "rev-parse", args.ref + "^{commit}").decode().strip()
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    assert git(repo, "rev-parse", REF).decode().strip() == REF
    rows = tree(repo)
    paths = {r["path"] for r in rows}
    all_symbols = []
    all_edges = []
    for r in rows:
        p = r["path"]
        kind = file_kind(p)
        primary, basis = choose_feature(p, kind)
        secondary = secondaries(p, primary)
        r.update({"kind": kind, "language": language(p),
                  "generated_vs_authored": authorship(p, kind),
                  "runtime_vs_tooling": execution_context(p, kind),
                  "primary_feature": primary, "secondary_features": "|".join(secondary),
                  "classification_basis": basis})
        # Do not read dataset, media, documentation or generated-index contents.
        r["test_role"] = ""
        if kind in {"source", "test"} and r["language"] in {"Dart", "JavaScript", "Python", "Kotlin", "Java", "Swift", "C++", "C/C++", "Shell", "HTML"}:
            try:
                text = git(repo, "show", f"{REF}:{p}").decode("utf-8", errors="replace")
            except subprocess.CalledProcessError:
                text = ""
            all_symbols += symbols(p, text)
            all_edges += dependencies(p, text, paths)
            if kind == "test":
                if "placeholder - " in text and "expect(true, isTrue)" in text:
                    r["test_role"] = "placeholder"
                elif p == "test/ekf/underground_drift_probe_test.dart":
                    r["test_role"] = "diagnostic_probe"
                elif p.startswith("test/maestro/"):
                    r["test_role"] = "ui_scenario"
                elif p in {"test/flutter_test_config.dart", "test/log_helper.dart", "test/test_routes.dart", "test/mock_location_provider.dart", "test/helpers/ekf_test_helpers.dart", "geowake-server/test/setup-env.js", "test_driver/integration_test.dart"}:
                    r["test_role"] = "test_helper_or_driver"
                else:
                    r["test_role"] = "test_or_support"
        elif kind == "test" and p.startswith("test/maestro/"):
            r["test_role"] = "ui_scenario"
    all_symbols.sort(key=lambda x: (x["path"], x["line"], x["kind"], x["symbol"]))
    all_edges.sort(key=lambda x: (x["from_path"], x["line"], x["relation"], x["specifier"]))
    by_path = {r["path"]: r for r in rows}
    tests_for_source = defaultdict(set)
    sources_for_test = defaultdict(set)
    matches = set()
    for e in all_edges:
        if e["resolution"] != "local": continue
        src, dst = e["from_path"], e["to_path"]
        if by_path[src]["kind"] == "test" and by_path[dst]["kind"] in {"source", "generated_data_source"}:
            tests_for_source[dst].add(src)
            sources_for_test[src].add(dst)
            matches.add((src, dst, "direct_static_import"))
    # Filename match adds a navigation hint, not a claim that a test executes code.
    for t in (r for r in rows if r["kind"] == "test"):
        stem = PurePosixPath(t["path"]).stem
        if stem.endswith("_test"):
            base = stem[:-5]
            candidates = [s["path"] for s in rows if s["kind"] in {"source", "generated_data_source"} and PurePosixPath(s["path"]).stem == base]
            for src in candidates:
                tests_for_source[src].add(t["path"])
                sources_for_test[t["path"]].add(src)
                matches.add((t["path"], src, "exact_basename_hint"))
    sym_count = Counter(s["path"] for s in all_symbols)
    edge_count = Counter(e["from_path"] for e in all_edges if e["resolution"] == "local")
    for r in rows:
        p = r["path"]
        r["matched_test_paths"] = "|".join(sorted(tests_for_source[p]))
        r["matched_source_paths"] = "|".join(sorted(sources_for_test[p]))
        r["symbol_count"] = sym_count[p]
        r["resolved_local_dependency_count"] = edge_count[p]
        r["content_inspected"] = "yes" if r["kind"] in {"source", "test"} and r["language"] in {"Dart", "JavaScript", "Python", "Kotlin", "Java", "Swift", "C++", "C/C++", "Shell", "HTML"} else "no"
    features = []
    for key, description in FEATURES.items():
        own = [r for r in rows if r["primary_feature"] == key]
        cross = [r["path"] for r in rows if key in r["secondary_features"].split("|")]
        features.append({"id": key, "name": key.replace("_", " ").title(), "description": description,
                         "source_paths": [r["path"] for r in own if r["kind"] in {"source", "generated_data_source"}],
                         "test_paths": [r["path"] for r in own if r["kind"] == "test"],
                         "support_paths": [r["path"] for r in own if r["kind"] not in {"source", "generated_data_source", "test"}],
                         "cross_reference_paths": cross})
    write_csv(out / "files.csv", ["path", "mode", "object_type", "blob_oid", "size_bytes", "kind", "language", "generated_vs_authored", "runtime_vs_tooling", "primary_feature", "secondary_features", "classification_basis", "matched_test_paths", "matched_source_paths", "test_role", "symbol_count", "resolved_local_dependency_count", "content_inspected"], rows)
    write_csv(out / "symbols.csv", ["path", "line", "symbol", "kind", "language", "extraction"], all_symbols)
    write_csv(out / "dependencies.csv", ["from_path", "line", "relation", "specifier", "to_path", "resolution", "basis"], all_edges)
    write_csv(out / "test_matches.csv", ["test_path", "source_path", "match_basis"],
              [{"test_path": t, "source_path": s, "match_basis": basis} for t, s, basis in sorted(matches)])
    (out / "features.json").write_text(json.dumps({"pinned_commit": REF, "features": features}, ensure_ascii=False, indent=2) + "\n")
    summary = {"tracked_paths": len(rows), "file_kinds": dict(Counter(r["kind"] for r in rows)),
               "symbols": len(all_symbols), "dependency_edges": len(all_edges),
               "resolved_local_edges": sum(e["resolution"] == "local" for e in all_edges),
               "unresolved_local_edges": sum(e["resolution"] == "unresolved_local" for e in all_edges),
               "test_match_rows": len(matches),
               "test_roles": dict(Counter(r["test_role"] for r in rows if r["kind"] == "test")),
               "unclassified_paths": [r["path"] for r in rows if r["primary_feature"] == "unclassified"],
               "unmatched_test_paths": [r["path"] for r in rows if r["kind"] == "test" and not r["matched_source_paths"]]}
    (out / "counts.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({k: v for k, v in summary.items() if not isinstance(v, list)}, indent=2))
    print("unclassified:", summary["unclassified_paths"])
    print("unmatched_tests:", len(summary["unmatched_test_paths"]))


if __name__ == "__main__":
    main()
