

typedef enum { _AND, _OR } operation;


class event
{ 
public:
	virtual boolean HasOccurred( void ) = 0;

	virtual boolean Occur( void )
	{           
		return false;
	};         	   
	
	virtual boolean Reset( void )
	{           
		return false;
	};
	
	event & operator && ( event &e );
	event & operator || ( event &e );
};



class primitive_event : public event
{   
protected:

	boolean State;
	
public:
	    
	primitive_event( boolean _State = false )
	{
		State = _State;
	}

	virtual boolean Occur( void )
	{           
		State = true;
		return true;
	};         	   
	
	virtual boolean Reset( void )
	{           
		State = false;
		return true;
	};
	
	virtual boolean HasOccurred( void )
	{
	 	return State;
	};
	
};	

class compound_event : public event
{
protected:

	event	*e1,*e2;
	operation oper;	
	
public:

	compound_event( event *_e1, event *_e2, operation _oper = _AND )
	{
	 	e1 = _e1;
	 	e2 = _e2;                                      
	 	oper = _oper;
	};
      
	~compound_event( void )
	{
	 	delete e1;
	 	delete e2;
	};
      
      
	virtual boolean HasOccurred( void )
	{
		if( oper == _AND )
		{
	 		return (boolean) (e1->HasOccurred() && e2->HasOccurred());
	 	}
	 	else
		{
	 		return (boolean) (e1->HasOccurred() || e2->HasOccurred());
	 	}
	 	
	};
	
};
	


#ifdef _EVENT

	primitive_event Always(true);
	primitive_event Never(false);	

#else

	extern primitive_event Always;
	extern primitive_event Never;	

#endif			