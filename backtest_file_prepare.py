import os
from pathlib import Path
from shutil import copy2
import pandas as pd
import pandas_ta as ta
from hydra import compose, initialize

from enigma.core import Forex as ForexCore

with initialize(version_base=None, config_path="conf", job_name="app"):
    cfg = compose(config_name="notebook_config")

MQ5_TESTER_FOLDER = 'Tester'
BACKTEST_CSV = 'data/backtest.csv'
BACKTEST_READY_CSV = 'data/backtest_ready.csv'

print(os.getcwd())

if not os.path.exists(BACKTEST_CSV):
    print(f"{BACKTEST_CSV} not found, copying from MQ5 Tester folder;")
    folder = Path(MQ5_TESTER_FOLDER)
    dirs = [d for d in folder.glob("Agent-*") if d.is_dir()]
    for d in dirs:
        copy2(str(d)+'/MQL5/Files/backtest.csv', BACKTEST_CSV)
        break

df = pd.read_csv(BACKTEST_CSV)
forex = ForexCore(cfg)
forex.df = df
forex.prepare()

df = forex.get_core_prediction(True)
df['cre'] = df['core_score']

df = forex.get_class_prediction(True)
df['cls'] = df['class_1']

columns = ['name','date','open','high','low','close','cls','cre']
df['date'] = df.index
df[columns].to_csv(BACKTEST_READY_CSV, index=False)
print(f"{BACKTEST_READY_CSV} created;")

folder = Path(MQ5_TESTER_FOLDER)
dirs = [d for d in folder.glob("Agent-*") if d.is_dir()]
for d in dirs:
    try:
        copy2(BACKTEST_READY_CSV, str(d)+'/MQL5/Files/backtest_ready.csv')
        print(f"{BACKTEST_READY_CSV} copied to {str(d)+'/MQL5/Files/backtest_ready.csv'}")
        with open(str(d)+"/MQL5/Files/backtest_ready.flg", "w") as f:
            pass
        print(f"flag file created to {str(d)+'/MQL5/Files/backtest_ready.flg'}")
    except:
        print(str(d) + " is not ready;")
        pass

if os.path.exists(BACKTEST_CSV):
    os.remove(BACKTEST_CSV)
    print(f"{BACKTEST_CSV} removed")