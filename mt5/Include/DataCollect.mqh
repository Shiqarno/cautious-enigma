//+------------------------------------------------------------------+
//|                                                  DataCollect.mq5 |
//|                                               shiqarno@proton.me |
//|                                  http://www.shiqarnozaibatsu.com |
//+------------------------------------------------------------------+
#property copyright "shiqarno@proton.me"
#property link      "https://www.shiqarnozaibatsu.com"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
#include <JAson.mqh>
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
int iMaxBar = 1;
int iRatesBar = 400;
datetime Date;
string sIndicatorsStrings[];
string sIndicators = "ma13,ma36,ma78,ma216,r,r6,s,s-sig,s6,s6-sig,adx,adx-h,adx-c,adx6,adx6-h,adx6-c,macd,macd-sig,macd6,macd6-sig";
string sURL_eval = "http://127.0.0.1:8000/tick"; // API URL Evaluation
string sURL_eval_close = "http://127.0.0.1:8000/is_time_to_quit"; // API URL Evaluation close
string sURL_predict = "http://127.0.0.1:8000/predict"; // API URL Predict
string sURL_is_alive = "http://127.0.0.1:8000/is_alive"; // API URL Is Alive

bool IsAlive()
{
   string cookie=NULL,headers;
   char   post[],result[];
   int res = WebRequest("GET", sURL_is_alive, NULL, NULL, 1000, post, 0, result, headers);

   if (res == 200)
   {
      return true;
   }
   return false;
}

string EvaluateBar(string sSymbol, ENUM_TIMEFRAMES ePeriod, datetime dPeriod)
{
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
   uchar cTick[]; // ->sTick
   StringToCharArray(sTick, cTick, 0, StringLen(sTick));
   string serverHeaders = "content-type: application/json;\n";

   int res = WebRequest("PUT", sURL_eval, NULL, NULL, 1000, cTick, ArraySize(cTick), serverResult, serverHeaders);

   if (res == 200)
   {
      CJAVal response;
      response.Deserialize(serverResult);
      string result = response["decision"].ToStr();
      return result;
   }
   else
   {
      string LastError = GetLastError();
      Print("Web request result: ", res, ", error: #", (res == -1 ? LastError : 0));
      return LastError;
   }
}

string EvaluateBarClose(string sSymbol, ENUM_TIMEFRAMES ePeriod, datetime dPeriod)
{
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
   uchar cTick[]; // ->sTick
   StringToCharArray(sTick, cTick, 0, StringLen(sTick));
   string serverHeaders = "content-type: application/json;\n";

   int res = WebRequest("PUT", sURL_eval_close, NULL, NULL, 1000, cTick, ArraySize(cTick), serverResult, serverHeaders);

   if (res == 200)
   {
      CJAVal response;
      response.Deserialize(serverResult);
      string result = response["decision"].ToStr();
      return result;
   }
   else
   {
      string LastError = GetLastError();
      Print("Web request result: ", res, ", error: #", (res == -1 ? LastError : 0));
      return LastError;
   }
}

string GetPrediction(string sSymbol, ENUM_TIMEFRAMES ePeriod, datetime dPeriod)
{
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
   uchar cTick[]; // ->sTick
   StringToCharArray(sTick, cTick, 0, StringLen(sTick));
   string serverHeaders = "content-type: application/json;\n";

   int res = WebRequest("PUT", sURL_predict, NULL, NULL, 1000, cTick, ArraySize(cTick), serverResult, serverHeaders);

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

string IndicatorIndex(string value)
{
   for(int i=0;i<ArraySize(sIndicatorsStrings);i++)
   {
      if(sIndicatorsStrings[i] == value)
      {
         string sName = "";
         int iRet = StringConcatenate(sName, "ind_", i);
         return sName;
      }
   }
   Print("No found:", value);
   return -1;
}

void CollectTheData(CJAVal &DataSet, string sSumbol, datetime dDate)
{
      Date = dDate;

      ENUM_TIMEFRAMES eCurrentPeriod = PERIOD_H4; // or == 'Period()' -> then eMajorPeriod must be different (H1->H4;H4->D;D->W)
      string sName = "";

      ushort u_sep = 44; // ","
      int k=StringSplit(sIndicators,u_sep,sIndicatorsStrings);

      // back for classification
      MqlRates  rates_array[];
      ArraySetAsSeries(rates_array,true);
      int iRatesBar = 11;
      int iRatesArray = CopyRates(sSumbol,eCurrentPeriod,Date,iRatesBar,rates_array);
      DataSet["name"] = sSumbol;
      DataSet["date"] = DateToString(rates_array[0].time);
      DataSet["open"] = rates_array[0].open;
      DataSet["high"] = rates_array[0].high;
      DataSet["low"] = rates_array[0].low;
      DataSet["close"] = rates_array[0].close;
      DataSet["volume"] = rates_array[0].tick_volume;
      for(int i=1;i<iRatesBar;i++)
      {
         sName = "";
         int iRet = StringConcatenate(sName, "lag_", i);
         DataSet[sName] = rates_array[i].close;
      }

      // MA
      int iMAPeriods[4];
      iMAPeriods[0] = 13;
      iMAPeriods[1] = 36;
      iMAPeriods[2] = 78;
      iMAPeriods[3] = 216;

      for(int i=0; i<ArraySize(iMAPeriods); i++)
      {
         double MA_Buffer[];
         ArraySetAsSeries(MA_Buffer,true);
         bool iResult = GetMA(iMAPeriods[i], MA_Buffer, sSumbol, eCurrentPeriod);
         sName = "";
         int iRet = StringConcatenate(sName, "ma", iMAPeriods[i]);
         string indName = IndicatorIndex(sName);
         DataSet[indName] = MA_Buffer[0];
      }

      // %R
      double buffer[];
      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      bool iResult = GetWPR(buffer, sSumbol, eCurrentPeriod, 14);
      DataSet[IndicatorIndex("r")] = buffer[0];

      // %R
      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetWPR(buffer, sSumbol, eCurrentPeriod, 14 * 6);
      DataSet[IndicatorIndex("r6")] = buffer[0];

      // Stoch
      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetStoch(buffer, 0, sSumbol, eCurrentPeriod, 5, 3, 3);
      DataSet[IndicatorIndex("s")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetStoch(buffer, 1, sSumbol, eCurrentPeriod, 5, 3, 3);
      DataSet[IndicatorIndex("s-sig")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetStoch(buffer, 0, sSumbol, eCurrentPeriod, 5 * 6, 3 * 6, 3 * 6);
      DataSet[IndicatorIndex("s6")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetStoch(buffer, 1, sSumbol, eCurrentPeriod, 5 * 6, 3 * 6, 3 * 6);
      DataSet[IndicatorIndex("s6-sig")] = buffer[0];

      // ADX
      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetADX(buffer, 0, sSumbol, eCurrentPeriod, 14);
      DataSet[IndicatorIndex("adx")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetADX(buffer, 1, sSumbol, eCurrentPeriod, 14);
      DataSet[IndicatorIndex("adx-h")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetADX(buffer, 2, sSumbol, eCurrentPeriod, 14);
      DataSet[IndicatorIndex("adx-c")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetADX(buffer, 0, sSumbol, eCurrentPeriod, 14 * 6);
      DataSet[IndicatorIndex("adx6")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetADX(buffer, 1, sSumbol, eCurrentPeriod, 14 * 6);
      DataSet[IndicatorIndex("adx6-h")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetADX(buffer, 2, sSumbol, eCurrentPeriod, 14 * 6);
      DataSet[IndicatorIndex("adx6-c")] = buffer[0];

      // MACD
      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetMACD(buffer, 0, sSumbol, eCurrentPeriod, 12, 26, 9);
      DataSet[IndicatorIndex("macd")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetMACD(buffer, 1, sSumbol, eCurrentPeriod, 12, 26, 9);
      DataSet[IndicatorIndex("macd-sig")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetMACD(buffer, 0, sSumbol, eCurrentPeriod, 12 * 6, 26 * 6, 9 * 6);
      DataSet[IndicatorIndex("macd6")] = buffer[0];

      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      iResult = GetMACD(buffer, 1, sSumbol, eCurrentPeriod, 12 * 6, 26 * 6, 9 * 6);
      DataSet[IndicatorIndex("macd6-sig")] = buffer[0];
}

bool GetMA(int sPeriod, double &sBuffer[], string sSumbol, ENUM_TIMEFRAMES ePeriod)
{
   int handle=iMA(sSumbol,ePeriod,sPeriod,0,MODE_EMA,PRICE_CLOSE);
   int iResultCount = CopyBuffer(handle,0,Date,iMaxBar,sBuffer);
   IndicatorRelease(handle);
   return ArraySize(sBuffer) > 0;
}

bool GetWPR(double &sBuffer[], string sSumbol, ENUM_TIMEFRAMES ePeriod, int calc_period)
{
   int handle = iWPR(sSumbol,ePeriod, calc_period);
   int iResultCount = CopyBuffer(handle,0,Date,iMaxBar,sBuffer);
   IndicatorRelease(handle);
   return ArraySize(sBuffer) > 0;
}

bool GetStoch(double &sBuffer[], int iBufferNumber, string sSumbol, ENUM_TIMEFRAMES ePeriod,int k_period,int d_period,int slowing)
{
   int handle = iStochastic(sSumbol,ePeriod,k_period,d_period,slowing,MODE_SMA,STO_LOWHIGH);
   int iResultCount = CopyBuffer(handle,iBufferNumber,Date,iMaxBar,sBuffer);
   IndicatorRelease(handle);
   return ArraySize(sBuffer) > 0;
}

bool GetADX(double &sBuffer[], int iBufferNumber, string sSumbol, ENUM_TIMEFRAMES ePeriod, int ma_period)
{
   int handle = iADX(sSumbol,ePeriod, ma_period);
   int iResultCount = CopyBuffer(handle,iBufferNumber,Date,iMaxBar,sBuffer);
   IndicatorRelease(handle);
   return ArraySize(sBuffer) > 0;
}

bool GetMACD(double &sBuffer[], int iBufferNumber, string sSumbol, ENUM_TIMEFRAMES ePeriod, int fast_ema_period,int slow_ema_period,int signal_period)
{
   int handle = iMACD(sSumbol,ePeriod,fast_ema_period,slow_ema_period,signal_period,PRICE_CLOSE);
   int iResultCount = CopyBuffer(handle,iBufferNumber,Date,iMaxBar,sBuffer);
   IndicatorRelease(handle);
   return ArraySize(sBuffer) > 0;
}

string DateToString(datetime sDate)
{
   string sResult;
   sResult = TimeToString(sDate,TIME_DATE) +" "+ TimeToString(sDate,TIME_MINUTES);
   return sResult;
}

bool PeriodToStr(ENUM_TIMEFRAMES period,string &strper)
  {
   bool res=true;
   switch(period)
     {
      case PERIOD_MN1 : strper="MN1"; break;
      case PERIOD_W1 :  strper="W1";  break;
      case PERIOD_D1 :  strper="D1";  break;
      case PERIOD_H1 :  strper="H1";  break;
      case PERIOD_H2 :  strper="H2";  break;
      case PERIOD_H3 :  strper="H3";  break;
      case PERIOD_H4 :  strper="H4";  break;
      case PERIOD_H6 :  strper="H6";  break;
      case PERIOD_H8 :  strper="H8";  break;
      case PERIOD_H12 : strper="H12"; break;
      case PERIOD_M1 :  strper="M1";  break;
      case PERIOD_M2 :  strper="M2";  break;
      case PERIOD_M3 :  strper="M3";  break;
      case PERIOD_M4 :  strper="M4";  break;
      case PERIOD_M5 :  strper="M5";  break;
      case PERIOD_M6 :  strper="M6";  break;
      case PERIOD_M10 : strper="M10"; break;
      case PERIOD_M12 : strper="M12"; break;
      case PERIOD_M15 : strper="M15"; break;
      case PERIOD_M20 : strper="M20"; break;
      case PERIOD_M30 : strper="M30"; break;
      default : res=false;
     }
   return(res);
  }
