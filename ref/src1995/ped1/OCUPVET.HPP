                                  
typedef enum { FREE, BORDER, USED, BUSY } occupation;


    
class obj_elem
{
public:
	object *elem;
	obj_elem *next;
	
	obj_elem( object *_elem )
	{
		elem = _elem;
		next = NULL;
	};
};
    
class obj_list
{
public:
	obj_elem *FirstObject;
	
	obj_list( object *o )
	{                         
		FirstObject = new obj_elem(o);
	};
	 	
	obj_list( void )
	{                         
		FirstObject = NULL;
	};          
	
	~obj_list (void)
	{       
		obj_elem *e;
		
		while(FirstObject != NULL)
		{
			e = FirstObject->next;
			delete FirstObject;
			FirstObject = e;									
		}
	}
	
	obj_list *Insert( object *o )
	{
		obj_elem *e = new obj_elem(o);
		
	 	if( FirstObject == NULL )
	 	{
			FirstObject = e;
		}
		else
		{
			e->next = FirstObject;
			FirstObject = e;  		
	    }           
	    
	    return this;
	};

	boolean isEmpty( void )
	{
		return (boolean)(FirstObject == NULL);
	};
};
    
    
class occup_pair
{   
public:
	int CellNumber;
	obj_list ObjectList;

	occup_pair( void )
	{
		CellNumber = -1;
	};  
};


class occup_vector
{
public:
	occup_pair Vet[MAX_OBJ_SCENE];
	int UsedCells;
			                 
	occup_vector( void )
	{                 
		UsedCells = 0;
	};
	
	~occup_vector( void )	
	{
	};

};


class occup_matrix
{
public:
//	unsigned char far * far *Mat;
	unsigned char Mat[MAX_LINES][MAX_COLS];
	int NLines, NCols;
	HGLOBAL hMatMem;

			                 
	occupation Occupation( int X, int Y )
	{                   
		if( X < 0 || Y < 0 )
			return BUSY;
		else
		{                            
			Y >>= HEIGHT_POWER;
			X >>= WIDTH_POWER;			
	 		return (occupation) Mat[Y][X];
	 	}
	}	

	occupation Occup( uint Line, uint Col )
	{
	 	return (occupation) Mat[Line][Col];
	};	

	occupation SetOccupation( int X, int Y, occupation Occup )
	{
		if( X < 0 || Y < 0 )
			return Occup;
		else
			return (occupation) (Mat[Y>>HEIGHT_POWER][X>>WIDTH_POWER] = (unsigned char) Occup);	
	}	                                                

	occupation SetOccup( int Line, int Col, occupation Occup )
	{
		return (occupation) (Mat[Line][Col] = (unsigned char) Occup);	
	};	                                                


	occup_matrix( uint BufferWidth, uint BufferHeight )
	{      
		register int i = 0, j = 0;
		           
		NLines = 1+(BufferHeight >> HEIGHT_POWER);
		NCols  = 1+(BufferWidth  >> WIDTH_POWER); 
		
		for(i=0; i<NLines; i++)
		{
			for(j=0; j<NCols; j++)
			{
				SetOccup(i,j,FREE);
//				Mat[i][j] = ((unsigned char) FREE);
			}
		}
                 
//      hMatMem = GlobalAlloc( GMEM_ZEROINIT | GMEM_MOVEABLE, NLines * NCols );
//		Mat = (unsigned char far * far *) GlobalLock( hMatMem );
	};
	
	~occup_matrix( void )	
	{
//		GlobalUnlock( hMatMem );
//		GlobalFree( hMatMem );
	};


};


