//+------------------------------------------------------------------+
//|                                                  RatesExport.mq5 |
//|                               Copyright 2026, shiqarno@proton.me |
//|                                 https://www.shiqarnozaibatsu.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, shiqarno@proton.me"
#property link      "https://www.shiqarnozaibatsu.com"
#property version   "1.00"
#property script_show_inputs
//--- input parameters
input datetime DateFrom = D'2020.01.01 00:00:00';
input datetime DetaTo   = D'2026.01.01 00:00:00';
input string   FileName = "eurusd_h1.csv";
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
      MqlRates  rates_array[];
      ArraySetAsSeries(rates_array,true);
      int iRatesArray = CopyRates(Symbol(),Period(),DateFrom,DetaTo,rates_array);
      
      int header = FileOpen(FileName,FILE_READ|FILE_WRITE|FILE_ANSI|FILE_TXT);
      if(header == INVALID_HANDLE){
         Alert("Error opening file");
         return;
      }
      
      FileSeek(header,0,SEEK_END);
      FileWrite(header, "name,date,open,high,low,close,volume,category");
      Comment("Processing...");
      for(int i=iRatesArray-1;i>0;i--)
      {
         string sString = "";
         int iRet = StringConcatenate(sString, 
         Symbol(), ",",
         TimeToString(rates_array[i].time,TIME_DATE) +" "+ TimeToString(rates_array[i].time,TIME_MINUTES), ",",
         rates_array[i].open, ",",
         rates_array[i].high, ",",
         rates_array[i].low, ",",
         rates_array[i].close, ",",
         rates_array[i].tick_volume,",",
         "w"
         );         
         FileWrite(header, sString);
      } 
      Comment("Done: ", iRatesArray, " rows", 
                  "\n", FileName);
      FileClose(header);
  }
//+------------------------------------------------------------------+
