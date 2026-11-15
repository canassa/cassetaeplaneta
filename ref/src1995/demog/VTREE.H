

#define		MAX_VIS_OBJ		100


class object_node
{
public:
	
	_3D_object *Obj;

	object_node *l,*r;
	
	object_node(void)
	{
		l = r = NULL;
	};
	
	void Show( screen *Screen );
};


class object_tree
{
protected:	
	object_node Tree[MAX_VIS_OBJ];
	                               
	object_node *Root;   
	object_node *New;   

	
public:   
        
    object_tree(void);
        
	object_node *Insert( _3D_object *Obj, screen *Screen );

	void Extract( _3D_object *Obj, screen *Screen );

	void Show( register object_node *Node, register screen *Screen );
	
	void Show( register screen *Screen );
}; 


class object_ordlist
{
protected:	
	object_node List[MAX_VIS_OBJ];
	                               
	object_node *New;   
	
public:   
	object_node *First;   
        
    object_ordlist(void);
        
	object_node *Insert( _3D_object *Obj, screen *Screen );

	void Extract( _3D_object *Obj );

	void Show( register object_node *Node, register screen *Screen );
	
	void Show( register screen *Screen );
}; 
