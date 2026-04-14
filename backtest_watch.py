import os
import time
import shutil
import signal
import sys
from pathlib import Path
from datetime import datetime

# ---- SETTINGS ----
BASE_PATH = Path("Tester")  # folder where Agent-* folders are located
TARGET_REL_PATH = Path("MQL5/Files")  # inside Agent-*
FILE_TO_COPY = Path("data/backtest_ready.csv")  # file to copy
CHECK_INTERVAL = 1  # seconds between scans
# -------------------

def shutdown(sig, frame):
    print("Graceful shutdown...")
    sys.exit(0)

signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)

def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {msg}")

def verify_source_file():
    if not FILE_TO_COPY.exists():
        raise FileNotFoundError(f"Source file does not exist: {FILE_TO_COPY}")
    log(f"Source file OK: {FILE_TO_COPY}")

def copy_if_exists():
    for agent_dir in BASE_PATH.glob("Agent-*"):
        if agent_dir.is_dir():
            target_dir = agent_dir / TARGET_REL_PATH
            dest_file = target_dir / "backtest_ready.csv"
            flag_file = target_dir / "backtest_ready.flg"

            if target_dir.exists():
                if dest_file.exists():
                    # log(f"Skip: destination file already exists → {dest_file}")
                    if not flag_file.exists():
                        with open(flag_file, "w") as f:
                            pass
                    continue
                try:
                    shutil.copy(FILE_TO_COPY, dest_file)
                    log(f"Copied → {dest_file}")
                    with open(flag_file, "w") as f:
                        pass
                    log(f"Flag file: {flag_file}")
                except Exception as e:
                    log(f"ERROR copying: {e}")
            else:
                log(f"{agent_dir} not ready")

def main():
    log("Starting watcher... Press CTRL+C to stop.")
    verify_source_file()
    while True:
        try:
            copy_if_exists()
            time.sleep(CHECK_INTERVAL)
        except KeyboardInterrupt:
            log("Stopped manually.")
            break

if __name__ == "__main__":
    main()
