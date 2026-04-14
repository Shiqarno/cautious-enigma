from typing import List
import subprocess
import sys
import os
import psutil

import uvicorn
from fastapi import FastAPI, HTTPException, Query
from hydra import compose, initialize
from pydantic import BaseModel

from core import Forex as ForexCore

BACKTEST_SCRIPT_PATH = "backtest_file_prepare.py"
ONESHOT_PID_FILE = "backtest_file_prepare.pid"
WATCH_SCRIPT_PATH = "backtest_watch.py"
WATCH_PID_FILE = "backtest_watch.pid"
STDOUT_LOG = "backtest_watch_stdout.log"
STDERR_LOG = "backtest_watch_stderr.log"

app = FastAPI()
with initialize(version_base=None, config_path="../conf", job_name="app"):
    cfg = compose(config_name="default_config")


class Tick(BaseModel):
    name: str
    date: str
    open: float
    high: float
    low: float
    close: float
    volume: int

def oneshot_running():
    if not os.path.exists(ONESHOT_PID_FILE):
        return False

    with open(ONESHOT_PID_FILE) as f:
        pid = int(f.read())

    return psutil.pid_exists(pid)


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/is_alive")
def is_alive():
    return {"alive": True}


@app.put("/tick")
def tick(ticks: List[Tick]):
    path = cfg.predict.path
    text_file = open(path, "w")
    text_file.write(",".join([str(i) for i in ticks[0].dict().keys()]))
    for tick in ticks:
        text_file.write("\n")
        text_file.write(",".join([str(i) for i in tick.dict().values()]))
    text_file.close()

    frx = ForexCore(cfg)
    result = frx.make_decision()

    return {"decision": result}

@app.put("/predict")
def predict(ticks: List[Tick]):
    path = cfg.predict.path
    text_file = open(path, "w")
    text_file.write(",".join([str(i) for i in ticks[0].dict().keys()]))
    for tick in ticks:
        text_file.write("\n")
        text_file.write(",".join([str(i) for i in tick.dict().values()]))
    text_file.close()

    frx = ForexCore(cfg)    
    class_preds_set = frx.get_class_prediction()
    result = (
        str(frx.df.loc[frx.df.index[-1]]["name"])
        + "\n"
        + str(frx.df.index[-1])
        + "\n"
        + str(class_preds_set)
    )

    return {"result": result}

@app.post("/backtest_file_prepare")
def run_script_once():
    if oneshot_running():
        raise HTTPException(status_code=409, detail="Script already running")

    try:
        process = subprocess.Popen(
            [sys.executable, BACKTEST_SCRIPT_PATH],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        with open(ONESHOT_PID_FILE, "w") as f:
            f.write(str(process.pid))

        stdout, stderr = process.communicate()

        return {
            "status": "finished",
            "exit_code": process.returncode,
            "stdout": stdout[-2000:],   # prevent huge output
            "stderr": stderr[-2000:]
        }

    finally:
        if os.path.exists(ONESHOT_PID_FILE):
            os.remove(ONESHOT_PID_FILE)

def get_pid():
    if not os.path.exists(WATCH_PID_FILE):
        return None
    with open(WATCH_PID_FILE) as f:
        return int(f.read())


def is_running(pid: int) -> bool:
    return psutil.pid_exists(pid)


def stop_script():
    pid = get_pid()
    if not pid:
        return False

    try:
        p = psutil.Process(pid)
        p.terminate()          # SIGTERM
        p.wait(timeout=10)
    except psutil.NoSuchProcess:
        pass
    except psutil.TimeoutExpired:
        p.kill()               # SIGKILL fallback

    if os.path.exists(WATCH_PID_FILE):
        os.remove(WATCH_PID_FILE)

    return True


def start_script():
    pid = get_pid()
    if pid and is_running(pid):
        raise RuntimeError("Script already running")

    stdout = open(STDOUT_LOG, "a")
    stderr = open(STDERR_LOG, "a")

    process = subprocess.Popen(
        [sys.executable, WATCH_SCRIPT_PATH],
        stdout=stdout,
        stderr=stderr
    )

    with open(WATCH_PID_FILE, "w") as f:
        f.write(str(process.pid))

    return process.pid

@app.post("/backtest_watch")
def manage_script(
    action: str = Query(..., regex="^(start|stop|restart|status)$")
):
    try:
        if action == "status":
            pid = get_pid()
            return {
                "running": bool(pid and is_running(pid)),
                "pid": pid
            }

        if action == "start":
            pid = start_script()
            return {"status": "started", "pid": pid}

        if action == "stop":
            stopped = stop_script()
            return {"status": "stopped" if stopped else "not running"}

        if action == "restart":
            stop_script()
            pid = start_script()
            return {"status": "restarted", "pid": pid}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=cfg.uvicorn.host,
        port=cfg.uvicorn.port,
        log_level=cfg.uvicorn.log_level,
    )
