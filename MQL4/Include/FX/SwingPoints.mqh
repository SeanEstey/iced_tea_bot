//+----------------------------------------------------------------------------+
//|                                                         FX/SwingPoints.mqh |
//|                                                 Copyright 2018, Sean Estey |
//+----------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict

#include <FX/Graph.mqh>
#include <FX/Chart.mqh>
#include <FX/Draw.mqh>

//---SwingPoint enums
enum SwingLength {THREE_BAR,FIVE_BAR};
enum SwingType {LOW,HIGH};
enum SwingLevel {SHORT,MEDIUM,LONG};
enum SwingLinkType {NEIGHBOR,IMPULSE};

//--Config
SwingLength SwingBars             =THREE_BAR;
const int PointSize               =22;
const color PointColors[3]        ={clrMagenta, C'59,103,186', clrRed};
const string PointLblFonts[3]     ={"Arial", "Arial", "Arial Bold"};
const int PointLblSizes[3]        ={9, 9, 9};
const color PointLblColors[3]     ={clrGray, C'59,103,186', clrRed};
const int LinkLblColor            =clrBlack;
const color LinkLineColor         =clrBlack;


//-----------------------------------------------------------------------------+
//| Return SwingType enum for valid swing points, -1 otherwise.
//-----------------------------------------------------------------------------+
SwingType GetSwingType(int bar){
   int min= SwingBars==THREE_BAR? 1: 2;
   int max= SwingBars==THREE_BAR? Bars-2: Bars-3;
   int n_checks= SwingBars==THREE_BAR? 1: 2;
      
   if(bar<min || bar>max)  // Bounds check
      return -1;
   
   // Loop 1: check nodes[i-1] to nodes[i+1]
   // Loop 2: check nodes[i-2] to nodes[i+2]
   for(int i=1; i<n_checks+1; i++) {            
      // Swing High test
      if(iHigh(NULL,0,bar)>iHigh(NULL,0,bar-i) && iHigh(NULL,0,bar)>iHigh(NULL,0,bar+i))
         return HIGH;
      // Swing Low test
      else if(iLow(NULL,0,bar)<iLow(NULL,0,bar-i) && iLow(NULL,0,bar)<iLow(NULL,0,bar+i))
         return LOW;
   }
   return -1;
}

//-----------------------------------------------------------------------------+
/* A high/low candle surrounded by 2 lower highs/higher lows.
 * Categorized into: Short-term (ST), Intermediate-term (IT), Long-term (LT) */
//-----------------------------------------------------------------------------+
class SwingPoint: public Node{
   public:
      int TF;
      datetime DT;
      double O,C,H,L;
      SwingLevel Level;
      SwingType Type;
   public:
       SwingPoint(int tf, int shift):Node(shift) {
         this.Level=SHORT;
         this.Type=GetSwingType(shift);
         this.TF=tf;
         this.DT=Time[shift];
         this.O=Open[shift];
         this.C=Close[shift];
         this.H=High[shift];
         this.L=Low[shift];
         CreateText(this.LabelId,"",this.Shift,this.Type==HIGH? ANCHOR_LOWER: ANCHOR_UPPER,0,0,0,0,PointLblFonts[this.Level],PointLblSizes[this.Level],PointLblColors[this.Level]);
         // Vertex drawn as text Wingdings Char(159).
         // Set empty string to hide
         CreateText(this.PointId,"",this.Shift,-1,this.Type==HIGH?this.H:this.L,this.DT,0,0,"Wingdings",PointSize,PointColors[this.Level],0,0,false,true);
         //log("SwingPoint() Id:"+this.Id+", Shift:"+(string)this.Shift);
      }
  
      ~SwingPoint(){
         ObjectDelete(0,this.LabelId);
         ObjectDelete(0,this.PointId);
         //debuglog("~SwingPoint()");
      }
      
      // Upgraded to intermediate/long-term swingpoint. Adjust fonts + draw Point.
      int RaiseLevel(SwingLevel lvl) {
         if(lvl>1)
            return -1;
         this.Level=lvl+1;
         ObjectSetText(this.LabelId,this.ToString(),
            PointLblSizes[this.Level],PointLblFonts[this.Level],PointLblColors[this.Level]);
         ObjectSetText(this.PointId,CharToStr(159),22,"Wingdings",PointColors[this.Level]);
         return 0;
      }
      
      void ShowLabel(bool toggle){
         ObjectSetText(this.LabelId,toggle? this.ToString(): "");
      }
      
      string ToString(){
         string prefix= this.Level==SHORT? "ST": this.Level==MEDIUM? "IT": this.Level==LONG? "LT": "";
         string sufix= this.Type==LOW? "L": this.Type==HIGH? "H" : "";
         return prefix+sufix; 
      }
};

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
class SwingLink: public Link {
   public:
      SwingLink(SwingPoint* sp1, SwingPoint* sp2, string description): Link(sp1,sp2,description){  
         double p1=sp1.Type==HIGH? sp1.H: sp1.L;
         double p2=sp2.Type==HIGH? sp2.H: sp2.L;
         
         CreateTrendline(this.LineId,sp1.DT,p1,sp2.DT,p2,0,LinkLineColor,0,1,true,false);
         
         int midpoint=(int)sp1.Shift-(int)MathFloor((sp1.Shift-sp2.Shift)/2);
         double delta_p=MathAbs(p1-p2);
         int delta_t=MathAbs(sp1.Shift-sp2.Shift);
         
         // Label swing/time/price relationship (e.g "HL,100,25")
         string label= p2-p1<0? "L": p2-p1>0? "H": "E";
         label+=sp1.Type==HIGH?"H":"L";
         label+=","+ToPipsStr(delta_p,0)+","+(string)delta_t;
         
         CreateText(this.LabelId,label,midpoint,sp1.Type==HIGH? ANCHOR_LOWER : ANCHOR_UPPER,
            p1<p2? p1+(delta_p/2): p2+(delta_p/2),0,0,0,"Arial",7,LinkLblColor);
      }
      
      //----------------------------------------------------------------------------
      ~SwingLink(){
         ObjectDelete(this.LineId);
         ObjectDelete(this.LabelId);
      }
};

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
class SwingGraph: public Graph {   
   public:
      SwingGraph(): Graph(){
         log("SwingGraph constructor");
      }
      ~SwingGraph(){
         // TODO: this may not free up the actual object heap memory
         this.links.Clear();
         this.nodes.Clear();
         log("SwingGraph destructor");
      }
   
      //----------------------------------------------------------------------------
      void DiscoverNodes(string symbol, ENUM_TIMEFRAMES tf, int shift1, int shift2){
         int n_nodes=this.nodes.Count();
         if(n_nodes==0)
            log("Building SwingGraph...");
         else
            log("Updating SwingGraph from Bars "+(string)shift1+"-"+(string)shift2+". Nodes:"+(string)this.nodes.Count()+", Links:"+(string)this.links.Count());
         
         // Scan price data for any valid nodes to add to graph.
         for(int bar=shift1; bar>=shift2; bar--) {
            if(GetSwingType(bar)>-1) {
               string key=(string)(long)iTime(NULL,0,bar);
               if(!this.HasNode(key))
                  this.AddNode(new SwingPoint(tf,bar));
            }
         }
         log("Updated SwingGraph. Discovered "+(string)(this.nodes.Count()-n_nodes)+" Nodes.");
      }
      
      //----------------------------------------------------------------------------
      int FilterNodes(SwingPoint* &dest[], SwingPoint* first, SwingPoint* last, int min_lvl=-1, int type=-1){         
         SwingPoint* n=first;
         while(n && n!=last) {
            if(n.Level>=min_lvl && n.Type>=type){
               ArrayResize(dest,ArraySize(dest)+1);
               dest[ArraySize(dest)-1]=n;
            }
            n=n.Next;
         }
         
         log("Found "+(string)ArraySize(dest)+" nodes matching filter (Level:"+(string)min_lvl+", Type:"+(string)type+").");
         return ArraySize(dest);         
      }
      
      //----------------------------------------------------------------------------
      void UpdateNodeLevels(){
         log("Updating SwingPoint Levels...");
         // Outer loop. Iterate SwingLevels.
         for(int i=0; i<2; i++) {
            SwingPoint* n=this.FirstNode;
            // Inner loop. Traverse nodes within SwingLevel.
            while(n) {
               if(n.Level!=i){
                  n=n.Next;
                  continue;
               }
               // Traverse nodes to left until first neighbor matching SwingType/SwingLevel
               SwingPoint* left=n.Prev;
               while(left!=NULL){
                  if(left.Level>=n.Level && n.Type==left.Type)
                     break;
                  left=left.Prev;
               }
               SwingPoint* right=n.Next;
               while(right!=NULL){
                  if(right.Level>=n.Level && n.Type==right.Type)
                     break;
                  right=right.Next;
               }
               if(left && right){
                  if(n.Type==LOW && iLow(NULL,0,n.Shift)<MathMin(iLow(NULL,0,left.Shift),iLow(NULL,0,right.Shift)))
                     n.RaiseLevel(n.Level);
                  else if(n.Type==HIGH && iHigh(NULL,0,n.Shift)>MathMax(iHigh(NULL,0,left.Shift),iHigh(NULL,0,right.Shift)))
                     n.RaiseLevel(n.Level);
               }
               n=n.Next;
            }
         }   
         log("SwingPoint Levels updated.");
      }
      
      //-----------------------------------------------------------------------+
      int FindAdjacentLinks(){
         // Connect Lvl1 Nodes-->Lvl1+ Nodes of same Type (to the right)
         // Connect Lvl2 Nodes-->Lvl2 Nodes of same Type (to the right)
         int n_traversals=0;
         int n_edges=this.links.Count();
         
         log("Finding adjacent SwingPoint edges...");
         if(this.nodes.Count()<=1)
            return -1;
         
         SwingPoint *n1=this.LastNode;
         SwingPoint *n2=n1.Prev;
         
         while(n1 && n2){
            if(n1.Level>0 && (n1.Type!=n2.Type || n2.Level<1)){
               // Iterate backwards until Lvl1+ swingpoint found.
               while(n2.Prev){
                  if(n2.Type==n1.Type && n2.Level>0)
                     break;
                  n2=n2.Prev;
               }  
            }
            if(n1.Type==n2.Type && n1.Level>0 && n2.Level>0 && !this.HasLink(n1,n2)) {
               this.AddLink(new SwingLink(n1,n2,"Neighbors"));
            }
            
            n1=n1.Prev;
            n2=n1? n1.Prev: NULL;
            n_traversals++;
         }
         log("Done. Traversed "+(string)n_traversals+" nodes, found "+(string)(this.links.Count()-n_edges)+" edges.");
         log(this.ToString());
         return 1;
      }
};
