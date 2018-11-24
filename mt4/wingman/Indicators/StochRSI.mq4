//+------------------------------------------------------------------+
//|                                            Basic    StochRSI.mq4 |
//|                                 Copyright � 2007, Petr Doroshenko|
//|                                            i7hornet@yahoo.com    |
//+------------------------------------------------------------------+

#include <utility.mqh>

#property copyright "Copyright � 2007, Petr Doroshenko"
#property link      "i7hornet@yahoo.com"

#property indicator_separate_window
#property indicator_height 450
#property indicator_minimum -25
#property indicator_maximum 125
#property indicator_level1 10
#property indicator_level2 20
#property indicator_level3 80
#property indicator_level4 90

#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red

//---- input parameters
extern int RSIPeriod=10;
extern int KPeriod=10;
extern int DPeriod=2;
extern int Slowing=2;
extern int StochOverbought=80;
extern int StochOversold=20;

//---- buffers
double MainBuf[];
double SigBuf[];


int draw_begin1=0;
int draw_begin2=0;
int RPrice=5;
int subwindow_idx=NULL;

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //Print("deinit StochRSI Indicator objects...");
   //ObjectsDeleteAll(ChartID(), subwindow_idx, EMPTY); 
   return;
}


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   int id=0;//ChartID();
   if(IsVisualMode())
      id=0;
      
   string short_name = "StochRSI("+RSIPeriod+","+KPeriod+","+DPeriod+","+Slowing+")";
   string os_name = "StochRSI Oversold Line";
   string ob_name = "StochRSI Overbought Line";
   
   //---- 3 additional buffers are used for counting.
   IndicatorBuffers(2);
   //SetIndexBuffer(2, HighRSIBuf);
   //SetIndexBuffer(3, LowRSIBuf);
   //SetIndexBuffer(4, rsi);
   //---- indicator lines
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(0, MainBuf);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(1, SigBuf);
   //---- name for DataWindow and indicator subwindow label
   short_name="StochRSI("+RSIPeriod+","+KPeriod+","+DPeriod+","+Slowing+")";
   IndicatorShortName(short_name);
   SetIndexLabel(0,short_name);
   SetIndexLabel(1,"Signal");
   draw_begin1=KPeriod+Slowing;
   draw_begin2=draw_begin1+DPeriod;
   SetIndexDrawBegin(0,draw_begin1);
   SetIndexDrawBegin(1,draw_begin2);
  
   // Overbought/Oversold lines
   subwindow_idx=ChartWindowFind(id, short_name);
   int res = ObjectCreate(id, os_name, OBJ_HLINE, subwindow_idx, Time[0], StochOversold);
   ObjectSetInteger(id, os_name, OBJPROP_COLOR, clrGreen); 
   ObjectSetInteger(id, os_name, OBJPROP_STYLE, STYLE_DOT); 
   ObjectSetInteger(id, os_name, OBJPROP_WIDTH, 2); 
   ObjectSetInteger(id, os_name, OBJPROP_BACK, false); 
   ObjectSetInteger(id, os_name, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(id, os_name, OBJPROP_SELECTED, true); 
   ObjectSetInteger(id, os_name, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, os_name, OBJPROP_ZORDER, 0); 
   res = ObjectCreate(id, ob_name, OBJ_HLINE, subwindow_idx, Time[0], StochOverbought);
   ObjectSetInteger(id, ob_name, OBJPROP_COLOR, clrGreen); 
   ObjectSetInteger(id, ob_name, OBJPROP_STYLE, STYLE_DOT); 
   ObjectSetInteger(id, ob_name, OBJPROP_WIDTH, 2); 
   ObjectSetInteger(id, ob_name, OBJPROP_BACK, false); 
   ObjectSetInteger(id, ob_name, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(id, ob_name, OBJPROP_SELECTED, true); 
   ObjectSetInteger(id, ob_name, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, ob_name, OBJPROP_ZORDER, 0); 
   if(!res)
      Print("ERROR creating Stoch HLINE: ",err_msg(GetLastError()));
   
   return(INIT_SUCCEEDED);
}
  
//+------------------------------------------------------------------+
//| Stochastics formula applied to RSI                               |
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
   double rsi, low_rsi, high_rsi, sum_K;
   int pos, i;
   
   //--- counting from 0 to rates_total
   ArraySetAsSeries(MainBuf,false);
   ArraySetAsSeries(SigBuf,false);  
 
   //--- preliminary calculation
   if(prev_calculated>1)
      pos=prev_calculated-1;
   else {
      for(i=0;i<=draw_begin1;i++)
         MainBuf[i]=0;
      for(int i=0;i<=draw_begin2;i++)
         SigBuf[i]=0;
      pos=i;
   }
   
   //log("StochRSI loop. pos="+pos+", n="+rates_total);
   
   for(i=pos; i<rates_total; i++) {        
      rsi=iRSI(NULL,0,RSIPeriod,PRICE_TYPICAL,i);
      high_rsi=rsi;
      low_rsi=rsi;
      
      for(int x=0;x<KPeriod;x++){
         low_rsi=MathMin(low_rsi,iRSI(NULL,0,RSIPeriod, PRICE_TYPICAL,i-x));
         high_rsi=MathMax(high_rsi,iRSI(NULL,0,RSIPeriod,PRICE_TYPICAL,i-x));
      }
      
      sum_K=0;
      for(int x=0;x<DPeriod;x++){
         sum_K=sum_K + MainBuf[i-x];
      }
      
      if(high_rsi-low_rsi == 0)
         MainBuf[i] = 100.0;
      else
         MainBuf[i]=((rsi-low_rsi)/(high_rsi-low_rsi))*100;
         
      SigBuf[i]=sum_K/DPeriod;
   }
    
   log("OnCalculate updated StochRSI Bars["+pos+".."+(pos+rates_total)+"].");
   dump("MainBuf.first", MainBuf, 0, 50);
  
   dump("MainBuf.tail", MainBuf,ArraySize(MainBuf)-50,50); 
   dump("SigBuf", SigBuf, pos, 50);
   
   return(rates_total);
}


//+------------------------------------------------------------------+
//| Stochastics formula applied to RSI                               |
//+------------------------------------------------------------------+
void dump(string name, double& arr[], int pos, int n) {
   string values="[";
   
   if(pos+n >= ArraySize(arr))
      pos=ArraySize(arr)-n-1;
      
   for(int i=0; i<n; i++) {
      if(pos+i >= ArraySize(arr))
         break;
      values+= DoubleToString(arr[pos+i],1) + ", ";
   
   }             

   log(name+"["+(string)pos+".."+(pos+n)+"]: "+values);
}