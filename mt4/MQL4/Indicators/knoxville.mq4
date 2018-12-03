//+------------------------------------------------------------------+
//|                                         knoxville_divergence.mq4 |
//|                                                     Paúl Herrera |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Avanti Servicios Financieros, C.A."
#property link      "https://avantifs.herokuapp.com"
#property version   "2.1"
#property strict
#property indicator_chart_window

//--- input parameters
input int      Periods = 14;
input bool     BullishDivergence = True;
input bool     BearishDivergence = True;

int arrowCount = 0;
double divisor = MathPow(10, Digits);


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   
//---
   return(INIT_SUCCEEDED);
  }
  
 void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_ARROW);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int limit = rates_total - prev_calculated;
   int KD, bar;
   
   if(limit > 1) {
      for(bar=1; bar<limit-Periods; bar++){
         double momo[14];
         // Get momentum array
         for(int j=0; j<Periods; j++) {
            //Print("Bar:",bar,", MaxBar:",limit-Periods, ", momo[",j,"]:",momo[j]);
            momo[j]=iMomentumOnArray(close,0,Periods,bar+j);
            
         }
            
         // Making Lower Lows?
         double mom_low1=ArrayMinimum(momo,Periods/2,0);
         double mom_low2=ArrayMinimum(momo,Periods/2,Periods/2);
         // Making Higher Highs?
         double mom_high1=ArrayMaximum(momo,Periods/2,0);
         double mom_high2=ArrayMaximum(momo,Periods/2,Periods/2);
         
         // Price making LL's/HH's?
         bool LL = ArrayMinimum(low,Periods/2, bar) < ArrayMinimum(low, Periods/2, bar+(Periods/2));
         bool HH = ArrayMaximum(high,Periods/2, bar) < ArrayMaximum(high, Periods/2, bar+(Periods/2));
         
         if(LL) {
            Print("Price making Lower Lows from Bars:",bar,"-",bar+Periods);
         }
         if(HH) {
            Print("Price making Higher Highs from Bars:",bar,"-",bar+Periods);
            //KD = knoxville_divergence(bar);
            //create_arrow(KD, bar, time, high, low);
         }
      }
   }
   else if(limit == 1){
      //KD = knoxville_divergence(1);
      //create_arrow(KD, 1, time, high, low);
   }
   return(rates_total);
}

//------------------------------------------------------------------------------ 1 --
//-----------------------          FUNCTIONS          -------------------------- 1 --
//------------------------------------------------------------------------------ 1 --


//+------------------------------------------------------------------+
//| Returns: 1 for bullish div, -1 for bearish div
//+------------------------------------------------------------------+
int knoxville_divergence(int bar){
   int MinPeriod = 4, KD = 0, i, j;
   int os[210], ob[210];
   double rsi = 50;
   
   ArrayInitialize(os,999999999);
   ArrayInitialize(ob,999999999);
   
   //---- Checking if oversold/overbought.
   for(j=0; j<=Periods; j++){
      rsi = iRSI(NULL, 0, Periods, PRICE_CLOSE, bar + j);
      
      if(rsi <= 30)
         os[j] = bar + j;
      if(rsi >= 70)
         ob[j] = bar + j;
   }
     
   ArraySort(os);
   ArraySort(ob);

   if(bar<=0)
      return(0);
   
   // Bullish Div: momentum making HH's
   if(iMomentum(NULL,0,Periods,PRICE_CLOSE,bar) > iMomentum(NULL,0,Periods,PRICE_CLOSE,bar+Periods)){
      //if(iClose(NULL,0,bar) < iClose(NULL,0,bar+Periods)){
         // Price making Lower Lows
         if(iLow(NULL,0,iLowest(NULL,0,MODE_LOW,Periods,bar)) <= iLow(NULL,0,iLowest(NULL,0,MODE_LOW,Periods,bar+Periods+1))){
           
            for(j=0; j<ArraySize(os); j++) {
               if(os[j] <= bar+i) {
                  Print("Bull Div on Bars:",bar+i,"->",bar,". OS on Bar:",os[j],". Arrow",arrowCount+1);
                  return 1;
               }
            }
         }
      //}
   }
   // Bearish Div: Decreasing momentum on increasing price
   if(iMomentum(NULL,0,Periods,PRICE_CLOSE,bar) < iMomentum(NULL,0,Periods,PRICE_CLOSE,bar+Periods)){
      //if(iClose(NULL,0,bar) > iClose(NULL,0,bar+Periods)){
         // Price making Higher High
         if(iHigh(NULL,0,iHighest(NULL,0,MODE_HIGH,Periods,bar)) >= iHigh(NULL,0,iHighest(NULL,0,MODE_HIGH,Periods,bar+Periods+1))){
            for(j=0; j < ArraySize(os); j++){
               if(ob[j] <= bar + i){
                  Print("Bear Div on Bars:",bar+i,"->",bar,". OB on Bar:",ob[j],". Arrow",arrowCount+1);
                  return -1;
               }
            }
         }
      //}
   }       
   return(0);
}
 
 
void create_arrow(int KD, int period, const datetime &time[], const double &high[],
                const double &low[])
   {
      string name;
      
      if (KD == 1)
        {
           arrowCount++;
           name = get_name();
           ObjectCreate(0,name,OBJ_ARROW,0,0,0,0,0);          // Create an arrow
           ObjectSetInteger(0,name,OBJPROP_ARROWCODE,225);    // Set the arrow code
           ObjectSetInteger(0,name,OBJPROP_TIME,time[period]);        // Set time
           ObjectSetDouble(0,name,OBJPROP_PRICE,high[period] + 2.5*iATR(NULL,0,10,period));       // Set price
           ObjectSetInteger(0,name,OBJPROP_WIDTH,3);
           ObjectSetInteger(0,name,OBJPROP_COLOR,clrForestGreen);
           ChartRedraw(0);
        }
      else if (KD == -1)
        {
           arrowCount++;
           name = get_name();
           ObjectCreate(0,name,OBJ_ARROW,0,0,0,0,0);          // Create an arrow
           ObjectSetInteger(0,name,OBJPROP_ARROWCODE,226);    // Set the arrow code
           ObjectSetInteger(0,name,OBJPROP_TIME,time[period]);        // Set time
           ObjectSetDouble(0,name,OBJPROP_PRICE,low[period] - 0.5*iATR(NULL,0,10,period));       // Set price
           ObjectSetInteger(0,name,OBJPROP_WIDTH,3);
           ChartRedraw(0); 
        }
   }
   
   
string get_name()
   {
    return(StringConcatenate("arrow", IntegerToString(arrowCount)));
   }
 
//+------------------------------------------------------------------+