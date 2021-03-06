//+----------------------------------------------------------------------------+
//|                                                         FX/SwingPoints.mqh |
//|                                                 Copyright 2018, Sean Estey |
//+----------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict

#include "Graph.mqh"
#include "PAUtils.mqh"
#include "Draw.mqh"

//---SwingPoint enums
enum BarLength {THREE_BAR,FIVE_BAR};
enum SwingVector {LOW,HIGH};
enum Level {SHORT_TERM,MEDIUM_TERM,LONG_TERM};
enum RelationshipType {NEIGHBOR,IMPULSE};
enum MarketStructure {LOWER_HIGH, HIGHER_HIGH, LOWER_LOW, HIGHER_LOW};

//--Config
BarLength SwingBars               =THREE_BAR;
const int PointSize               =8;
const color PointColors[3]        ={C'59,103,186', C'59,103,186', C'59,103,186'};
const string PointLblFonts[3]     ={"Arial", "Arial", "Arial Bold"};
const int PointLblSizes[3]        ={5, 9, 9};
const color PointLblColors[3]     ={clrBlack, clrBlack, clrBlack}; //C'59,103,186', clrBlack};
const int RelationshipLblColor    =clrBlack;
const color RelationshipLineColor =clrBlack;

//-----------------------------------------------------------------------------+
//| Return SwingVector enum for valid swing points, -1 otherwise.
//-----------------------------------------------------------------------------+
SwingVector GetSwingVector(int bar){
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

//---------------------------------------------------------------------------------+
//|****************************** SwingPoint Class *********************************
//---------------------------------------------------------------------------------+
class SwingPoint: public Node{
   public:
      int TF;
      datetime DT;
      double O,C,H,L;
      Level MyLevel;
      SwingVector Type;
   public:
       SwingPoint(int tf, int shift):Node(shift) {
         this.MyLevel=SHORT_TERM;
         this.Type=GetSwingVector(shift);
         this.TF=tf;
         this.DT=Time[shift];
         this.O=Open[shift];
         this.C=Close[shift];
         this.H=High[shift];
         this.L=Low[shift];
         CreateText(this.LabelId,this.ToString(),this.Shift,this.Type==HIGH? ANCHOR_LOWER: ANCHOR_UPPER,0,0,0,0,PointLblFonts[this.MyLevel],PointLblSizes[this.MyLevel],PointLblColors[this.MyLevel]);
         // Vertex drawn as text Wingdings Char(159) (empty string to hide)
         CreateText(this.PointId,CharToStr(32),this.Shift,-1,this.Type==HIGH?this.H:this.L,this.DT,0,0,"Wingdings",PointSize,PointColors[this.MyLevel],0,true,false,false);
      }
      
      double GetValue(){return this.Type==HIGH? this.H: this.L;}
      
      // Upgraded to intermediate/long-term swingpoint. Adjust fonts + draw Point.
      int RaiseLevel(Level lvl) {
         if(lvl>1)
            return -1;
         this.MyLevel=(Level)(((int)lvl)+1);
         ObjectSetText(this.LabelId,this.ToString(),
            PointLblSizes[this.MyLevel],PointLblFonts[this.MyLevel],PointLblColors[this.MyLevel]);
         
         if(this.MyLevel==LONG_TERM)
            ObjectSetText(this.PointId,CharToStr(159),22,"Wingdings",PointColors[this.MyLevel]);
         else
            ObjectSetText(this.PointId,CharToStr(32),22,"Wingdings",PointColors[this.MyLevel]);
         
         return 0;
      }
      
      void ShowLabel(bool toggle){
         ObjectSetText(this.LabelId,toggle? this.ToString(): "");
         
         //ObjectSetText(this.PointId, toggle?
         //   ObjectSetText(this.PointId, CharToStr(159),PointSize,"Wingdings",PointColors[this.MyLevel]):
         //   ObjectSetText(this.PointId,"",PointSize,"Arial",PointColors[this.MyLevel])
         //);
      }
      
      string ToString(bool debug=false){
         string prefix= this.MyLevel==SHORT_TERM? "ST": this.MyLevel==MEDIUM_TERM? "IT": this.MyLevel==LONG_TERM? "LT": "";
         string sufix= this.Type==LOW? "L": this.Type==HIGH? "H" : "";
         
         if(debug) {
            log("SwingPoint Id:"+this.Id+", Shift:"+(string)this.Shift+", Dt:"+(string)this.DT);
         }
         
         return prefix+sufix; 
      }
};

//---------------------------------------------------------------------------------+
//|******************************* SwingRelationship Class *********************************
//---------------------------------------------------------------------------------+
class SwingRelationship: public Relationship {
   public:
      RelationshipType Type;
      MarketStructure Desc;
   public:
      SwingRelationship(SwingPoint* left, SwingPoint* right, RelationshipType type): Relationship(left,right){  
         this.Type=type;
         double p1=left.Type==HIGH? left.C>left.O? left.C: left.O : left.C;
         double p2=right.Type==HIGH? right.C>right.O? right.C: right.O: right.C;
         
         int midpoint=(int)left.Shift-(int)MathFloor((left.Shift-right.Shift)/2);
         double delta_p=MathAbs(p1-p2);
         int delta_t=MathAbs(left.Shift-right.Shift);
         string label="";
         
         // Label swing/time/price relationship (e.g "HL,100,25")
         if(this.Type==NEIGHBOR){
            if(p1-p2<0)
               if(left.Type==HIGH) {
                  this.Desc=LOWER_HIGH;
                  label="LH"+","+ToPipsStr(p1-p2,0)+","+(string)delta_t;
               }
               else {
                  this.Desc=LOWER_LOW;
                  label="LL"+","+ToPipsStr(p1-p2,0)+","+(string)delta_t;
               }
            else if(p1-p2>0)
               if(left.Type==HIGH){
                  this.Desc=HIGHER_HIGH;
                  label="HH"+","+ToPipsStr(p1-p2,0)+","+(string)delta_t;
               }
               else {
                  this.Desc=HIGHER_LOW;
                  label="HL"+","+ToPipsStr(p1-p2,0)+","+(string)delta_t;
               }
               
            CreateTrendline(this.LineId,left.DT,p1,right.DT,p2,0,RelationshipLineColor,0,1,true,false);
            CreateText(this.LabelId,label,midpoint,left.Type==HIGH? ANCHOR_LOWER : ANCHOR_UPPER,
               p1<p2? p1+(delta_p/2): p2+(delta_p/2),0,0,0,"Arial",7,RelationshipLblColor);
         }
         else if(this.Type==IMPULSE) {
            CreateTrendline(this.LineId,left.DT,p1,right.DT,p2,0,clrRed,STYLE_DASH,1,true,false,false);
         }
         
         
      }
      
      //----------------------------------------------------------------------------
      string ToString() {
         if(this.Type==NEIGHBOR) {
            if(this.Desc==HIGHER_HIGH)
               return "Higher High";
            else if(this.Desc==LOWER_HIGH)
               return "Lower High";
            else if(this.Desc==HIGHER_LOW)
               return "Higher Low";
            else if(this.Desc==LOWER_LOW)
               return "Lower Low";
         }
         
         return "Uknown";
         /*string text=ObjectGetString(0,results[i],OBJPROP_TEXT)+", ";

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
         log(text+", u_sep:"+(string)u_sep+", parts.size:"+(string)ArraySize(parts));
         msg+=", "+(string)parts[1]+" pips, "+(string)parts[2]+" bars.";*/
      }
   
};

//---------------------------------------------------------------------------------+
//|****************************** SwingGraph Class *********************************
//---------------------------------------------------------------------------------+
class SwingGraph: public Graph {   
   public:
      SwingGraph(): Graph(){}
   
      //----------------------------------------------------------------------------
      void DiscoverNodes(string symbol, ENUM_TIMEFRAMES tf, int shift1, int shift2){
         int n_nodes=ArraySize(this.Nodes);
         if(n_nodes==0)
            log("----- Building SwingGraph -----");
         else
            log("Building SwingGraph from Bars "+(string)shift1+"-"+(string)shift2+
               ". Nodes:"+(string)ArraySize(this.Nodes)+", Links:"+(string)ArraySize(this.Links));
         
         // Scan price data for any valid nodes to add to graph.
         for(int bar=shift1; bar>=shift2; bar--) {
            if(GetSwingVector(bar)>-1) {
               string key=(string)(long)iTime(NULL,0,bar);
               if(!this.HasNode(key)){
                  SwingPoint* sp=new SwingPoint(tf,bar);
                  sp.ShowLabel(false);
                  this.AddNode(sp);
               }
            }
         }
         log("Discovered "+(string)(ArraySize(this.Nodes)-n_nodes)+" Nodes.");
      }
      //----------------------------------------------------------------------------
      int UpdateNodeLevels(int level){
         if(level>=2)
            return 1;
         
         // Traverse nodes within Level.
         for(int i=0; i<ArraySize(this.Nodes); i++){
            SwingPoint *sp=this.Nodes[i];
            if(sp.MyLevel!=level)
               continue;
               
            bool left=false,right=false;
            // Find left neighbor
            int j=i-1;
            while(j>=0){
               if(((SwingPoint*)this.Nodes[j]).MyLevel>=sp.MyLevel && sp.Type==((SwingPoint*)this.Nodes[j]).Type){
                  left=true;
                  break;
               }
               j--;
            }
            // Find right neighbor
            int k=i+1;
            while(k<ArraySize(this.Nodes)){
               if(((SwingPoint*)this.Nodes[k]).MyLevel>=sp.MyLevel && sp.Type==((SwingPoint*)this.Nodes[k]).Type){
                  right=true;
                  break;
               }
               k++;
            }
            // Increase node level if Lowest/Highest of its 2 neighbors.
            if(left && right){
               if(sp.Type==LOW && iLow(NULL,0,sp.Shift)<MathMin(iLow(NULL,0,this.Nodes[j].Shift),iLow(NULL,0,this.Nodes[k].Shift)))
                  sp.RaiseLevel(sp.MyLevel);
               else if(sp.Type==HIGH && iHigh(NULL,0,sp.Shift)>MathMax(iHigh(NULL,0,this.Nodes[j].Shift),iHigh(NULL,0,this.Nodes[k].Shift)))
                  sp.RaiseLevel(sp.MyLevel);
               if(sp.MyLevel==LONG_TERM)
                  sp.ShowLabel(true);
               else
                  sp.ShowLabel(false);
            }
         } 
         //log("SwingPoint Levels "+(string)level+" updated.");
         this.UpdateNodeLevels(level+1);
         return 1;
      }
      //----------------------------------------------------------------------------
      int FindNeighborRelationships(){
         // Connect Lvl1 Nodes-->Lvl1+ Nodes of same Type (to the right)
         // Connect Lvl2 Nodes-->Lvl2 Nodes of same Type (to the right)
         int n_traversals=0;
         int n_edges=ArraySize(this.Links);
         
         log("Finding adjacent SwingPoint edges...");
         if(ArraySize(this.Nodes)<=1)
            return -1;
         
         for(int i=0; i<ArraySize(this.Nodes); i++){
            SwingPoint *left=this.Nodes[i];
            if(left.MyLevel<1)
               continue;
            
            SwingPoint *right=this.Nodes[i+1];
            
            for(int j=i+1; j<ArraySize(this.Nodes); j++) {
               right=this.Nodes[j];
               if(right.Type==left.Type && right.MyLevel>0)
                  break;
            }
            
            if(right.MyLevel>0 && !this.HasRelationship(left,right)){
               this.AddRelationship(new SwingRelationship(right,left,NEIGHBOR));
            }
               n_traversals++;
         }
         log("Done. Traversed "+(string)n_traversals+" nodes, found "+(string)(ArraySize(this.Links)-n_edges)+" edges.");
         log(this.ToString());
         
         return 1;
      }
      //----------------------------------------------------------------------------
      //| Impulse definition:
      //| 1. SwingLink between SwingPointA (Right) and SwingPointB (Left)
      //| 2. Right and Left must be of opposite Types (HIGH/LOW)
      //| 3. Left must be identified within existing SwingLink of Type NEIGHBOR 
      //|    with Desc==LOWER_LOW or HIGHER_HIGH (break of market structure)
      //| 4. Right Shift must be inbetween SwingPoints in above SwingLink
      int FindImpulseRelationships() {
         SwingPoint *origins[];     // Cached results to speedup lookups
         // Iterate graph and identify breaks in market structure (HH/LL)
         for(int i=0; i<ArraySize(this.Links); i++){
            SwingPoint *end=NULL,*origin=NULL;
            SwingRelationship *swing=(SwingRelationship*)this.Links[i];
            
            if(swing.Desc==HIGHER_LOW || swing.Desc==LOWER_HIGH)
               continue;
      
            // Find tail of impulse swing.
            if(swing.Desc==HIGHER_HIGH)
               end=((SwingPoint*)swing.Right).C>((SwingPoint*)swing.Left).C? swing.Right: swing.Left;
            else if(swing.Desc==LOWER_LOW)
               end=((SwingPoint*)swing.Right).C<((SwingPoint*)swing.Left).C? swing.Right: swing.Left;
       
            // Find impulse swing origin.
            for(int j=0; j<this.NodeCount()-1; j++){
               if(((SwingPoint*)this.Nodes[j]).MyLevel==0)
                  continue;
               if(((SwingPoint*)this.Nodes[j]).Type==end.Type)
                  continue;
               if((this.Nodes[j]>swing.Left && this.Nodes[j]>swing.Right) || (this.Nodes[j]<swing.Left && this.Nodes[j]<swing.Right))
                  continue;
                     
               // Make sure this SwingPoint isn't already defined as an impulse
               bool valid=true;
               for(int k=0; k<ArraySize(origins); k++){
                  if(origins[k].Id==this.Nodes[j].Id)
                     valid=false;
               }
               if(valid)
                  origin=this.Nodes[j];
            }
            
            if(end && origin) {
               ArrayResize(origins,ArraySize(origins)+1);
               origins[ArraySize(origins)-1]=origin;
               SwingRelationship *sl=new SwingRelationship(origin,end,IMPULSE);
               sl.Desc=swing.Desc;
               this.AddRelationship(sl);
            }
         }
         return 1;
      }
      //----------------------------------------------------------------------------
      //| Iterate graph links for Impulses, identify + draw orderblock rectangles
      //----------------------------------------------------------------------------
      int FindOrderBlocks() {
         // ***This code is total shit. Refactor***
         for(int i=0; i<ArraySize(this.Links); i++){
            if(((SwingRelationship*)this.Links[i]).Type!=IMPULSE)
               continue;
          
            SwingRelationship *impulse=(SwingRelationship*)this.Links[i];
            SwingPoint *origin=impulse.Left;
            SwingPoint *end=impulse.Right;
            
            //color mask=MaskColour(clrWhite, clrDarkTurquoise, color chartBackground);
      
            // Bullish impulse. Test origin candle for OB.
            for(int j=0; j<=1; j++){
               if(impulse.Desc==HIGHER_HIGH) {
                  log("Found bullish OrderBlock!");
                  if(DownCandle(origin.Shift+j)){
                     CreateRect("orderblock_"+(string)(origin.Shift+j),
                        iTime(NULL,0,origin.Shift+j),
                        iOpen(NULL,0,origin.Shift+j),
                        iTime(NULL,0,origin.Shift+j-50), // FIXME
                        iClose(NULL,0,origin.Shift+j),
                        0,0,clrDarkTurquoise,STYLE_SOLID,3,true,true,true,false,50);
                     break;
                  }
               }
            }
            
            // Bearish impulse. "  "
            for(int j=0; j<=1; j++){
               if(impulse.Desc==LOWER_LOW) {
                  log("Found bullish OrderBlock!");
                  if(UpCandle(origin.Shift+j)){
                     CreateRect("orderblock_"+(string)(origin.Shift+j),
                        iTime(NULL,0,origin.Shift+j),
                        iOpen(NULL,0,origin.Shift+j),
                        iTime(NULL,0,origin.Shift+j-50), // FIXME
                        iClose(NULL,0,origin.Shift+j),
                        0,0,clrDarkTurquoise,STYLE_SOLID,3,true,true,true,false,50);
                     break;
                  }
               }
            }
         }
         return 1;
      }
};
