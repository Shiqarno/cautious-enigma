//+------------------------------------------------------------------+
//|                                                       tomato.mq5 |
///|                              Copyright 2026, shiqarno@proton.me |
//|                                 https://www.shiqarnozaibatsu.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, shiqarno@proton.me"
#property link      "https://www.shiqarnozaibatsu.com"
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
#include <JAson.mqh>

//--- input parameters
input datetime dPeriod = D'2024.01.01 00:00:00';

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Comment(dPeriod, " ", Symbol(), "\nEvaluation...");
   Comment(GetPrediction(Symbol(), Period(), dPeriod));
}

string GetPrediction(string sSymbol, ENUM_TIMEFRAMES ePeriod, datetime dPeriod)
{
   int iRatesBar = 400;
   MqlRates  rates_array[];
   ArraySetAsSeries(rates_array,true);
   int iRatesArray = CopyRates(sSymbol,ePeriod,dPeriod,iRatesBar,rates_array);

   string sTick = "[";

   for(int i=0;i<iRatesBar;i++)
   {
      CJAVal data;
      data["name"] = sSymbol;
      data["date"] = DateToString(rates_array[i].time);
      data["open"] = rates_array[i].open;
      data["high"] = rates_array[i].high;
      data["low"] = rates_array[i].low;
      data["close"] = rates_array[i].close;
      data["volume"] = rates_array[i].tick_volume;
      string sLocalTick = data.Serialize();
      int iRet = StringConcatenate(sTick, sTick, data.Serialize());
      if(i!=iRatesBar-1)
         int iRet = StringConcatenate(sTick, sTick, ",");
      else
         int iRet = StringConcatenate(sTick, sTick, "]");
   }

   char serverResult[];
   char cTick[]; // ->sTick
   StringToCharArray(sTick, cTick, 0, StringLen(sTick));
   string serverHeaders = "content-type: application/json;\n";
   
   string cookie=NULL,headers;
   char   post[],result[];

   int res = WebRequest("PUT", "http://127.0.0.1:8000/predict", NULL, NULL, 1000, cTick, ArraySize(cTick), serverResult, serverHeaders);

   if (res == 200)
   {
      CJAVal response;
      response.Deserialize(serverResult);
      string result = response["result"].ToStr();
      return result;
   }
   else
   {
      string LastError = GetLastError();
      Print("Web request result: ", res, ", error: #", (res == -1 ? LastError : 0));
      return LastError;
   }
}

string DateToString(datetime sDate)
{
   string sResult;
   sResult = TimeToString(sDate,TIME_DATE) +" "+ TimeToString(sDate,TIME_MINUTES);
   return sResult;
}
