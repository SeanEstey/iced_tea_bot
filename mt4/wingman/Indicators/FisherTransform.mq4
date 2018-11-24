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
#property indicator_height 350
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red

//---- input parameters
extern int FisherPeriod   = 10;
extern double FisherRange = 1.0;

//---- indicator buffers
double FishSigBuf[];
double FishTrigBuf[];

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
   int id=0; //ChartID();
   if(IsVisualMode())
      id=0; 
  
   // Signal + Trigger lines
   IndicatorBuffers(2);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(0, FishSigBuf);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(1, FishTrigBuf);
   ArrayInitialize(FishSigBuf, 0);
   ArrayInitialize(FishTrigBuf, 0);
   string short_name="Fisher Transform("+FisherPeriod+","+(string)(FisherRange*-1)+","+(string)FisherRange+")";
   IndicatorShortName(short_name);
   IndicatorDigits(3);
   SetIndexLabel(0, "Fisher Signal");
   SetIndexLabel(1, "Fisher Trigger"); 
   SetIndexDrawBegin(0, FisherPeriod);
   SetIndexDrawBegin(1, FisherPeriod);
  
   // Overbought/Oversold lines.
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
   int i,pos;
   //--- counting from 0 to rates_total
   ArraySetAsSeries(FishSigBuf,false);
   ArraySetAsSeries(FishTrigBuf,false);
 
   //--- preliminary calculation
   if(prev_calculated>1)
      pos=prev_calculated-1;
   else {
      FishSigBuf[0]=0;
      FishTrigBuf[0]=0;
      pos=1;
   }
   
   double MinL=0, MaxH=0, nVal1=0, nVal1_prev=0, nVal2=0, hl2=0;
   
   //--- main loop of calculations
   for(i=pos; i<rates_total; i++) {
      MaxH = High[iHighest(NULL,0,MODE_HIGH,FisherPeriod,i)];
      MinL = Low[iLowest(NULL,0,MODE_LOW,FisherPeriod,i)];
      hl2 = (High[i]+Low[i])/2;
      nVal1 = 0.33*2* ((hl2 - MinL) / (MaxH - MinL) - 0.5) + 0.67*nVal1_prev;    
      //nVal2 = nVal1 > 0.99 ? 0.999 : nVal1 < -0.99 ? -0.999 : nVal1;
      nVal2 = MathMin(MathMax(nVal1,-0.999),0.999);
      FishSigBuf[i] = 0.5*MathLog((1+nVal2)/(1-nVal2)) + 0.5*FishSigBuf[i-1];
      FishTrigBuf[i] = FishSigBuf[i-1];
      nVal1_prev=nVal1;
   }
   
   log("OnCalculate updated Fisher Bars["+pos+".."+(pos+rates_total)+"].");
   dump(pos, 10);
   
   return(rates_total);   
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void dump(int pos, int n) {
   string values="[";
   int k = pos+n > ArraySize(FishSigBuf) ? ArraySize(FishSigBuf)-n : pos;
   
   for(; k<ArraySize(FishSigBuf); k++) {
      values+= DoubleToString(FishSigBuf[k],3) + ", ";
   }
   values+="]";
   log("Fisher.tail("+(string)n+"):"+values);
}