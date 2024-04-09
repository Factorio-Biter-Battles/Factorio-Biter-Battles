#!/usr/bin/env bash
# Script to run a benchmark on the factorio biter battles scenario
# Workflow:
# 1. Modify the scenario to modify control.lua to require the benchmark code
# 2. Convert the scenario to a save
# 3. Run the benchmark on the new save
# Notes:
#   Consider: Disabling the profiler (comment out the line in benchmark.lua) and just looking at raw execute time.

if [ $# -eq 0 ]; then
	echo "Usage: $0 <factorio data directory> <factorio executable> <scenario to benchmark directory> <output log file>"
	echo "Example: ./benchmarking/run_benchmark.sh \"/Users/abiter/Library/Application Support/factorio\" /Applications/factorio.app/Contents/MacOS/factorio /Users/abiter/git/Factorio-Biter-Battes benchmark.log"
	exit 1
fi
FACTORIO_DATA_DIR="$1"
FACTORIO_EXE="$2"
SCENARIO_TO_BENCHMARK_DIRECTORY="$3"
OUTPUT_LOG_FILE="$4"

mkdir -p .trash

SCENARIO_RANDOM_NAME=$(openssl rand -base64 10 | tr -dc 'a-zA-Z' | head -c 5)
HARDCODED_PRIMED_SCENARIO_NAME=abcdefg
HARDCODED_SAVE_TEXT="Saving finished"

if [ -n "$SCENARIO_RANDOM_NAME" ]; then
	echo "Random scenario name: $SCENARIO_RANDOM_NAME"
	SCENARIO_FACTORIO_DATA_PATH="${FACTORIO_DATA_DIR}/scenarios/${SCENARIO_RANDOM_NAME}"
	cp -r "$SCENARIO_TO_BENCHMARK_DIRECTORY" "$SCENARIO_FACTORIO_DATA_PATH" || exit 1
	old_text="local BENCHMARKING_ENABLED = false"
	new_text="local BENCHMARKING_ENABLED = true"
	CONTROL_FILE="$SCENARIO_FACTORIO_DATA_PATH/control.lua"
	sed -i.bak "s|$old_text|$new_text|g" "$CONTROL_FILE" || exit 1
	rm "$CONTROL_FILE".bak || exit 1
	"$FACTORIO_EXE" --scenario2map "$SCENARIO_RANDOM_NAME" || exit 1
	echo "made scenario"
	mkfifo factorio_output_pipe
	"$FACTORIO_EXE" --start-server-load-latest "$SCENARIO_RANDOM_NAME" --disable-audio --server-settings benchmarking/server-settings.json >factorio_output_pipe &
	command_pid=$!
	while IFS= read -r line; do
		echo "$line"
		if [[ $line == *"$HARDCODED_SAVE_TEXT"* ]]; then
			echo "Target text found: $HARDCODED_SAVE_TEXT"
			# give it a few ticks to finish
			sleep 2
			kill "$command_pid"
			sleep 2
			kill "$command_pid"
			sleep 2
			break
		fi
	done <factorio_output_pipe
	kill -9 "$command_pid" >/dev/null 2>&1
	rm factorio_output_pipe
	SAVE_FACTORIO_DATA_PATH="${FACTORIO_DATA_DIR}/saves/${HARDCODED_PRIMED_SCENARIO_NAME}.zip"
	SAVE_SETUP_FACTORIO_DATA_PATH="${FACTORIO_DATA_DIR}/saves/${SCENARIO_RANDOM_NAME}.zip"
	# Use --benchmark-graphics if you want to watch
	"$FACTORIO_EXE" --benchmark-graphics "$SAVE_FACTORIO_DATA_PATH" --benchmark-ticks 3100 --disable-audio | tee "$OUTPUT_LOG_FILE" || exit 1
	mv "$SCENARIO_FACTORIO_DATA_PATH" .trash/ || exit 1
	mv "$SAVE_FACTORIO_DATA_PATH" .trash/ || exit 1
	mv "$SAVE_SETUP_FACTORIO_DATA_PATH" .trash/ || exit 1
	echo "------ SORTED BY TIME ------" >>"$OUTPUT_LOG_FILE"
	grep -n 'Total Duration' "$OUTPUT_LOG_FILE" | awk '{match($0, /[0-9]+[.]*[0-9]*ms/); print $1, substr($0, RSTART, RLENGTH) " " $0}' | sort -k2 -n | awk '{$1=""; print $0}' >tmp.txt || exit 1
	cat tmp.txt >>"$OUTPUT_LOG_FILE" || exit 1
	rm tmp.txt || exit 1
	rm -rf ./.trash || exit 1
fi
