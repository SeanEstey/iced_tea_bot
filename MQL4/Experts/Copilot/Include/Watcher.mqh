//+---------------------------------------------------------------------------+
//|                                                       Include/Watcher.mq4 |      
//+---------------------------------------------------------------------------+
#property strict
#include "Logging.mqh"
#include "OrderManager.mqh"

enum Reaction     {SFP,BOUNCE,BREAK};
enum Direction    {BULLISH,BEARISH};
enum SetupState   {PENDING,VALIDATED,INVALIDATED};
enum CondState    {MET,UNMET,FAILED};


//|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|
//|+++++++++++++++++++++++++++ Class Interfaces +++++++++++++++++++++++++++++++|
//|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|


//+----------------------------------------------------------------------------+
//| Represents a desired market condition for validation of a trade setup.     |
//+----------------------------------------------------------------------------+
class Condition {
   public:
      uint id;
      string symbol;
      int tf;
      double level;
      Reaction reaction;
      Direction dir;
      CondState state;
   public:
      Condition(string _symbol, int _tf, double lvl, Reaction react, Direction _dir);
      ~Condition();
      CondState Test();
      string ToString();
};
//----------------------------------------------------------------------------+
//| Wrapper for evaluating the validation of multiple trade setup conditions.
//----------------------------------------------------------------------------+
class TradeSetup {
   public:
      uint id;
      string symbol;
      int tf;
      SetupState state;
      Order* order;
      Condition* conditions[];
   public:
      TradeSetup(string _symbol, int _tf, Condition* c, Order* o);
      ~TradeSetup();
      int Add(Condition* c);
      int Rmv(Condition* c);
      SetupState Eval();
};
//----------------------------------------------------------------------------+
// Manages multiple trade setups in a watchlist.
//----------------------------------------------------------------------------+
class Watcher {
   public:
      TradeSetup* watchlist[];
   public:
      Watcher();
      ~Watcher();
      int Add(TradeSetup* setup);
      int Rmv(TradeSetup* setup);
      int RmvAll();
      int PauseAll();
      bool Eval(TradeSetup* setup);
      int TickUpdate(OrderManager* OM);
};

//|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|
//|+++++++++++++++++++++++++++ Class Definitions+++++++++++++++++++++++++++++++|
//|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|


//+---------------------------------------------------------------------------+
Condition::Condition(string _symbol, int _tf, double lvl, Reaction react, Direction _dir){
   this.id=GenerateUUID();
   this.symbol=_symbol;
   this.tf=_tf;
   this.level=lvl;
   this.reaction=react;
   this.dir=_dir;
   this.state=UNMET;
}
//+---------------------------------------------------------------------------+
Condition::~Condition(){
   // WRITEME
}
//+---------------------------------------------------------------------------+
CondState Condition::Test(){
   if(this.state!=UNMET)
      return this.state;
   
   // For readability
   double open=iOpen(this.symbol,this.tf,1);
   double close=iClose(this.symbol,this.tf,1);
   double low=iLow(this.symbol,this.tf,1);
   double high=iHigh(this.symbol,this.tf,1);
    
   // FIXME: detect case where high/low/close==this.level
   // SFP states: MET/UNMET/FAILED
   if(reaction==SFP){
      if(dir==BULLISH && low<level && close>level)
         state=MET;
      else if(dir==BULLISH && low<level && close<level)
         state=FAILED;
      else if(dir==BEARISH && high>level && close<level)
         state=MET;
      else if(dir==BEARISH && high>level && close>level)
         state=FAILED;
   }
   // Level break states: MET/UNMET
   else if(reaction==BREAK){
      if(dir==BULLISH && open<level && close>level)
         state=MET;
      else if(dir==BEARISH && open>level && close<level)
         state=MET;
   }
   // Bounce states: PENDING, VALIDATED or INVALIDATED
   else if(reaction==BOUNCE){
      // WRITEME
   }
   
   if(state!=UNMET){
      log((dir==BULLISH? "Bullish ": "Bearish ")+
         (reaction==SFP?"SFP ":reaction==BREAK?"Break ":reaction==BOUNCE?"Bounce ":"")+
         "pattern "+(state==MET? "MET": "FAILED")
      );
   }
   return this.state;
}
//+---------------------------------------------------------------------------+
string Condition::ToString(){
   string str=this.reaction==SFP? "SFP": 
      this.reaction==BOUNCE? "BOUNCE": 
      this.reaction==BREAK? "BREAK": "NONE";
   return "Setup Condition. Symbol: "+this.symbol+", Tf: "+
      (string)this.tf+", Lvl: "+DoubleToStr(this.level)+", Reaction: "+str;
}


/*****************************************************************************/
TradeSetup::TradeSetup(string _symbol, int _tf, Condition* c, Order* o){
   this.id=GenerateUUID();
   this.symbol=_symbol;
   this.tf=_tf;
   this.order=o;
   this.Add(c);
   this.state=PENDING;
   log("TradeSetup ID: "+(string)this.id+" created.");
}
//+---------------------------------------------------------------------------+
TradeSetup::~TradeSetup(){
   // WRITEME
}
//+---------------------------------------------------------------------------+
int TradeSetup::Add(Condition* c){
   for(int i=0; i<ArraySize(this.conditions); i++){
      if(this.conditions[i].id==c.id){
         log("TradeSetup::Add() Cannot add condition with duplicate ID#"+(string)c.id);
         return -1;
      }
   }
   
   ArrayResize(this.conditions, ArraySize(this.conditions)+1);
   this.conditions[ArraySize(this.conditions)-1]=c;
   return 1;
}

//+---------------------------------------------------------------------------+
int TradeSetup::Rmv(Condition* c){
   for(int i=0; i<ArraySize(this.conditions); i++){
      if(this.conditions[i].id!=c.id)
         continue;
      
      Condition* tmp[];
      ArrayCopy(tmp,this.conditions,0,0,WHOLE_ARRAY);
      ArrayFree(this.conditions);
      
      for(int j=0; j<ArraySize(tmp); j++){
         if(tmp[j].id==c.id)
            continue;
         ArrayResize(this.conditions, ArraySize(this.conditions)+1);
         this.conditions[ArraySize(this.conditions)-1]=tmp[j];  
      }
      
      log("Condition ID#"+(string)c.id+" removed from TradeSetup ("+
         (string)ArraySize(tmp)+"-->"+(string)ArraySize(this.conditions)+").");
   }
   return 1;
}

//+---------------------------------------------------------------------------+
//| Evaluate conditions and execute trade if met, rmv setup if invalidated.
//+---------------------------------------------------------------------------+
SetupState TradeSetup::Eval(){
   int n_met=0, n_failed=0, n_unmet=0;
   
   for(int i=0; i<ArraySize(this.conditions); i++){
      Condition* c=this.conditions[i];
      
      if(c.state==FAILED){
         n_failed++;
         continue;
      }
         
      c.Test();
      
      if(c.state==UNMET)
         n_unmet++;
      else if(c.state==MET)
         n_met++;
      else if(c.state==FAILED)
         n_failed++;
   }
   
   string msg="Unmet: "+(string)n_unmet+
      ", Met: "+(string)n_met+
      ", Failed: "+(string)n_failed;
   
   if(n_met==ArraySize(this.conditions)){
      this.state=VALIDATED;
      log("TradeSetup ID "+(string)id+": Validated ("+msg+")");
   }
   else if(n_failed>0){
      this.state=INVALIDATED;
      log("TradeSetup ID "+(string)id+": Invalidated ("+msg+")");
   }
   else {
      log("TradeSetup ID "+(string)id+": Pending ("+msg+")");
   }
   
   return this.state;
}


/*****************************************************************************/
Watcher::Watcher(){
}

//+---------------------------------------------------------------------------+
Watcher::~Watcher(){}
//+---------------------------------------------------------------------------+
int Watcher::Add(TradeSetup* setup){
   for(int i=0; i<ArraySize(this.watchlist); i++){
      if(this.watchlist[i].id==setup.id){
         log("Watcher::Add() Cannot add TradeSetup with duplicate ID#"+(string)setup.id);
         return -1;
      }
   }

   ArrayResize(this.watchlist, ArraySize(this.watchlist)+1);
   this.watchlist[ArraySize(this.watchlist)-1]=setup;
   log("Watcher added TradeSetup ID: "+setup.id+
      " (Total: "+(string)ArraySize(this.watchlist)+")");
   return 1;
}

//+---------------------------------------------------------------------------+
int Watcher::Rmv(TradeSetup* setup){
   for(int i=0; i<ArraySize(this.watchlist); i++){
      if(watchlist[i].id!=setup.id)
         continue;
      
      TradeSetup* tmp[];
      ArrayCopy(tmp,watchlist,0,0,WHOLE_ARRAY);
      ArrayFree(watchlist);

      for(int j=0; j<ArraySize(tmp); j++){
         if(tmp[j].id==setup.id)
            continue;
            
         ArrayResize(this.watchlist, ArraySize(this.watchlist)+1);
         this.watchlist[ArraySize(watchlist)-1]=tmp[j];  
      
         log("Watcher removed TradeSetup ID#"+setup.id+
            " ("+(string)ArraySize(tmp)+"-->"+(string)ArraySize(this.watchlist)+").");
         return 1;
      }   
   }
      
   log("Watcher::Rmv() Error: TradeSetup ID: "+setup.id+" not found in watchlist.");
   return -1;
}

//+---------------------------------------------------------------------------+
int Watcher::RmvAll(){
   ArrayFree(this.watchlist);
   log("Watcher watchlist cleared (Total: "+(string)ArraySize(this.watchlist)+").");
   return 1;
}

//+---------------------------------------------------------------------------+
int Watcher::PauseAll(){
   return -1;
}

//+---------------------------------------------------------------------------+
//| Evaluate/execute TradeSetups in watchlist
//+---------------------------------------------------------------------------+
int Watcher::TickUpdate(OrderManager* OM){
   int n_err=0, n_validated=0, n_invalidated=0;
   
   for(int i=0; i<ArraySize(this.watchlist); i++){
      TradeSetup* setup=this.watchlist[i];
      
      SetupState s=setup.Eval();
      
      if(s==PENDING)
         continue;
      
      if(s==INVALIDATED){
         this.Rmv(setup);
         n_invalidated++;
         log("Watcher invalidated TradeSetup #"+(string)setup.id+
            ". Removed from watchlist.");
      }  
      // Execute setup trade if conditions are met
      else if(s==VALIDATED){
         Order* o=setup.order;
         int ticket=OM.OpenPosition(o.Symbol,o.Type,0.0,o.Lots,o.Tp,o.Sl);
         this.Rmv(setup);
         n_validated++;
         
         if(ticket==-1){
            log("Watcher error executing TradeSetup ID#"+(string)setup.id+" order.");
            n_err++;
            continue;
         }
         else {
            log("Watcher validated TradeSetup #"+(string)setup.id+". "+
               "Executed Order ID#"+(string)ticket+" . Rmv'd from watchlist.");
         }
      }
   }
   
   log("Updated TradeSetup watchlist. Validated:"+(string)n_validated+
      ", Invalidated:"+(string)n_invalidated+
      ", Active:"+(string)ArraySize(this.watchlist)+
      ". Generated "+(string)n_err+" errors.");
   
   return -1;
}