//+------------------------------------------------------------------+
//|                      Fisher Transform                            |
//|                        original Fisher routine by Yura Prokofiev |
//+------------------------------------------------------------------+
#include <utility.mqh>

#property copyright "Copyright © 2017, Macdulio"
#property link      "http://macdulio.blogspot.co.uk"

#property indicator_separate_window
#property indicator_minimum -2
#property indicator_maximum 2
#property indicator_height 300
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red

//---- input parameters
extern int FisherPeriod   = 10;
extern double FisherRange = 1.0;

//---- indicator buffers
double FishSigBuf[];
double FishTrigBuf[];
double FishnValBuf[];

int subwindow_idx=NULL;

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //Print("deinit Fisher Indicator objects...");
   ObjectsDeleteAll(0, subwindow_idx, EMPTY); 
   return;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int OnInit()  {
   int id=0;
   string short_name="Fisher Transform("+FisherPeriod+","+
      (string)(FisherRange*-1)+","+(string)FisherRange+")";
      
   IndicatorShortName(short_name);
   IndicatorBuffers(3);
   IndicatorDigits(2);
   
   
   SetIndexBuffer(0, FishSigBuf);
   SetIndexLabel(0, "Fisher Signal");
   ArraySetAsSeries(FishSigBuf,false);
   ArrayInitialize(FishSigBuf, 0);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2);
   
   SetIndexBuffer(1, FishTrigBuf);
   SetIndexLabel(1, "Fisher Trigger"); 
   ArraySetAsSeries(FishTrigBuf,false);
   ArrayInitialize(FishTrigBuf, 0);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,2);

   SetIndexBuffer(2, FishnValBuf);
   SetIndexLabel(2, "Fisher nVal"); 
   ArraySetAsSeries(FishnValBuf,false);
   ArrayInitialize(FishnValBuf, 0);
   SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,2);
   SetIndexEmptyValue(2,0.0); 
      
   // Upper/lower bands
   string ob="Fisher OB Line";
   string os="Fisher OS Line"; 
   subwindow_idx=ChartWindowFind(id, short_name);
   int res = ObjectCreate(id, os, OBJ_HLINE, subwindow_idx, Time[0], FisherRange*-1);
   ObjectSetInteger(id, os, OBJPROP_COLOR, clrGreen); 
   ObjectSetInteger(id, os, OBJPROP_STYLE, STYLE_SOLID); 
   ObjectSetInteger(id, os, OBJPROP_WIDTH, 2); 
   ObjectSetInteger(id, os, OBJPROP_BACK, false); 
   ObjectSetInteger(id, os, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(id, os, OBJPROP_SELECTED, true); 
   ObjectSetInteger(id, os, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, os, OBJPROP_ZORDER, 0); 
   res = ObjectCreate(id, ob, OBJ_HLINE, subwindow_idx, Time[0], FisherRange);
   ObjectSetInteger(id, ob, OBJPROP_COLOR, clrGreen); 
   ObjectSetInteger(id, ob, OBJPROP_STYLE, STYLE_SOLID); 
   ObjectSetInteger(id, ob, OBJPROP_WIDTH, 2); 
   ObjectSetInteger(id, ob, OBJPROP_BACK, false); 
   ObjectSetInteger(id, ob, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(id, ob, OBJPROP_SELECTED, true); 
   ObjectSetInteger(id, ob, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, ob, OBJPROP_ZORDER, 0);  
   if(!res)
      log("ERROR creating Fisher line: ",err_msg(GetLastError()), ", subwindow_idx: ", subwindow_idx);
 
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
// The amount of bars not changed after the indicator had been launched last. 
// DO NOT MIX OLD STYLE (IndicatorCounted()) WITH NEW STYLE
//+------------------------------------------------------------------+
int OnCalculate (const int rates_total,      // size of input time series 
                 const int prev_calculated,  // bars handled in previous call 
                 const datetime& time[],     // Time 
                 const double& open[],       // Open 
                 const double& high[],       // High 
                 const double& low[],        // Low 
                 const double& close[],      // Close 
                 const long& tick_volume[],  // Tick Volume 
                 const long& volume[],       // Real Volume 
                 const int& spread[]         // Spread 
   ) {
   double MinL=0, MaxH=0, nVal2=0, hl2=0;
   int iBar,iTSBar;
 
   if(prev_calculated==0) {
      iBar=FisherPeriod;
      ArrayInitialize(FishSigBuf,0);
      ArrayInitialize(FishTrigBuf,0);
      ArrayInitialize(FishnValBuf,0);
   }
   else
      iBar=prev_calculated;
   
   // iBar: non-Timeseries (left-to-right) index
   for(; iBar<rates_total; iBar++) { 
      if(iBar < 0 || iBar >= ArraySize(time)) {
         log("Invalid iBar:"+iBar);
         return -1;
      } 
      iTSBar=Bars-iBar-1;  
      MaxH = High[iHighest(NULL,0,MODE_HIGH,FisherPeriod,iTSBar)];
      MinL = Low[iLowest(NULL,0,MODE_LOW,FisherPeriod,iTSBar)];
      hl2 = (High[iTSBar]+Low[iTSBar])/2;
      FishnValBuf[iBar] = 0.33*2* ((hl2 - MinL) / (MaxH - MinL) - 0.5) + 0.67*FishnValBuf[iBar-1];    
      //nVal2 = nVal1 > 0.99 ? 0.999 : nVal1 < -0.99 ? -0.999 : nVal1;
      nVal2 = MathMin(MathMax(FishnValBuf[iBar],-0.999),0.999);
      FishSigBuf[iBar] = 0.5*MathLog((1+nVal2)/(1-nVal2)) + 0.5*FishSigBuf[iBar-1];
      FishTrigBuf[iBar] = FishSigBuf[iBar-1];
   }
   
   arr_dump("FishSigBuf", FishSigBuf, iBar-10, 10, 1);
   log("OnCalculate() done. PrevBars:"+prev_calculated+", NowBars:"+rates_total+", FishSigBuf.Size:"+ArraySize(FishSigBuf)+".");   
   return(rates_total);   
}