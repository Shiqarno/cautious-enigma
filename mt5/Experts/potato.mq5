//+------------------------------------------------------------------+
//|                                              expert_template.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Math\Stat\Math.mqh>
#include <DataCollect.mqh>
#include <DealStorage.mqh>

CTrade ExtTrade;
CSymbolInfo ExtSymbolInfo;

//--- input parameters
input string Mode           = "backtest"; // trade|backtest|dump

input double class_treshold = 0.5;// Class treshold
input int    MaxRisk_Money  = 50; // Max risk for position (USD)
// input ENUM_TIMEFRAMES SLMovePeriod = PERIOD_M1;
input double risk_rt        = 0.5;// Loss ratio
input double prft_rt        = 1;  // Profit ratio

input int    ADX_treshold = 0;
input int    sl_move_in_min = 1;   // Move SL every X minutes
input int    close_in_min = 0;     // Close position in X minutes

input string SymbolEval     = "CURRENT";    // Symbol to evaluate. Default=CURRENT
input int    debug_level    = 0;  // Debug messages
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
string filename       = "backtest.csv";
string filename_ready = "backtest_ready.csv";
string flag_ready     = "backtest_ready.flg";
// table - columns
int columns_number = 7; // name,date,open,high,low,close,cls
struct OHLCBar
{
   string   name; // EURUSD
   datetime date; // 2025.01.01 00:00:00
   
   double   open; // 1.00001
   double   high; // 1.00001
   double   low;  // 1.00001
   double   close;// 1.00001
   
   double   cla;  // 0.00
};

OHLCBar bars[];        // in-memory table of OHLC bars
datetime currentHour;  // timestamp of the currently processed hour
double hourOpen, hourHigh, hourLow, hourClose;
string backtest_action;

int    ExtHandle50=0;
int    ExtHandle200=0;
int    ATRHandle14=0;

bool   Model_available = false;

ushort u_sep = 44; // ","
ushort u_sep_semicolon = 59; // ";"
ushort equal_sign = 61; // "="

IStorage *storage;

int OnInit()
  {
      if(MQLInfoInteger(MQL_TESTER))
         storage = new MemoryPositionStorage();
      else
         storage = new MemoryPositionStorage(); //RedisStorage();

      if(debug_level>0)
         Print("Mode: ", Mode);
      ExtHandle50=iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE);
      ExtHandle200=iMA(_Symbol,_Period,200,0,MODE_EMA,PRICE_CLOSE);
      ATRHandle14=iATR(_Symbol, _Period, 14);
      
      if(Mode == "backtest")
      {
         
         int hndl = FileOpen("agent_ready.flg", FILE_WRITE | FILE_REWRITE | FILE_TXT);
         while(!FileIsExist(flag_ready))
         {  
            Print("File not found: ", filename_ready);
            Sleep(5000);
         }
         int handle = FileOpen(filename_ready,
                         FILE_SHARE_READ | FILE_CSV | FILE_ANSI, ",");
         backtest_action = "read_and_test";
         Print("Read and test mode");
         
         // --- skip header line ---
         for(int i=0; i<columns_number; i++)
            FileReadString(handle);
         
         // clear existing
         ArrayResize(bars, 0);
         
         while (!FileIsEnding(handle)){
            string sName  = FileReadString(handle);               
            string sDate  = FileReadString(handle);         
            string sOpen  = FileReadString(handle);
            string sHigh  = FileReadString(handle);
            string sLow   = FileReadString(handle);
            string sClose = FileReadString(handle);
            string sCla   = FileReadString(handle);

            if(debug_level>1)
               Print("Data Row -> ", 
                     "Name: ", sName, 
                     ", Date:", sDate, 
                     ", Class:", sCla);
      
            OHLCBar row;
            row.name  = sName;
            row.date  = StringToTime(sDate);
            row.open  = StringToDouble(sOpen);
            row.high  = StringToDouble(sHigh);
            row.low   = StringToDouble(sLow);
            row.close = StringToDouble(sClose);
            row.cla   = StringToDouble(sCla);
            
            if(row.cla < class_treshold)
               continue;
      
            int size = ArraySize(bars);
            ArrayResize(bars, size + 1);
            bars[size] = row;
         }
      
         FileClose(handle);
      
         Print("Loaded ", ArraySize(bars), " rows from ", filename_ready);
         return(INIT_SUCCEEDED);
      }
      if(Mode == "dump")
      {
         backtest_action = "write_file";
         Print("Write file mode");
         Print("Write ticks to file: ", filename);
         int handle = FileOpen("file.flag",
                               FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
         FileWrite(handle, "1");
         FileClose(handle);
         FileDelete("file.flag");
         return(INIT_SUCCEEDED);
      }
         
      if(IsAlive())
      {
         Print("Model available");
         Model_available = true;
      }
      else
      {
         Print("Model not available. "+ GetLastError());
         return(INIT_FAILED);
      }
      return(INIT_SUCCEEDED);
 }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
      if(Mode == "dump"){
         if(backtest_action=="write_file"){
            int handle = FileOpen(filename,
                                  FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
            // Header row
            FileWrite(handle, "name", "date", "open", "high", "low", "close");
         
            // Save closed (finished) hourly bars
            for(int i = 0; i < ArraySize(bars); i++)
            {
               FileWrite(handle,
                         bars[i].name,
                         bars[i].date,
                         bars[i].open,
                         bars[i].high,
                         bars[i].low,
                         bars[i].close);
            }
            
            FileClose(handle);
         
            Print("Saved ", ArraySize(bars), " full bars + current bar to ", filename);
         }
      }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
      // opened positions handle
      for(int t=PositionsTotal()-1;t>=0;t--) 
         if(PositionSelectByTicket(PositionGetTicket(t)))
         {
            string p_symbol = PositionGetString(POSITION_SYMBOL);
            if(p_symbol != Symbol())
               continue;
               
            if(close_in_min > 0)
            {
               datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
               int minutes_from_open = (int)((TimeCurrent() - open_time) / 60);
               if(minutes_from_open == close_in_min)
               {
                  if(debug_level>0)
                     Print("Close position: ", minutes_from_open);
                  ExtTrade.PositionClose(PositionGetTicket(t));
                  return;
               } 
            }
            
            if(sl_move_in_min == 0)
               return;
            
            datetime update_time = (datetime)PositionGetInteger(POSITION_TIME_UPDATE);
            int minutes_floor = (int)((TimeCurrent() - update_time) / 60);
            if(minutes_floor == 0)
               return;
            if((minutes_floor % sl_move_in_min) != 0)
               return;
            if(debug_level>2)
            {
               Print("update_time: ", update_time);
               Print("TimeCurrent(): ", TimeCurrent());
               Print("minutes_floor: ", minutes_floor);
            }

            ExtSymbolInfo.Name(p_symbol);
            ExtSymbolInfo.Refresh();
            ExtSymbolInfo.RefreshRates();

            double tickvalue = SymbolInfoDouble(p_symbol, SYMBOL_TRADE_TICK_VALUE);

            int direction = PositionGetInteger(POSITION_TYPE);
            int trend_direction = 0;
            string sOperation;
            double BidAsk;
            if(direction == POSITION_TYPE_BUY)
            {
               trend_direction = 1;
               sOperation = "buy";
               BidAsk = ExtSymbolInfo.Bid();
            }
            else
            {
               trend_direction = -1;
               sOperation = "sell";
               BidAsk = ExtSymbolInfo.Ask();
            }
            float volume = MathRound(PositionGetDouble(POSITION_VOLUME), 2);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double curr_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            double tp = PositionGetDouble(POSITION_TP);
            double sl = PositionGetDouble(POSITION_SL);
            
            double profit = PositionGetDouble(POSITION_PROFIT);
            int profit_points = (int)(profit / volume / tickvalue);
            
            double ATRValue = GetATRValue();
            
            int digits = ExtSymbolInfo.Digits();
            
            double new_tp = 0;
            double new_sl = 0;
            if(prft_rt != 0)
               new_tp = curr_price + ATRValue * trend_direction * prft_rt;
            new_sl = curr_price - ATRValue * trend_direction * risk_rt;
            
            if((new_sl - sl)*trend_direction > 0)
            {
 
               PrintFormat("PositionModify - SL move: %s %s at %G (sl=%G tp=%G). Bid=%G. Profit_points=%G",
         
                           p_symbol, sOperation, open_price, new_sl, tp, BidAsk, profit_points);
         
               if(!ExtTrade.PositionModify(PositionGetTicket(t), new_sl, tp)){
                  PrintFormat("Failed %s %s at %G (sl=%G tp=%G) failed. Bid=%G error=%d",
                              p_symbol, sOperation, open_price, new_sl, tp, BidAsk, GetLastError());
                  ExtTrade.PrintResult();
                  Print("   ");
               }
            }
         return;
      } // for(int t=PositionsTotal()-1;t>=0;t--)
          
      static datetime dtBarCurrent  = WRONG_VALUE;
      datetime dtBarPrevious = dtBarCurrent;
      dtBarCurrent  = iTime(Symbol(), Period(), 0);
      bool bNewBarEvent  = ( dtBarCurrent != dtBarPrevious);
      if(!bNewBarEvent)
         return;
      
      if(Mode =="dump")
      {
         MqlRates  rates_array[];
         ArraySetAsSeries(rates_array,true);
         
         int iRatesArray = CopyRates(Symbol(),Period(),dtBarCurrent,2,rates_array);
         OHLCBar bar;
         bar.name  = Symbol();
         bar.date  = rates_array[1].time;
         bar.open  = rates_array[1].open;
         bar.high  = rates_array[1].high;
         bar.low   = rates_array[1].low;
         bar.close = rates_array[1].close;
         
         int size = ArraySize(bars);
         ArrayResize(bars, size + 1);
         bars[size] = bar;
         return;
      }
      if(Mode =="backtest")
      {
         MqlRates  rates_array[];
         ArraySetAsSeries(rates_array,true);
         
         int iRatesArray = CopyRates(Symbol(),Period(),dtBarCurrent,2,rates_array);
         int i = FindBarByDate(rates_array[1].time);
         if(i == -1)
            return;
         CheckOpenPosition(rates_array[1].time, bars[i].cla);
         return;
      }    
            
      if(Model_available & dtBarPrevious != WRONG_VALUE){
            if(debug_level>1)
            {
               Print("Check for position: ", Symbol());
               Print("dtBarPrevious: ", dtBarPrevious);
            }
            double sResult = 0.0;
            if(SymbolEval == "CURRENT")
               EvaluateBar(Symbol(), Period(), dtBarPrevious);
            else
               EvaluateBar(SymbolEval, Period(), dtBarPrevious);
            if(debug_level>0)
            {
               Print("Class_ratio: ", sResult);
            }
            CheckOpenPosition(dtBarCurrent, sResult);
      }
  } // void OnTick()
  
void CheckOpenPosition(datetime currentTime, double cla)
{
   if(cla < class_treshold)
      return;
   ExtSymbolInfo.Name(Symbol());
   ExtSymbolInfo.Refresh();
   ExtSymbolInfo.RefreshRates();
   int digits = ExtSymbolInfo.Digits();

   double   ma50[2];
   double   ma200[2];
   if(CopyBuffer(ExtHandle50,0,currentTime,2,ma50)!=2)
     {
      Print("CopyBuffer from iMA-50 failed, no data");
      return;
     }
   if(CopyBuffer(ExtHandle200,0,currentTime,2,ma200)!=2)
     {
      Print("CopyBuffer from iMA-200 failed, no data");
      return;
     }
     
   int trend_direction = 0;
   if(ma50[1] > ma200[1])
      trend_direction = 1;
   else
      trend_direction = -1;

   if(ADX_treshold != 0)
   {
      double buffer[];
      ArrayFree(buffer);
      ArraySetAsSeries(buffer,true);
      int handle = iADX(Symbol(),Period(), 14);
      int iResultCount = CopyBuffer(handle,0,currentTime,1,buffer);
      IndicatorRelease(handle);
   
      double ADXValue = buffer[0];
      if(ADXValue < 8 | ADXValue > 22)
      {
         Print("Rejected: ADX treshold. ADXValue:", ADXValue, " ADX_treshold:", ADX_treshold);
         return;  
      }
   }
   
   double ATRValue = GetATRValue(currentTime);
      
   double lot_size = 0.0;
   lot_size = GetLots(_Symbol, ATRValue*risk_rt * pow(10, digits), MaxRisk_Money);

   if(debug_level>1)
      Print("---Lot size=", lot_size,", points=",ATRValue*risk_rt * pow(10, digits),", MaxRisk_Money=",MaxRisk_Money);
   
   double price;
   ENUM_ORDER_TYPE ORDER_TYPE_BUY_SELL;
   if(trend_direction == 1)
   {
      ORDER_TYPE_BUY_SELL = ORDER_TYPE_BUY;
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      }
   else
   {
      ORDER_TYPE_BUY_SELL = ORDER_TYPE_SELL;
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
   double tp = 0;
   double sl = 0;
   if(prft_rt != 0)
      tp = price + ATRValue * trend_direction * prft_rt;
   sl = price - ATRValue * trend_direction * risk_rt;
     
   if(debug_level>0)
      PrintFormat("PositionOpen: %s %s at %G (sl=%G tp=%G). lot_size=%G. cla=%G",
                              _Symbol, trend_direction, price, sl, tp, lot_size, cla);
      
   bool is_opened = ExtTrade.PositionOpen(_Symbol,
      ORDER_TYPE_BUY_SELL,
      lot_size, 
      price,
      sl,
      tp,
      currentTime+"="+cla);
   if(is_opened)
   {
      ulong ticket_id = ExtTrade.ResultDeal(); 
      PositionSelectByTicket(ticket_id);
      PositionState state;
      state.ticket = ticket_id;   
      state.symbol = Symbol();
      state.magic = PositionGetInteger(POSITION_MAGIC);
      state.volume = PositionGetDouble(POSITION_VOLUME);
      state.price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      
      storage.Set(ticket_id, state);
   }
}
//+------------------------------------------------------------------+
double GetLots(string sSumbol, double dbStopLoss, double dbRiskMoney){

   double
      dbLotsMinimum  = SymbolInfoDouble( sSumbol, SYMBOL_VOLUME_MIN       ),
      dbLotsMaximum  = SymbolInfoDouble( sSumbol, SYMBOL_VOLUME_MAX       ),
      dbLotsStep     = SymbolInfoDouble( sSumbol, SYMBOL_VOLUME_STEP      ),
      dbTickValue    = SymbolInfoDouble( sSumbol, SYMBOL_TRADE_TICK_VALUE ),
      dbCalcLot      = fmin(  dbLotsMaximum,                  // Prevent too greater volume;
                       fmax(  dbLotsMinimum,                  // Prevent too smaller volume
                       round( dbRiskMoney / (dbStopLoss * dbTickValue)       // Calculate stop risk
                       / dbLotsStep ) * dbLotsStep ) );       // Align to step value
   return(dbCalcLot);
   
}

//+------------------------------------------------------------------+
double GetLotsForPartial(string sSumbol, double dInitial, int dPercent){

   double
      dbLotsMinimum  = SymbolInfoDouble( sSumbol, SYMBOL_VOLUME_MIN       ),
      dbLotsMaximum  = SymbolInfoDouble( sSumbol, SYMBOL_VOLUME_MAX       ),
      dbLotsStep     = SymbolInfoDouble( sSumbol, SYMBOL_VOLUME_STEP      ),
      dbCalcLot      = fmin(  dbLotsMaximum,                  // Prevent too greater volume;
                       fmax(  dbLotsMinimum,                  // Prevent too smaller volume
                       round( dInitial / 100 * dPercent       // Calculate lots to decrease
                       / dbLotsStep ) * dbLotsStep ) );       // Align to step value
   return(dbCalcLot);
   
}

int FindBarByDate(datetime target)
{
   int left = 0;
   int right = ArraySize(bars) - 1;

   while(left <= right)
   {
      int mid = left + (right - left) / 2;
      datetime midDate = bars[mid].date;

      if(midDate < target)
         left = mid + 1;
      else if(midDate > target)
         right = mid - 1;
      else
         return mid;
   }

   return -1;
}

double GetATRValue(datetime currentTime=0)
{
   double PriceArray[];
   ArraySetAsSeries(PriceArray, true);
   if(currentTime == 0)
      CopyBuffer(ATRHandle14, 0, 0, 3, PriceArray);
   else
      CopyBuffer(ATRHandle14, 0, currentTime, 3, PriceArray);
   double ATRValue = NormalizeDouble(PriceArray[0], 5);
   if(debug_level>0)
      Print("ATRValue:", ATRValue, " currentTime:", currentTime);
   return ATRValue;
}
//
//bool IsTracked(ulong ticket)
//{
//   return storage.Exists("pos:" + (string)ticket);
//}