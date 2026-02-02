from typing import List


import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel

from core import Forex as Frx

app = FastAPI()

class Tick(BaseModel):
    name: str
    date: str
    open: float
    high: float
    low: float
    close: float
    volume: int


@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.get("/is_alive")
def is_alive():
    return {"alive": True}

@app.put("/predict")
def predict(ticks: List[Tick]):
    path = "data/input_data.csv"
    text_file = open(path, "w")
    text_file.write(",".join([str(i) for i in ticks[0].dict().keys()]))
    for tick in ticks:
        text_file.write("\n")
        text_file.write(",".join([str(i) for i in tick.dict().values()]))
    text_file.close()

    frx = Frx()    
    frx.prepare_data()
    class_preds = frx.get_prediction()
    result = (
        str(frx.df.loc[frx.df.index[-1]]["name"])
        + "\n"
        + str(frx.df.index[-1])
        + "\n"
        + str(class_preds)
    )

    return {"result": result}


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        log_level="debug",
    )
