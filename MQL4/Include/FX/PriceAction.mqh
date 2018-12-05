//+----------------------------------------------------------------------------+
//|                                                         FX/PriceAction.mqh |
//|                                                 Copyright 2018, Sean Estey |
//+----------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict
#include <FX/Utility.mqh>
#include <FX/ChartObjects.mqh>

//---Enums
enum SwingType {SWING_HIGH, SWING_LOW};
enum CandleType {NONE,STL,STH,ITL,ITH,LTL,LTH};

//---Globals
string SwingLabels[7] = {"None","STL","STH","ITL","ITH","LTL","LTH"};

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
               CreateText(SwingLabels[Type], Shift, ANCHOR_UPPER,NULL,0,0,"Arial",10,clrBlack);
            else if(Type==STH || Type==ITH || Type==LTH)
               CreateText(SwingLabels[Type], Shift, ANCHOR_LOWER,NULL,0,0,"Arial",10,clrBlack);
            IsAnnotated=true;
         }
         else {
            ObjectDelete(0,SwingLabels[Type]+"_"+(string)Shift);
            IsAnnotated=false;
         }
      }
      string ToString(){return "Candle at "+TimeToStr(DT)+", Close:"+(string)C;}
};

//+****************************** METHODS *************************************+

void AppendCandle(Candle* c, Candle* &list[]) { 
   ArrayResize(list, ArraySize(list)+1);
   list[ArraySize(list)-1]=c;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void DrawLevels(string symbol, ENUM_TIMEFRAMES tf, int offset, int count,
                color clr, string& objs[]){
   datetime start_dt,end_dt;
   
   for(int i=offset+count-1; i>0; i--) {
      start_dt=iTime(symbol, tf,offset+i);
      if(i==1)
         end_dt = TimeCurrent();
      else
         end_dt=iTime(symbol, tf,offset+i-1);
      
      double high = iHigh(symbol, tf, offset+i);
      double low = iLow(symbol, tf, offset+i);
  
      string name1="high_line__p"+(string)tf+"_"+(string)(offset+i);
      string name2="low_line_p"+(string)tf+"_"+(string)(offset+i);
      
      CreateLine(name1,start_dt,high,end_dt,high,clr,objs);
      CreateLine(name2,start_dt,low,end_dt,low,clr,objs);
      
      //log("Low/High levels for "+TimeToStr(start_dt,TIME_DATE)+" to "+
      //   TimeToStr(end_dt,TIME_DATE)+". High:"+(string)high+", Low:"+(string)low);
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void DrawSwingLabels(string symbol, ENUM_TIMEFRAMES tf, int offset, int count, color clr,
                     const double &lows[], const double &highs[],
                     Candle* &sl[], Candle* &sh[], string& objs[]) {
   datetime start_dt,end_dt;
   
   // Find Short-Term swings
   for(int i=offset+count-1; i>0; i--) {      
      if(isSwingHigh(offset+i,highs)) {
         Candle* c=new Candle(tf,i,STH);
         c.Annotate(true);
         AppendCandle(c, sh);
      }
      else if(isSwingLow(offset+i,lows)) {
         Candle* c=new Candle(tf,i,STL);
         c.Annotate(true);
         AppendCandle(c, sl);
      }   
   }
   
   // Find Intermediate-Term Swings
   
   for(int i=1; i<ArraySize(sl)-1; i++) {
      Candle* c=sl[i];
      if(c.L >= sl[i-1].L || c.L >= sl[i+1].L)
         continue;
      // Delete existing lbl, re-assign Type, recreate lbl
      c.Annotate(false);
      c.Type=ITL;
      c.Annotate(true);
      log("ITL swing, Shift:"+(string)c.ToString());
   }
     
   for(int i=1; i<ArraySize(sh)-1; i++) {
      Candle* c=sh[i];
      if(c.H <= sh[i-1].H || c.H <= sh[i+1].H)
         continue;
      // Delete existing lbl, re-assign Type, recreate lbl
      c.Annotate(false);
      c.Type=ITH;
      c.Annotate(true);
      log("ITH swing, Shift:"+(string)c.ToString());
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int GetSignificantVisibleSwing(SwingType type, Candle* &swings[]) {
   int first = WindowFirstVisibleBar();
   int last = first-WindowBarsPerChart();//first+WindowBarsPerChart();
   Candle* key = swings[0];
   
   log("Searching for key swing in Bars "+(string)first+"-"+(string)last);
   
   for(int i=1; i<ArraySize(swings); i++) {
      if(swings[i].Shift > first || swings[i].Shift < last)
         continue;
      
      double lvl=type==SWING_HIGH ? swings[i].H : swings[i].L;
          
      if(type==SWING_HIGH && swings[i].H > key.H)
         key=swings[i];
      else if(type==SWING_LOW && swings[i].L < key.L)
         key=swings[i];
   }
   
   log("Most significant visible swing:"+key.ToString());
   return key.Shift;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
bool isSwingHigh(int offset, const double &highs[]) {
   if(offset <=0 || offset >=ArraySize(highs)-1)
      return false;
   if(highs[offset] > highs[offset+1] && highs[offset] > highs[offset-1])
      return true;
   else
      return false;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
bool isSwingLow(int offset, const double &lows[]) {
   if(offset<=0 || offset>=ArraySize(lows)-1)
      return false;
   if(lows[offset] < lows[offset+1] && lows[offset] < lows[offset-1])
      return true;
   else
      return false;
}