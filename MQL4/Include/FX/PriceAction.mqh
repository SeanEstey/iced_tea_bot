//+----------------------------------------------------------------------------+
//|                                                         FX/PriceAction.mqh |
//|                                                 Copyright 2018, Sean Estey |
//+----------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict
#include <FX/Utility.mqh>
#include <FX/ChartObjects.mqh>

//---Enums
enum CandleType {NONE,STL,STH,ITL,ITH,LTL,LTH};
enum OrderBlockType {BEARISH,BULLISH,BREAKER};

//---Globals
string SwingLabels[7] = {"None","STL","STH","ITL","ITH","LTL","LTH"};

//---Structs
struct Rect {
   double x1;
   double y1;
   double x2;
   double y2;
};


//-----------------------------------------------------------------------------+
//+*********************************CLASSES ***********************************+
//-----------------------------------------------------------------------------+

//-----------------------------------------------------------------------------+
/* A high/low candle surrounded by 2 lower highs/higher lows.
 * Categorized into: Short-term (ST), Intermediate-term (IT), Long-term (LT) */
//-----------------------------------------------------------------------------+
class Candle {
   public:
      int TF;
      datetime DT;
      int Shift;
      double O;
      double C;
      double H;
      double L;
      CandleType Type;
      bool IsAnnotated;
      
      void Candle(int tf, int shift, CandleType type=NONE) {
         TF=tf;
         Shift=shift;
         DT=Time[shift];
         O=Open[shift];
         C=Close[shift];
         H=High[shift];
         L=Low[shift];
         Type=type;
         IsAnnotated=false;
      }
      void Annotate(bool toggle){
         if(toggle==true) {
            if(Type==STL || Type==ITL || Type==LTL)
               CreateText(SwingLabels[Type], Shift, ANCHOR_UPPER);
            else if(Type==STH || Type==ITH || Type==LTH)
               CreateText(SwingLabels[Type], Shift, ANCHOR_LOWER);
            IsAnnotated=true;
         }
         else {
            ObjectDelete(0,SwingLabels[Type]+"_"+(string)Shift);
            IsAnnotated=false;
         }
      }
      string ToString(){return "Candle at "+TimeToStr(DT)+", Close:"+(string)C;}
};

//-----------------------------------------------------------------------------+
/* Describes the candle series of an impulse movement: a
 * strong price swing up/down, generated by an OrderBloc 
 * Non-TimeSeries (left-to-right) */
//-----------------------------------------------------------------------------+
class Impulse {
   public:
      int Direction;    // 1:up, -1:down, 0:none
      int StartBar;
      int EndBar;
      int ChainLen;
      int OderBlockBar;
      datetime StartDt;
      datetime EndDt;
      double Height;
      double nDeviations;
      
      void Impulse(int tf, int ibar1, int ibar2, double nDeviations=0) {
         double point=MarketInfo(Symbol(),MODE_POINT);
         Direction=Close[ibar1]>Open[ibar1] ? 1 : Close[ibar1]<Open[ibar1] ? -1 : 0;
         StartBar=ibar1;
         EndBar=ibar2;
         ChainLen=ibar2-ibar1;
         StartDt=Time[ibar1];
         EndDt=Time[ibar2];
         Height=Close[ibar2]-Open[ibar1]/point;
         nDeviations=nDeviations;
      }
      string ToString(){
         double point=MarketInfo(Symbol(),MODE_POINT);
         string dir= Direction == 1 ? "upward" : Direction ==-1 ? "downward" : "sideways"; 
         string s = TimeToStr(StartDt)+": "+(string)ChainLen+"-chain "+dir+" impulse, height:"+DoubleToStr(Height,2)+" pips, "+DoubleToStr(nDeviations,2)+"x STD. ";
         return s;
      }
};

//-----------------------------------------------------------------------------+
/* Stores rectangular area of an OrderBlock, the candle(s) that
 * generated it, the impulse(s) it produced, and history of
 * price retests. */
//-----------------------------------------------------------------------------+ 
class OrderBlock {
   public:
      int TF;
      datetime Dt;
      double PriceTop;
      double PriceEQ;
      double PriceBottom;
      string Label;
      Rect DrawRect;
      OrderBlockType Type;
   
      void OrderBlock(int tf, int ibar, OrderBlockType type, string lbl=""){
         TF=tf;
         Dt=Time[ibar];
         PriceTop=High[ibar];
         PriceBottom=Low[ibar];
         PriceEQ=(PriceTop-PriceBottom)/2;
         //DrawRect.x1=Dt;
         //DrawRect.y1=PriceTop;
         //DrawRect.x2=Time[ibar-50];
         //DrawRect.y2=PriceBottom;
         Type=type;
         Label=lbl;
      }
      string ToString() {return Label;}
};


//-----------------------------------------------------------------------------+
//+****************************** METHODS *************************************+
//-----------------------------------------------------------------------------+

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
bool isSwingHigh(int iBar, const double &highs[]) {
   if(iBar <=0 || iBar >=ArraySize(highs)-1)
      return false;
   if(highs[iBar] > highs[iBar+1] && highs[iBar] > highs[iBar-1])
      return true;
   else
      return false;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
bool isSwingLow(int iBar, const double &lows[]) {
   if(iBar<=0 || iBar>=ArraySize(lows)-1)
      return false;
   if(lows[iBar] < lows[iBar+1] && lows[iBar] < lows[iBar-1])
      return true;
   else
      return false;
}

//+---------------------------------------------------------------------------+
//| If iBar arrives at daily close, identify the significant swing highs/lows
//| for that week with chart annotations.
//+---------------------------------------------------------------------------+
void FindSwings(int iBar, Candle* &sl[], Candle* &sh[]) {
   MqlDateTime dt1, dt2;
   TimeToStruct(Time[iBar], dt1);
   
   if(dt1.hour == 18 && dt1.min == 0) {
      //CreateVLine(iBar+1, objs);   
      TimeToStruct(Time[iBar], dt2);
      dt2.day-=1;
      int dailybars = Bars(Symbol(),0, Time[iBar],StructToTime(dt2));
      
      int iLBar = iLowest(Symbol(), 0, MODE_LOW, dailybars, iBar);
      int iHBar = iHighest(Symbol(), 0, MODE_HIGH, dailybars, iBar);
      
      /*CreateLine("daily_low_"+(string)iBar, Time[iBar], Low[iLBar], StructToTime(dt2),
         Low[iLBar], clrRed, objs);         
      CreateLine("daily_high_"+(string)iBar, Time[iBar], High[iHBar], StructToTime(dt2),
         High[iHBar], clrRed, objs);
         */
      
      // Identify significant daily swings 
      if(isSwingLow(iLBar, Low)) {
         Candle* c=new Candle(0,iLBar,STL);
         c.Annotate(true);
         ArrayResize(sl, ArraySize(sl)+1);
         sl[ArraySize(sl)-1]=c;
      }
      if(isSwingHigh(iHBar,High)) {
         Candle* c=new Candle(0,iHBar,STH);
         c.Annotate(true);
         ArrayResize(sh, ArraySize(sh)+1);
         sh[ArraySize(sh)-1]=c;
      }
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void FindImpulses(int iBar, int period, Impulse* &impulses[]) {
   double point=MarketInfo(Symbol(),MODE_POINT);
   
   for(int i=iBar; i<iBar+period; i++) {
      if(i==iBar) {
         // Init new impulse
         ArrayResize(impulses, ArraySize(impulses)+1);
         impulses[ArraySize(impulses)-1]=new Impulse(0,i,i);
         continue;
      }
      
      int dir=Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0;
      Impulse* last = impulses[ArraySize(impulses)-1];
      
      // Merge properties of impulses chained together.
      // New impulse extends move by 1 bar to the left.
      // Extend startdt, start_ibar, and height
      if(last.Direction == dir) {
         //log("Found an impulse chain!");
         last.Height+=(Close[i]-Open[i])/point;
         last.StartBar=i;
         last.ChainLen++;
         last.StartDt=Time[i];
         //impulses[ArraySize(impulses)-1] = last;
      }
      // New impulse
      else {
         ArrayResize(impulses, ArraySize(impulses)+1);
         impulses[ArraySize(impulses)-1]=new Impulse(0,i,i);
      }
   }
}
   
//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void FindOrderBlocks(Impulse* &impulses[], OrderBlock* &obs[],double min_std=3.0){ 
   double heights[];
   ArrayResize(heights,ArraySize(impulses));
   
   for(int i=0; i<ArraySize(impulses); i++) {
      heights[i] = impulses[i].Height;
   }
   double mean_height = Average(heights);
   double variance = Variance(heights, mean_height);
   double std = MathSqrt(variance);
      
   for(int i=0; i<ArraySize(impulses); i++){
      impulses[i].nDeviations = impulses[i].Height/std;
      if(MathAbs(impulses[i].nDeviations) >= min_std) {
         // FIXME. BUGGY
         OrderBlockType type=impulses[i].Direction==1 ? BULLISH : impulses[i].Direction==-1 ? BEARISH : 0;
         obs[ArraySize(obs)-1]= new OrderBlock(0, impulses[i].StartBar+1,type,"OB");
         //ArrayResize(impulses, ArraySize(impulses)+1);
         // **** WARNING: PROBABLY NOT SAFE ********
         //impulses[ArraySize(impulses)-1]=impulses[i];
      }     
   }
   
   //log("Updated impulses from iBar "+(string)iBar+"-"+(iBar+period)+". Impulses:"+(string)ArraySize(impulses));
   log("Found "+(string)ArraySize(obs)+" OrderBlocks!");
   
   /*
   int max_up=0, max_down=0;
   for(int i=1; i<ArraySize(impulses); i++) {      
      if(Impulses[i].Height > impulses[max_up].Height)
         max_up=i;
      else if(impulses[i].Height < impulses[max_down].Height)
         max_down=i;
   }
   
   impulses[max_up].nDeviations = impulses[max_up].Height/std;
   
   if(MathAbs(impulses[max_up].nDeviations) >= 3)
      impulses[max_up].Label=impulses[max_up].start_ibar+1;
      
   Impulses[max_down].n_deviations = Impulses[max_down].height/std;
   if(MathAbs(Impulses[max_down].n_deviations) >= 3)
      Impulses[max_down].ob_ibar=Impulses[max_down].start_ibar+1;
   
   log("Mean chain height:"+DoubleToStr(mean_height,2)+" pips, Std_Dev:"+DoubleToStr(std,2)+" pips");
   
   // Draw OB Rectangles
   
   int OB_RECT_WIDTH=50;
   datetime dt1=iTime(Symbol(),0,Impulses[max_up].ob_ibar);
   double p1=iHigh(Symbol(),0,Impulses[max_up].ob_ibar);
   datetime dt2;
   if(Impulses[max_up].ob_ibar-OB_RECT_WIDTH < 0)
      dt2=iTime(Symbol(),0,0);
   else
      dt2=iTime(Symbol(),0,Impulses[max_up].ob_ibar-OB_RECT_WIDTH);
   double p2=iLow(Symbol(),0,Impulses[max_up].ob_ibar);
   CreateRect(dt1,p1,dt2,p2,ChartObjs);
   
   log(impulseToStr(Impulses[max_up], std));
   log(impulseToStr(Impulses[max_down], std));
   */
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
string GetOrderBlockDesc(int iBar) {
   return "";
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
bool DrawWeeklyLevels(datetime dt1, datetime dt2) {

   // 0..6, Sunday-Saturday
   int day1 = TimeDayOfWeek(dt1);
   int day2 = TimeDayOfWeek(dt2);
   /*
   //MqlDateTime dt1, dt2;
   TimeToStruct(Time[iBar], dt1);
   
   if(dt1.hour == 18 && dt1.min == 0) {
      //CreateVLine(iBar+1, objs);   
      TimeToStruct(Time[iBar], dt2);
      dt2.day-=1;
      int dailybars = Bars(Symbol(),0, Time[iBar],StructToTime(dt2));
      
      int iLBar = iLowest(Symbol(), 0, MODE_LOW, dailybars, iBar);
      int iHBar = iHighest(Symbol(), 0, MODE_HIGH, dailybars, iBar);
      
      CreateLine("daily_low_"+(string)iBar, Time[iBar], Low[iLBar], StructToTime(dt2),
         Low[iLBar], clrRed, objs);         
      CreateLine("daily_high_"+(string)iBar, Time[iBar], High[iHBar], StructToTime(dt2),
         High[iHBar], clrRed, objs);
       
      }
      */
   //Schedule s(SUNDAY,"18:00", FRIDAY, "18:00");
   return false;
}  