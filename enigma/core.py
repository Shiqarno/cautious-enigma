# general
import logging
import os
import warnings
from datetime import date

import fire
import pandas as pd
import numpy as np
import pandas_ta as ta
from hydra import compose, initialize
from joblib import dump, load
from sklearn.ensemble import RandomForestClassifier

# models
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    f1_score,
    precision_score,
    roc_auc_score,
)

# modeling
from sklearn.model_selection import cross_val_score, train_test_split


warnings.filterwarnings("ignore")


def get_help_bbands():
    """
    =>--*
    """
    return help(ta.bbands)

class ForexCLI:
    """Forex CLI"""

    def train(self):
        with initialize(version_base=None, config_path="../conf", job_name="app"):
            cfg = compose(config_name="train_config")
            frx = Forex(cfg)
            frx.train_class_model()
            frx.dump_model("class_model")



class Forex:
    """General methods"""

    def __init__(self, cfg=None):
        if cfg is None or not cfg:
            with initialize(version_base=None, config_path="../conf", job_name="app"):
                self.cfg = compose(config_name="default_config")
        else:
            self.cfg = cfg
        logging.basicConfig(
            filename=self.cfg.logs.path + "/" + str(date.today()) + ".log",
            level=logging.INFO,
        )
        self.logger = logging.getLogger(__name__)
        self.DIGITS = self.cfg.prepare.digits
        self.MAX_LAG = 3
        self.columns_for_train = []
        self.columns_for_forecast = []
        self.df = None
        self.class_model = None
        self.core_model_upward = None
        self.core_model_downward = None
        self.farseer_model = None
        self.STATE = 1234
        self.__version__ = "14.04.26"

    def dump_model(self, model_name: str):
        """Save model to disk"""
        if not hasattr(self, model_name):
            return None
        dump(
            getattr(self, model_name),
            self.cfg.predict.model_path + "/" + model_name + ".joblib",
        )

    def load_model(self, model_name: str):
        """Load model from disk"""
        if not hasattr(self, model_name):
            return None
        model = load(self.cfg.predict.model_path + "/" + model_name + ".joblib")
        if model is not None:
            setattr(self, model_name, model)
        else:
            print(f"Error loading model: {model_name}")

    def train_class_model(self):
        """Train class model"""
        model_name = "class_model"
        if self.df is None:
            self.prepare()
        train_array = []
        df_a = self.df.query("category == 'a'")
        df_a['target'] = 1
        train_array.append(df_a)
        df_m = self.df.query("category != 'a'").sample(n=df_a.shape[0])
        df_m['target'] = 0
        train_array.append(df_m)

        df_train = pd.concat(train_array)

        features = df_train[self.columns_for_train]
        target = df_train["target"]
        features_train, features_test, target_train, target_test = train_test_split(
            features, target, test_size=0.2
        )
        model = RandomForestClassifier(verbose=False)
        scores = cross_val_score(model, features_train, target_train, scoring="f1")
        print("f1.avg=", scores.mean())
        print(scores)
        model.fit(features_train, target_train)
        setattr(self, model_name, model)
        preds_test = model.predict(features_test)
        print("class_model")
        print(classification_report(target_test, preds_test))

    def make_decision(self, bulk=False) -> str:
        """Decision on opening position"""
        is_open = "none"

        if self.df is None:
            self.prepare()

        last_index = self.df.index[-1]
        name = self.df.loc[last_index, "name"]
        if name == "":
            return is_open

        log_message = "version=" + self.__version__
        log_message += f":{name}:{str(last_index)}"

        row = self.df.loc[last_index]

        class_preds = self.get_class_prediction()
        if class_preds is None:
            return 0.01

        log_message += f":class_1={class_preds["class_1"]}"
        self.logger.info(log_message)
        return round(class_preds["class_1"], 2)

    def get_class_prediction(self, bulk=False) -> dict:
        """Class (a,m,z,...)"""
        if self.df is None:
            self.prepare()
        models = ["class_model"]
        for model_name in models:
            if getattr(self, model_name) is None:
                self.load_model(model_name)
        if bulk:
            df = self.df
        else:
            last_index = self.df.index[-1]
            name = self.df.loc[last_index, "name"]
            df = self.df.query("date == @last_index")
            if name == "":
                log_message = "version=" + self.__version__
                log_message += ":name is None"
                log_message += f":df.shape={str(df.shape)}"
                self.logger.info(log_message)
                return None
        class_preds = self.class_model.predict_proba(df[self.columns_for_train])
        classes = self.class_model.classes_
        if bulk:
            for i in range(len(classes)):
                df["class_" + str(classes[i])] = class_preds[:, i]
            return df
        last_index = self.df.index[-1]
        log_message = "version=" + self.__version__
        log_message += f":{name}:{str(last_index)}"
        log_message += f":classes={str(classes)}"
        log_message += f":class_preds={str(round(class_preds[0][1], 2))}"
        self.logger.info(log_message)
        keys = list(classes)
        values = list(class_preds[0])
        return {"class_"+str(keys[i]): float(values[i]) for i in range(len(keys))}
    
    def get_core_prediction(self, bulk=False) -> dict:
        """Core score (higher is better)"""
        if self.df is None:
            self.prepare()
        
        if bulk:
            df = self.df
        else:
            last_index = self.df.index[-1]
            name = self.df.loc[last_index, "name"]
            df = self.df.query("date == @last_index")
            if name == "":
                log_message = "version=" + self.__version__
                log_message += ":name is None"
                log_message += f":df.shape={str(df.shape)}"
                self.logger.info(log_message)
                return None
            
        df['core_score'] = 0
        df['core_score'] += df.apply(lambda row: 1 if row['ft_scr'] > -0.5 else 0, axis=1)
        df['core_score'] += df.apply(lambda row: 1 if row['impulse'] > 0.3 else 0, axis=1)

        if bulk:
            return df
        last_index = self.df.index[-1]
        log_message = "version=" + self.__version__
        log_message += f":{name}:{str(last_index)}"
        log_message += f":core_score={str(round(df['core_score'].iloc[-1], 2))}"
        self.logger.info(log_message)

        return {"core_score": float(df['core_score'].iloc[-1])}

    def prepare(self):
        """Prepare dataset"""
        if self.df is None:
            self.df = pd.read_csv(self.cfg.prepare.path)
        df = self.df

        df["date"] = pd.to_datetime(df["date"])
        df = df.set_index("date")
        df = df.sort_values("date")

        MA_PERIODS = [14, 50, 200]

        for period in MA_PERIODS:
            df["ma" + str(period)] = ta.ema(df['close'], length=period)

        df.dropna(inplace=True)

        df["trend_direction"] = df.apply(
            lambda row: 1 if row["ma50"] >= row["ma200"] else -1, axis=1
        )
        self.columns_for_train.append("trend_direction")

        adx = ta.adx(df["high"], df["low"], df["close"], length=14, drift=1, mamona="ema")
        df["adx"] = adx["ADX_14"]
        self.columns_for_train.append("adx")
        df["adx_h"] = adx["DMP_14"]
        self.columns_for_train.append("adx_h")
        df["adx_c"] = adx["DMN_14"]
        self.columns_for_train.append("adx_c")
        df["rsi"] = ta.rsi(df["close"])
        self.columns_for_train.append("rsi")

        df["atr"] = ta.atr(df['high'],df['low'],df['close'], length=14)

        macd = ta.macd(df["close"])
        df["macd"] = macd["MACD_12_26_9"]
        df["macd_s"] = macd["MACDs_12_26_9"]

        df["body"] = (df["close"] - df["open"]) * df["trend_direction"] * self.DIGITS
        self.columns_for_train.append("body")

        df["full_body"] = (df["close"] - df["low"]) * df["trend_direction"] * self.DIGITS
        self.columns_for_train.append("full_body")

        df['shadow'] = (df["high"] - df["low"]) * df["trend_direction"] * self.DIGITS

        df["close_ma50_diff"] = (
            (df["close"] - df["ma50"]) * df["trend_direction"] * self.DIGITS
        )
        self.columns_for_train.append("close_ma50_diff")

        df["close_ma14_diff"] = (
            (df["close"] - df["ma14"]) * df["trend_direction"] * self.DIGITS
        )

        df["ma14_ma50_diff"] = (
            (df["ma14"] - df["ma50"]) * df["trend_direction"] * self.DIGITS
        )

        df["ma14_ma200_diff"] = (
            (df["ma14"] - df["ma200"]) * df["trend_direction"] * self.DIGITS
        )

        df['stdev'] = ta.stdev(df['close'], length=20)

        df["close_ma200_diff"] = (
            (df["close"] - df["ma200"]) * df["trend_direction"] * self.DIGITS
        )
        self.columns_for_train.append("close_ma200_diff")

        df["ma50_ma200_diff"] = (
            (df["ma50"] - df["ma200"]) * df["trend_direction"] * self.DIGITS
        )
        self.columns_for_train.append("ma50_ma200_diff")

        df["is_body_positive"] = df.apply(
            lambda row: 1 if (row["body"] * row["trend_direction"] > 0) else 0, axis=1
        )
        self.columns_for_train.append("is_body_positive")

        df['is_cross_ma50'] = df.apply(
                lambda row: 1 if (row["low"] <= row["ma50"] <= row["high"]) else 0, axis=1
            )
        self.columns_for_train.append("is_cross_ma50")

        df_buff = df.ta.stoch()
        df["stoch"] = df_buff["STOCHk_14_3_3"]
        df["stoch_s"] = df_buff["STOCHd_14_3_3"]

        self.columns_for_train.append("stoch")
        self.columns_for_train.append("stoch_s")

        df["r"] = df.ta.willr()

        df["rsi"] = ta.rsi(df['close'], length=14)

        self.columns_for_train.append("r")

        for lag in range(1, self.MAX_LAG + 1):
            df["diff_{}".format(lag)] = (
                (df["close"] - df["close"].shift(lag))
                * df["trend_direction"]
                * self.DIGITS
            )
            self.columns_for_train.append("diff_{}".format(lag))

            df["is_cross_ma50_{}".format(lag)] = df["is_cross_ma50"].shift(lag)
            self.columns_for_train.append("is_cross_ma50_{}".format(lag))

            for indicator in ("adx", "adx_h", "adx_c"):
                df[f"diff_{indicator}_{lag}"] = df[indicator] - df[indicator].shift(lag)
                self.columns_for_train.append(f"diff_{indicator}_{lag}")

            for indicator in ("r", "stoch", "stoch_s", "macd", "macd_s", "rsi"):
                df[f"diff_{indicator}_{lag}"] = (
                    df[indicator] - df[indicator].shift(lag)
                ) * df["trend_direction"]
                self.columns_for_train.append(f"diff_{indicator}_{lag}")

        #    for indicator in ("volume"):
        #        df[f"diff_{indicator}_{lag}"] = df[indicator] - df[indicator].shift(lag)

        for lag in range(0, self.MAX_LAG + 1):
            for moving_average in MA_PERIODS:
                df["diff_ma_" + str(moving_average) + "_" + str(lag)] = (
                    (df["close"] - df["ma" + str(moving_average)].shift(lag))
                    * df["trend_direction"]
                    * self.DIGITS
                )
                self.columns_for_train.append(
                    "diff_ma_" + str(moving_average) + "_" + str(lag)
                )

        df["stoch_delta"] = (df["stoch"] - df["stoch_s"]) * df["trend_direction"]
        self.columns_for_train.append("stoch_delta")

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
        self.columns_for_train.append("macd_delta")

        # df["macd"] = df["macd"] * df["trend_direction"]
        self.columns_for_train.append("macd")
        # df["macd_s"] = df["macd_s"] * df["trend_direction"]
        self.columns_for_train.append("macd_s")

        df.dropna(inplace=True)

        if df.shape[0] == 0:
            raise TypeError("Empty dataset")

        df["candle_direction"] = df.apply(lambda row: 1 if row["body"] > 0 else 0, axis=1)
        self.columns_for_train.append("candle_direction")

        df['atr_norm'] = df['atr'] / df['close']
        df['efficiency'] = df['body'].abs() / df['shadow'].abs()

        df['atr10'] = ta.atr(df['high'],df['low'],df['close'], length=10)
        df['atr50'] = ta.atr(df['high'],df['low'],df['close'], length=50)

        df['compression'] = df['atr10'] / df['atr50']

        df['impulse'] = df['body'] / df['atr'] / self.DIGITS
        df['impulse_abs'] = df['body'].abs() / df['atr'] / self.DIGITS

        df['local_high'] = 0
        df['local_low'] = 9999
        BACKWARD = 3
        for lag in range(1, BACKWARD + 1):
            df['local_high'] = np.fmax(
                df['high'].shift(1 * lag)
                ,df['local_high']
            )
            df['local_low'] = np.fmin(
                df['low'].shift(1 * lag)
                ,df['local_low']
            )

        df['ft_score'] = (
                    df.apply(lambda row: 
                    row['close'] - row['local_high'] if row['trend_direction'] == 1 else 
                    row['local_low'] - row['close'], 
                    axis=1)
                        )
        
        df['ft_scr'] = df['ft_score'] / df['atr']

        self.df = df

if __name__ == "__main__":
    fire.Fire(ForexCLI)        