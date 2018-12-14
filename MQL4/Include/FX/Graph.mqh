//+----------------------------------------------------------------------------+
//|                                                               FX/Graph.mqh |
//|                                                 Copyright 2018, Sean Estey |
//+----------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict

#include <Generic/HashMap.mqh>
#include <FX/Logging.mqh>

//|-----------------------------------------------------------------------------+
//| Template graph node
//|-----------------------------------------------------------------------------+
class Node {
   public:
      string Id, PointId, LabelId;
      int Shift;
      Node *Prev, *Next;                    
   public:
      Node(int shift) {
         this.Prev=NULL;
         this.Next=NULL;
         this.Shift=shift;
         this.Id=(string)(long)iTime(NULL,0,this.Shift);
         this.PointId=this.Id+"_point";
         this.LabelId=this.Id+"_label";
      }
      ~Node() {}
      string ToString() {return "";}
};

//|-----------------------------------------------------------------------------+
//| Template graph edge between two nodes
//|-----------------------------------------------------------------------------+
class Link {
   public:
      string Id, LineId, LabelId;
      Node *n1,*n2;
      string Description;
   public:
      Link(Node* node1, Node* node2, string description) {
         this.Id=this.CreateKey(node1,node2);
         this.LineId=this.Id+"_line";
         this.LabelId=this.Id+"_label";
         this.n1=node1;
         this.n2=node2;
         this.Description=description;
      }
      string CreateKey(Node *n1, Node *n2){
         return (string)MathMax((long)n1.Id,(long)n2.Id) + (string)MathMin((long)n1.Id,(long)n2.Id);
      }
      ~Link() {}
};

//|-----------------------------------------------------------------------------+
//| Template node+edge graph implementing hashmaps.
//|-----------------------------------------------------------------------------+
class Graph {
   public:
      CHashMap<string,Node*> nodes;
      Node *FirstNode,*LastNode;
      CHashMap<string,Link*> links;
      Link *FirstLink,*LastLink;
   public:
      Graph(){
         log(this.ToString());
      }
      ~Graph(){
         this.nodes.Clear();
         this.links.Clear();  
      }
      void AddNode(Node* n) {
         if(this.nodes.Add(n.Id,n)) {
            if(this.nodes.Count()==1){
               n.Prev=NULL;
               n.Next=NULL;
               this.FirstNode=n;
               this.LastNode=n;
            }
            else {
               n.Prev=this.LastNode;
               n.Next=NULL;
               this.LastNode.Next=n;
               this.LastNode=n;
            }
            //log("Node added (Id:"+n.Id+"). Total graph nodes:"+(string)this.nodes.Count());
         }
         else
            log("Node not added. Desc:"+err_msg());
      }
      bool HasNode(Node* n) {
         return this.nodes.ContainsValue(n)? true: false;
      }
      bool HasNode(string key) {
         return this.nodes.ContainsKey(key)? true: false;
      }
      void AddLink(Link* link) {
         bool r=this.links.Add(link.Id,link);
         if(r){
            // log("Link added (Id:"+link.Id+"). Total graph links:"+(string)this.links.Count());
         }
         else
            log("Link not added. Desc:"+err_msg());
      }
      void RmvLink(Link* link){
         string key=link.n1.Id+link.n2.Id;
         int s1=this.links.Count();
         this.links.Remove(key);
         log("Link removed. Count prior:"+(string)s1+", count after:"+(string)this.links.Count());
      }
      bool HasLink(Node* n1, Node* n2) {
         string key=(string)MathMax((long)n1.Id,(long)n2.Id) + (string)MathMin((long)n1.Id,(long)n2.Id);
         return this.links.ContainsKey(key)? true: false;
      }
      string ToString() {
         return "Graph has "+(string)this.nodes.Count()+" nodes, "+(string)this.links.Count()+" edges.";
      }
};