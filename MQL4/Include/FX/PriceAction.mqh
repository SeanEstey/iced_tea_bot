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
enum SwingPattern {THREE_CANDLE, FIVE_CANDLE};
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
//| Find Short-term, Intermediate-term, and Long-term Highs/Lows (swings)
//+---------------------------------------------------------------------------+
void DrawSwingLabels(string symbol, ENUM_TIMEFRAMES tf, int offset, int count, color clr,
                     const double &lows[], const double &highs[],
                     Candle* &sl[], Candle* &sh[], string& objs[]) {   
   
   // First pass: find Short-Term swings
   for(int i=offset+count-1; i>0; i--) {      
      if(isSwing(offset+i, SWING_HIGH, THREE_CANDLE, highs)) {
         Candle* c=new Candle(tf,i,STH);
         c.Annotate(true);
         AppendCandle(c, sh);
      }
      else if(isSwing(offset+i, SWING_LOW, THREE_CANDLE, lows)) {
         Candle* c=new Candle(tf,i,STL);
         c.Annotate(true);
         AppendCandle(c, sl);
      }   
   }
   
   // Second pass: find Intermediate-Term Swings
    for(int i=1; i<ArraySize(sh)-1; i++) {
      Candle* c=sh[i];
      if(c.H <= sh[i-1].H || c.H <= sh[i+1].H)
         continue;
      c.Annotate(false);
      c.Type=ITH;
      c.Annotate(true);
   }
   for(int i=1; i<ArraySize(sl)-1; i++) {
      Candle* c=sl[i];
      if(c.L >= sl[i-1].L || c.L >= sl[i+1].L)
         continue;
      c.Annotate(false);
      c.Type=ITL;
      c.Annotate(true);
   }  
   
   // Final pass: find Long-Term Swings
   for(int i=1; i<ArraySize(sh)-1; i++) {
      bool left_match=false, right_match=false;
      
      // Iterate to left of i and test first ITH
      for(int j=i-1; j>=0; j--) {
         if(sh[j].Type!=ITH)
            continue;
         if(sh[j].H<sh[i].H)
            left_match=true;
         break;
      }
      // Iterate to right of i and test first ITH
      for(int j=i+1; j<ArraySize(sh); j++) {
         if(sh[j].Type!=ITH)
            continue;
         if(sh[j].H<sh[i].H)
            right_match=true;
         break;
      }
      if(left_match==true && right_match==true){
         sh[i].Annotate(false);
         sh[i].Type=LTH;
         sh[i].Annotate(true);
         log("Found a LTH!");
      }
   }
   for(int i=1; i<ArraySize(sl)-1; i++) {
      bool left_match=false, right_match=false;
      
      for(int j=i-1; j>=0; j--) {
         if(sl[j].Type!=ITL)
            continue;
         if(sl[j].L>sl[i].L){
            left_match=true;
            break;
         }
      }
      for(int j=i+1; j<ArraySize(sl); j++) {
         if(sl[j].Type!=ITL)
            continue;
         if(sl[j].L>sl[i].L)
            right_match=true;
         break;
      }
      if(left_match==true && right_match==true){
         sl[i].Annotate(false);
         sl[i].Type=LTL;
         sl[i].Annotate(true);
         log("Found a LTL!");
      }
   }
   
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int GetSignificantVisibleSwing(SwingType type, Candle* &swings[]) {
   int first = WindowFirstVisibleBar();
   int last = first-WindowBarsPerChart();
   Candle* key = swings[0];
   
   for(int i=1; i<ArraySize(swings); i++) {
      if(swings[i].Shift > first || swings[i].Shift < last)
         continue;
      
      double lvl=type==SWING_HIGH ? swings[i].H : swings[i].L;
          
      if(type==SWING_HIGH && swings[i].H > key.H)
         key=swings[i];
      else if(type==SWING_LOW && swings[i].L < key.L)
         key=swings[i];
   }
   
   //log("Most significant visible swing:"+key.ToString());
   return key.Shift;
}

//+---------------------------------------------------------------------------+
//+---------------------------------------------------------------------------+
bool isSwing(int offset, SwingType type, SwingPattern len, const double &list[]) {
   int min_offset= len==THREE_CANDLE ? 1 : 2;
   int max_offset= len==THREE_CANDLE ? ArraySize(list)-2 : ArraySize(list)-3;
  
   if(offset < min_offset || offset > max_offset)
      return false;
  
   if(len==THREE_CANDLE) {
      if(type==SWING_HIGH)
         if(list[offset] > list[offset+1] && list[offset] > list[offset-1])
            return true;
         else
            return false;
      else if(type==SWING_LOW)
         if(list[offset] < list[offset+1] && list[offset] < list[offset-1])
            return true;
         else
            return false;
   }
   else if(len==FIVE_CANDLE) {
      if(type==SWING_HIGH)
         if(list[offset]>list[offset-1] && list[offset-1]>list[offset-2] && list[offset]>list[offset+1] && list[offset+1]>list[offset+2])
            return true;
         else
            return false;
      else if(type==SWING_LOW)
         if(list[offset]<list[offset-1] && list[offset-1]<list[offset-2] && list[offset]<list[offset+1] && list[offset+1]<list[offset+2])
            return true;
         else
            return false;
   }
   return -1;
}