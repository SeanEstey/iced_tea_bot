//+------------------------------------------------------------------+
//|                                                      IcedTea.mq4 |
//+------------------------------------------------------------------+

#define VERSION "1.20"
#property strict

#include "Include/Logging.mqh"
#include "Include/Utility.mqh"
#include "Include/Chart.mqh"
#include "Include/Graph.mqh"
#include "Include/Orders.mqh"
#include "Include/SwingPoints.mqh"
#include "Include/Draw.mqh"
#include "Include/Hud.mqh"
#include "Algos/WeisCVD.mqh"


#define KEY_L           76
#define KEY_R           82
#define KEY_S           83
#define KEY_ESC         27

enum Algorithms {WEIS_CVD};


//--- Globals
Algorithms CurrentAlgo     = WEIS_CVD;
HUD* Hud                   = NULL;
SwingGraph* Swings         = NULL;
bool ShowLevels            = false;
bool ShowSwings            = true;
OrderManager* OM           = NULL;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   log("********** IcedTea Initializing **********");
   // Register Event Handlers
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE,true);
   Hud = new HUD("IcedTea v"+VERSION);
   Hud.AddItem("acct_name","Account","");
   Hud.AddItem("acct_balance","Balance","");
   Hud.AddItem("acct_pnl","Profit","");
   Hud.AddItem("acct_ntrades","Active Trades","");
   Hud.AddItem("hud_hover_bar","Hover Bar","");
   Hud.AddItem("hud_window_bars","Bars","");
   Hud.AddItem("hud_highest_high","Highest High","");
   Hud.AddItem("hud_lowest_low", "Lowest Low", "");
   Hud.AddItem("hud_trend", "Swing Trend", "");
   Hud.AddItem("hud_nodes", "Swing Nodes", "");
   Hud.AddItem("hud_node_links", "Node Links", "");
   Hud.SetDialogMsg("Hud created.");
   OM = new OrderManager();
   OM.GetAcctStats();
   // Swings = new SwingGraph();
   // Swings.DiscoverNodes(NULL,0,Bars-1,1);
   // Swings.UpdateNodeLevels(0);
   // Swings.FindNeighborRelationships();
   // Swings.FindImpulseRelationships();
   // Swings.FindOrderBlocks();
   log("********** All systems check. **********");
   Hud.SetDialogMsg("All systems check.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   delete OM;
   delete Hud;
   delete Swings;
   ObjectDelete(0,V_CROSSHAIR);
   ObjectDelete(0,H_CROSSHAIR); 
   int n=ObjectsDeleteAll();
   log("********** IcedTea Deinit. Deleted "+(string)n+" objects. **********");
   return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   if(!NewBar())
      return;
   
   int signal=GetSignal();
   if(signal==1){
      OM.OpenPosition(NULL,OP_BUY);
   }
   else if(signal==-1){
      OM.OpenPosition(NULL,OP_SELL);
   }
      
   Hud.SetItemValue("acct_pnl",OM.GetProfit());
}

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester() {
   double ret=0.0;
   return(ret);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {   
   switch(id) {
      case CHARTEVENT_CHART_CHANGE:
         OnChartChange(lparam,dparam,sparam);
         break;
      case CHARTEVENT_KEYDOWN:
         OnKeyPress(lparam,dparam,sparam);
         break;
      case CHARTEVENT_MOUSE_MOVE:
         OnMouseMove(lparam,dparam,sparam);
         break;
      case CHARTEVENT_CLICK:
         OnMouseClick(lparam,dparam,sparam);
         break;
      case CHARTEVENT_OBJECT_CLICK:
         break;
      default:
         break;
   }
}

//+---------------------------------------------------------------------------+
//| OnCalculate() has been called already, and indicator destructor/constructor
//| on change of TF.
//+---------------------------------------------------------------------------+
void OnChartChange(long lparam, double dparam, string sparam) {
   // Update HUD
   int first = WindowFirstVisibleBar();
   int last = first-WindowBarsPerChart();
   Hud.SetItemValue("hud_window_bars",(string)(last+2)+"-"+(string)(first+2));
   int hh_shift=iHighest(Symbol(),0,MODE_HIGH,first-last,last);
   int ll_shift=iLowest(Symbol(),0,MODE_LOW,first-last,last);   
   double hh=iHigh(Symbol(),0,hh_shift);
   datetime hh_time=iTime(Symbol(),0,hh_shift);
   double ll=iLow(Symbol(),0,ll_shift);
   datetime ll_time=iTime(Symbol(),0,ll_shift);
   Hud.SetItemValue("hud_lowest_low", DoubleToStr(ll,3)+" [Bar "+(string)(ll_shift+2)+"]"); 
   Hud.SetItemValue("hud_highest_high", DoubleToStr(hh,3)+" [Bar "+(string)(hh_shift+2)+"]");
   //Hud.SetItemValue("hud_nodes", (string)Swings.NodeCount());
   //Hud.SetItemValue("hud_node_links", (string)Swings.RelationshipCount());
   GetTrend();
}

//+---------------------------------------------------------------------------+
//| Respond to custom keyboard shortcuts
//+---------------------------------------------------------------------------+
void OnKeyPress(long lparam, double dparam, string sparam){
   switch((int)lparam){
      case KEY_ESC:
         break;
      case KEY_R: 
         break;   
      case KEY_S: 
         break;
      case KEY_L: 
         break;
      default:
         //log("Unmapped key:"+(string)lparam); 
         break;
   } 
   ChartRedraw(); 
}

//+---------------------------------------------------------------------------+
//| Draw crosshair, update HUD with relevent info.
//+---------------------------------------------------------------------------+
void OnMouseMove(long lparam, double dparam, string sparam){

   DrawCrosshair(lparam, (long)dparam);
   int m_bar=CoordsToBar((int)lparam, (int)dparam);
   Hud.SetItemValue("hud_hover_bar",(string)m_bar);
   Hud.SetDialogMsg("Mouse move. Coords:["+(string)lparam+","+(string)dparam+"]");
   
   datetime m_dt;
   double m_price;
   int window=0;
   ChartXYToTimePrice(0,(int)lparam,(int)dparam,window,m_dt,m_price);

   string results[];
   FindObjectsAtTimePrice(m_dt,m_price,results);
   if(ArraySize(results)>0){
      string msg="";
      for(int i=0; i<ArraySize(results); i++){
         if(results[i]=="V_CROSSHAIR" || results[i]=="H_CROSSHAIR")
            continue;
         // Found a SwingPoint connection label. Write out the label text in full.
         /*if(ObjectType(results[i])==OBJ_TEXT && StringFind(results[i],"link_text")>-1){
            string text=ObjectGetString(0,results[i],OBJPROP_TEXT)+", ";
            
            if(StringFind(text,"HH")>-1)
               msg+="Higher High";
            else if(StringFind(text,"HL")>-1)
               msg+="Higher Low";
            else if(StringFind(text,"LL")>-1)
               msg+="Lower Low";
            else if(StringFind(text,"LH")>-1)
               msg+="Lower High";
               
            string parts[];
            ushort u_sep=StringGetCharacter(",",0); 
            StringSplit(text,u_sep,parts);
           // log(text+", u_sep:"+(string)u_sep+", parts.size:"+(string)ArraySize(parts));
            msg+=", "+(string)parts[1]+" pips, "+(string)parts[2]+" bars.";
         }
         else
            msg+=results[i]+", ";
            */
      }
      Hud.SetDialogMsg(msg);
   }
}


//+------------------------------------------------------------------+
//| Mouse Input callback                                             |
//+------------------------------------------------------------------+
void OnMouseClick(long lparam, double dparam, string sparam) {
   int subwindow, x=(int)lparam, y=(int)dparam;
   datetime atTime;
   double atPrice;
   ChartXYToTimePrice(0,x,y,subwindow,atTime,atPrice);
 
   if (subwindow != 0) {
   } else {
  
   }
}


//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int GetTrend(){
   /*SwingRelationship* link1=Swings.GetRelationshipByIndex(Swings.RelationshipCount()-1);
   SwingRelationship* link2=Swings.GetRelationshipByIndex(Swings.RelationshipCount()-2);
   
   MarketStructure d1=link1.Desc;
   MarketStructure d2=link2.Desc;
   
   if(d1==HIGHER_HIGH || d1==HIGHER_LOW){
      if(d2==HIGHER_HIGH || d2==HIGHER_LOW)
         Hud.SetItemValue("hud_trend", "Bullish");
      else
         Hud.SetItemValue("hud_trend", "Neutral");
   }
   else if(d1==LOWER_HIGH || d1==LOWER_LOW) {
      if(d2==LOWER_HIGH || d2==LOWER_LOW)
         Hud.SetItemValue("hud_trend", "Bearish");
      else
         Hud.SetItemValue("hud_trend", "Neutral");
   }
   */
 
   //log("Last 2 SwingLink Descriptions:"+
   //   link1.ToString()+" (Lvl-"+(string)((SwingPoint*)link1.n2).Level+"), "+
   //   link2.ToString()+" (Lvl-"+(string)((SwingPoint*)link2.n2).Level+")");
   return 0;
}
