

#include "games.hpp"

#define _EVENT

#include "event.hpp"

#undef _EVENT 

event & event::operator && ( event & e )
{
	return *(new compound_event( this, &e, _AND ));						
};  
	
event & event::operator || ( event & e )
{
	return *(new compound_event( this, &e, _OR ));						
};  
	                             
	                             
