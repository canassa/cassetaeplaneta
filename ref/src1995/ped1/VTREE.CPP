
#include <windows.h>
#include "mmsystem.h" 


#include <io.h>
#include <conio.h>
#include <stdio.h>
#include <stdlib.h>
#include <dos.h>
#include <bios.h>
#include <fcntl.h>
#include <memory.h>
#include <malloc.h>
#include <math.h>
#include <limits.h>
#include <string.h>
#include <graph.h>  // we'll use microsofts stuff for this progrom


#include "games.hpp"
#include "event.hpp"

#include "screen.hpp"
#include "object.hpp"


#include "3dscreen.hpp"
#include "3dobject.hpp"

/*
#include "scene.hpp"
#include "ctrpanel.hpp"
#include "applicat.hpp"
*/

// #define LONG	long

#include "vtree.h"




void object_node::Show( screen *Screen )
{
	Obj->Show();
};


object_tree::object_tree(void)
{
	Root = NULL;
	New  = Tree;
    	
 	Tree[0].l = NULL;
 	Tree[0].r = &Tree[1];
 	Tree[0].Obj = NULL;

	for( int i = 1; i < MAX_VIS_OBJ-1; i++ )
	{
	 	Tree[i].l = &Tree[i-1];
	 	Tree[i].r = &Tree[i+1];
	 	Tree[i].Obj = NULL;
	}

 	Tree[MAX_VIS_OBJ-1].l = &Tree[MAX_VIS_OBJ-2];
 	Tree[MAX_VIS_OBJ-1].r = NULL; ;
 	Tree[MAX_VIS_OBJ-1].Obj = NULL;

};


object_node * object_tree::Insert( _3D_object *Obj, screen *Screen )
{
	register object_node *Node;
	register object_node *NewNode;
		
	if( Root == NULL )
	{
		Root = New;
		New = New->r;
					  
  	    Root->Obj  = Obj;
  	    Root->l  = NULL;
  	    Root->r  = NULL;
		
  	    return Root;
  	}
  	else
  	{

		if( New == NULL )
		{
			MessageBox( "Erro Fatal!", "Estouro no número maximo de objetos visíveis na cena" );
			return NULL;
		}
		
		Node = Root;
			
		for(;;)
		{   
	  	  	if( Obj->IsCloserThan(Node->Obj, Screen) )
	  	  	{
	  	  	 	if( Node->l == NULL )
	  	  	 	{
					NewNode = Node->l = New;
					break;
				}
	  	  	 	else
	  	  	 	{
					Node = Node->l;
	  	  	 	}
	  	  	}   
	  	  	else
	  	  	{
	  	  	 	if( Node->r == NULL )
	  	  	 	{
					NewNode = Node->r = New;
					break;
	  	  	 	}
	  	  	 	else
	  	  	 	{
					Node = Node->r;					
	  	  	 	}
	  	  	}   
		}

		New = New->r;

	    NewNode->Obj  = Obj;
  	    NewNode->l  = NULL;
  	    NewNode->r  = NULL;
				
	    return(NewNode);  	  	 	
  	}
};


void object_tree::Extract( _3D_object *Obj, screen *Screen )
{
	register object_node *Node;
	register object_node *NodeAux,*Parent;

		                
	if( Root == NULL )
	{
		return;
	}
			                
	Node = Root;
				 
	for(;;)
	{
		if( Obj->Name == Node->Obj->Name )
		{
			NodeAux = Node;
				
			while( NodeAux->r != NULL )
			{
			    Parent = NodeAux;
			    NodeAux = NodeAux->r;
			}
				
			Parent->r = NodeAux->l;
				
            Node->Obj = NodeAux->Obj;
                
            NodeAux->Obj = NULL;
            NodeAux->r = New;
            New = NodeAux;
		}
		else
		{
	  	  	if( Obj->IsCloserThan(Node->Obj, Screen) )
	  	  	{
	  	  	 	if( Node->l == NULL )
	  	  	 	{
					break;
				}
	  	  	 	else
	  	  	 	{
					Node = Node->l;
	  	  	 	}
	  	  	}   
	  	  	else
	  	  	{
	  	  	 	if( Node->r == NULL )
	  	  	 	{
					break;
	  	  	 	}
	  	  	 	else
	  	  	 	{
					Node = Node->r;
	  	  	 	}
	  	  	}   
		}	  	  
	}

};


void object_tree::Show( register object_node *Node, register screen *Screen )
{                                    
  	if( Node != NULL )
  	{
		Show( Node->r, Screen );
		Node->r = NULL;
			
		Node->Show(Screen);
			
		Show( Node->l, Screen );
		Node->l = NULL;
	}
};
        
void object_tree::Show( register screen *Screen )
{              
	Show( Root, Screen );                      
};

        
object_ordlist::object_ordlist(void)
{
	First = NULL;
	New  = List;
    	
 	List[0].l = NULL;
 	List[0].r = &List[1];
 	List[0].Obj = NULL;

	for( int i = 1; i < MAX_VIS_OBJ-1; i++ )
	{
	 	List[i].l = &List[i-1];
	 	List[i].r = &List[i+1];
	 	List[i].Obj = NULL;
	}

 	List[MAX_VIS_OBJ-1].l = &List[MAX_VIS_OBJ-2];
 	List[MAX_VIS_OBJ-1].r = NULL; ;
 	List[MAX_VIS_OBJ-1].Obj = NULL;

};


object_node * object_ordlist::Insert( _3D_object *Obj, screen *Screen )
{
	register object_node *Node;
	register object_node *Prev;
	register object_node *NewNode;

	if( Obj == NULL )
	{
		return NULL;
	}
	else		
	if( First == NULL )
	{
		First = New;
		New = New->r;
					  
  	    First->Obj  = Obj;
  	    First->l  = NULL;
  	    First->r  = NULL;
		
  	    return First;
  	}
  	else
  	{
        Prev = NULL;
		Node = First;
			
		while( Node != NULL )
		{   
	  	  	if( Obj->Name == Node->Obj->Name )
	  	  	{
				return Node;
			}
			else
	  	  	if( Obj->IsCloserThan(Node->Obj, Screen) )
	  	  	{
	  	  		Prev = Node;
				Node = Node->r;					
			}
			else
			{
				break;	 	
			}         
		}

		if( New == NULL )
		{
			MessageBox( "Erro Fatal!", "Estouro no número maximo de objetos visíveis na cena" );
			return NULL;
		}
		
		if( Prev != NULL )
		{
			NewNode = Prev->r = New;
		}
		else
		{
			NewNode = First = New;
		}			

		New = New->r;
	
		if( Node != NULL )
		{
			Node->l = NewNode;
   		}
	
  	    NewNode->l  = Prev;
  	    NewNode->r  = Node;
	    NewNode->Obj  = Obj;
		
				
	    return(NewNode);  	  	 	
  	}
};


void object_ordlist::Extract( _3D_object *Obj )
{
	register object_node *Node;
	register object_node *Prev = NULL;

		                
	if( Obj == NULL )
	{
		return;
	}
	else		
	if( First == NULL )
	{
		return;
	}
	else
	{			                
		Node = First;
					 
		while( Node != NULL )
		{
			if( Obj->Name == Node->Obj->Name )
			{       
				break;
			}
			else
			{
			    Prev = Node;
			    Node = Node->r;
			}
		}
					
		if( Node != NULL )
		{
			if( Prev != NULL )
			{
				Prev->r = Node->r;
			}
			else
			{
				First = Node->r;			
			}	     
							             
			if( Node->r != NULL )
			{
			 	Node->r->l = Prev;
			}					  
						           
	        Node->Obj = NULL;
	        Node->r = New;
	        Node->l = NULL; 
	        New->l = Node;
	        New = Node;
	    }
	}
};


void object_ordlist::Show( register object_node *Node, register screen *Screen )
{                                    
  	while( Node != NULL )
  	{
		Node->Show(Screen);
	    Node = Node->r;
	}
};
        
void object_ordlist::Show( register screen *Screen )
{              
//	Show( First, Screen );                           

	register object_node *Node = First;

  	while( Node != NULL )
  	{
		Node->Show(Screen);
	    Node = Node->r;
	}
};

        
