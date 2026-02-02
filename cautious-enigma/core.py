from joblib import load

import numpy as np
import pandas as pd
import pandas_ta as ta


class Forex:
    """General methods"""

    def __init__(self, cfg=None):
        self.DIGITS = 100_000
        self.MAX_LAG = 3
        self.STATE = 12345
        self.df = None
        self.__version__ = "02.02.26"

    def get_prediction(self) -> dict:
        """Load trained model from file and make prediction"""
        model = load("models/rf_class_a.joblib")
        class_preds = model.predict_proba(self.df.drop(columns=['name', 'open', 'high', 'low', 'close']))
        keys = list(model.classes_)
        values = list(class_preds[-1])
        return {"class_"+str(keys[i]): float(values[i]) for i in range(len(keys))}

    def prepare_data(self) -> None:
        """Prepare data for prediction"""
        
        df = pd.read_csv('data/input_data.csv')
        df["date"] = pd.to_datetime(df["date"])
        df = df.set_index("date")
        df = df.sort_values("date")

        adx = ta.adx(df["high"], df["low"], df["close"], length=14, drift=1, mamona="ema")
        df["adx"] = adx["ADX_14"]
        df["adx_h"] = adx["DMP_14"]
        df["adx_c"] = adx["DMN_14"]
        df["rsi"] = ta.rsi(df["close"])

        stoch = df.ta.stoch()
        df["stoch"] = stoch["STOCHk_14_3_3"]
        df["stoch_s"] = stoch["STOCHd_14_3_3"]

        df["r"] = df.ta.willr()

        macd = ta.macd(df["close"])
        df["macd"] = macd["MACD_12_26_9"]
        df["macd_s"] = macd["MACDs_12_26_9"]

        MA_PERIODS = [50, 200]

        for period in MA_PERIODS:
            df["ma" + str(period)] = ta.ema(df['close'], length=period)

        df.dropna(inplace=True)

        df["trend_direction"] = df.apply(
            lambda row: 1 if row["ma50"] >= row["ma200"] else -1, axis=1
        )

        df["close_ma50_diff"] = (
            (df["close"] - df["ma50"]) * df["trend_direction"] * self.DIGITS
        )

        df["close_ma200_diff"] = (
            (df["close"] - df["ma200"]) * df["trend_direction"] * self.DIGITS
        )

        df["ma50_ma200_diff"] = (
            (df["ma50"] - df["ma200"]) * df["trend_direction"] * self.DIGITS
        )

        df["body"] = (df["close"] - df["open"]) * df["trend_direction"] * self.DIGITS

        df["full_body"] = (df["close"] - df["low"]) * df["trend_direction"] * self.DIGITS

        df["candle_direction"] = df.apply(lambda row: 1 if row["body"] > 0 else 0, axis=1)

        df["is_body_positive"] = df.apply(
            lambda row: 1 if (row["body"] * row["trend_direction"] > 0) else 0, axis=1
        )

        df['is_cross_ma50'] = df.apply(
                lambda row: 1 if (row["low"] <= row["ma50"] <= row["high"]) else 0, axis=1
            )
        
        for lag in range(1, self.MAX_LAG + 1):
            df["diff_{}".format(lag)] = (
                (df["close"] - df["close"].shift(lag))
                * df["trend_direction"]
                * self.DIGITS
            )

            df["is_cross_ma50_{}".format(lag)] = df["is_cross_ma50"].shift(lag)

            for indicator in ("adx", "adx_h", "adx_c"):
                df[f"diff_{indicator}_{lag}"] = df[indicator] - df[indicator].shift(lag)

            for indicator in ("r", "stoch", "stoch_s", "macd", "macd_s", "rsi"):
                df[f"diff_{indicator}_{lag}"] = (
                    df[indicator] - df[indicator].shift(lag)
                ) * df["trend_direction"]

            for indicator in (["volume"]):
                df[f"diff_{indicator}_{lag}"] = df[indicator] - df[indicator].shift(lag)

        for lag in range(0, self.MAX_LAG + 1):
            for moving_average in MA_PERIODS:
                df["diff_ma_" + str(moving_average) + "_" + str(lag)] = (
                    (df["close"] - df["ma" + str(moving_average)].shift(lag))
                    * df["trend_direction"]
                    * self.DIGITS
                )

        df["stoch_delta"] = (df["stoch"] - df["stoch_s"]) * df["trend_direction"]

        columns_to_reverse = ["stoch", "stoch_s", "rsi"]
        for column in columns_to_reverse:
            df[column] = df.apply(
                lambda row: row[column]
                if row.trend_direction == 1
                else 100 - row[column],
                axis=1,
            )

        columns_to_reverse = ["r"]
        for column in columns_to_reverse:
            df[column] = df.apply(
                lambda row: row[column] * -1
                if row.trend_direction == -1
                else 100 + row[column],
                axis=1,
            )

        df["macd_delta"] = (df["macd"] - df["macd_s"]) * df["trend_direction"]

        df.dropna(inplace=True)

        if df.shape[0] == 0:
            raise TypeError("Empty dataset")
        
        self.df = df