#pragma  warning( disable : 4250 )
        
#include <ctype.h>
#include <windows.h>
#include <windowsx.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h> 
#include <io.h> 
#include "readdata.hpp" 
#include "scenenum.h"

#define is_space(ch) (isspace(ch)||(ch=='\n'))

struct SectionList
{
	char  SectionName[40];
	long  SectionOffset;
}Section[40];

char * NameSection;
int   NumSections;
BOOL  FColchetes = FALSE; // Verifica se já encontrou o colchete
char  FirstChar; // acumula o primeiro caracter da linha
BOOL  FNameLine = TRUE;
 	
	
BOOL Error( char *Msg, char *Arg )
{
	MessageBox(NULL, Msg,"Erro Fatal!", MB_OK);
	
	return FALSE;
}

/*
int PASCAL WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR szCmdLine, int cmdShow)
{
	HFILE HandleArch;
	int Number,X,Y,NumSprites,_3DOriginX,_3DOriginY,_3Dw,_3Dh,_3Dd,NumTimer,PerTimer,DeltaX,DeltaY;
	int NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,Cor,_3Dz0,PlayerX,PlayerY;
	int ScreenX,ScreenY,ScreenW,ScreenH,VanishX,VanishY,ViewX,ViewY,View_x,View_y,View_z,AxisX,AxisY;
	int LinhaSup,ColunaSup,LinhaLatEsq,ColunaLatEsq,DeltaLatEsq,LinhaLatDir,ColunaLatDir,DeltaLatDir;
	char NomeBMP[9],InitialScene[9],ScreenBMP[9],Name[9],SceneInName[9];
	BOOL HasPlayer,HasControlPanel,HasStatusBar,Is1Animation,IsClickExit;				      
	BYTE i;
    
	HandleArch = AbreArquivo("casseta.ini");       // abre o arquivo .ini e coloca o ponteiro 
	if(!HandleArch)								   // no início da primeira linha da sessão 		
	{
		return Error( "Não consegui ler o PLAYER" );
	}
		
	BuildSectionIndex(HandleArch);

	if(!SeekScene(HandleArch, "Casseta"))
	{
		return FALSE;
	}

	ReadFirstScene(HandleArch,Name,&HasPlayer,&HasControlPanel,&HasStatusBar, &Is1Animation, &IsClickExit);

	ReadPlayer(HandleArch,&Number,&X,&Y,&NumSprites,NomeBMP,&_3DOriginX,&_3DOriginY,
				&_3Dw,&_3Dh,&_3Dd,&NumTimer,&PerTimer,&DeltaX,&DeltaY);

	for( i=0; i<NumSprites; i++ )
	{                   
		ReadSprite(HandleArch,&NumFrames,&FrameW,&FrameH,&BoundX,&BoundY,&BoundW,&BoundH);
    	
		MontaNome(NomeBMP,i);
		 
	}
	ReadControlPanel(HandleArch,&X,&Y,NomeBMP,&NumFrames,&FrameW,&FrameH,&NumTimer,&PerTimer);
	ReadStatusBar(HandleArch,&X,&Y,&Cor,NomeBMP,&FrameW,&FrameH);
	while( BeginSameName() )
	{
		ReadPortable(HandleArch,&Number,InitialScene,&X,&Y,NomeBMP,&FrameW,&FrameH,&BoundX,
						&BoundY,&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,&_3Dw,&_3Dh,&_3Dd,
						&_3Dz0,&NumTimer,&PerTimer);

	}
 	SetOutBlock();


	if(!SeekScene(HandleArch, "QuartoZe"))
	{
		return FALSE;
	}


	ReadScreen(HandleArch,&Number,ScreenBMP,&ScreenX,&ScreenY,&ScreenW,&ScreenH,
						  &VanishX,&VanishY,&ViewX,&ViewY,&View_x,&View_y,&View_z,
						  &AxisX,&AxisY );

	ReadLimits(HandleArch,&LinhaSup,&ColunaSup,&LinhaLatEsq,&ColunaLatEsq,
					  &DeltaLatEsq,&LinhaLatDir,&ColunaLatDir,&DeltaLatDir);

	do
	{                   
		while( BeginSameName() )
		{                 
		 	ReadObject(HandleArch,&Number,&X,&Y,NomeBMP,&FrameW,&FrameH,&BoundX,&BoundY,
		 				&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,&_3Dw,&_3Dh,&_3Dd);
		}
	 	SetOutBlock();

		while( BeginSameName() )
		{
		 	ReadAnimated(HandleArch,&Number,&X,&Y,NomeBMP,&NumFrames,&FrameW,&FrameH,
		 					&BoundX,&BoundY,&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,
		 					&_3Dw,&_3Dh,&_3Dd,&NumTimer,&PerTimer);
		}
	 	SetOutBlock();

		while( BeginSameName() )
		{
		 	ReadExit(HandleArch,&Number,&X,&Y,NomeBMP,&NumFrames,&FrameW,&FrameH,&BoundX,&BoundY,
		 			&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,&_3Dw,&_3Dh,&_3Dd,&NumTimer,&PerTimer,
		 			SceneInName,&PlayerX,&PlayerY,&HasPlayer,&HasControlPanel,&HasStatusBar);
		}
	 	SetOutBlock();
	}		
	while(!EndScene() );
	SetOutScene();

	return NULL;
}	

*/
BOOL BuildSectionIndex( HFILE HandleArch )
{
	static int i = 0;                                
	char buffer[80];
	char ch;
	
	for(;;)
	{   
		ch = SkipSeparators( HandleArch, FALSE );
        
        if (ch == '\0')
        	break;
        	
        else
		if( ch == '[' )
		{
//			SkipChar( HandleArch );
			
			ReadStr( HandleArch, buffer, ']' );
			
			strcpy( Section[i].SectionName, buffer );
            
            SkipLine( HandleArch );
            
			Section[i++].SectionOffset = _lseek(HandleArch, 0L, SEEK_CUR);  
		}
		else
		{
		 	SkipLine( HandleArch );
		}		                                   
	}
	                      
	NumSections = i;
		                      
	return TRUE;
}

long FindSectionOffset(char * NameSection)
{                                 
	for( int i = 0; i < NumSections; i++ )
	{
	 	if( stricmp(Section[i].SectionName, NameSection) == 0 )
	 	{
	 		return Section[i].SectionOffset;
	 	}
//	 	if( stricmp(SectionNames[i], NameSection) == 0 )
//	 	{
//	 		return SectionOffsets[i];
//	 	}
	}                   
	return -1L;
}
	
                     
// Faz com que o ponteiro de leitura pule os caracteres separadores
char SkipSeparators( HFILE HandleArch, BOOL ErrorAtEnd)
{
	char ch;
	
   	do
   	{
    	if( _lread(HandleArch, &ch, 1) == 0 )
    	{   
    		                                   
//    		if( ErrorAtEnd )                
//    		{
//    			Error( "Fim de arquivo não esperado!");
//    		}
    		
    		return '\0';
    	}                         
    	
    	if( ch == ';' )
    	{
    		ch = Comment(HandleArch);
    	}
   	}                     
   	while(is_space(ch));
    
    FirstChar = ch; // acumula o primeiro caracter da linha
    
   	return ch;
}


char Comment( HFILE HandleArch )
{   
	return SkipLine( HandleArch );
}

// le e coloca no buffer até encontrar o fim de linha
char SkipLine( HFILE HandleArch, char *Buffer )
{
	char ch;                                         
	int i = 0;
	
   do
   {
    	if( _lread(HandleArch, &ch, 1) == 0 )
    	{
    		Error( "Fim de arquivo não esperado!");
    		return '\0';
    	}                                          
    	else
    	if( Buffer != NULL )
    	{
    	 	Buffer[i++] = ch;
    	}
   }                     
   while((ch!='\r') && (ch!='\n'));

	if( Buffer != NULL )
	{
	 	Buffer[i] = '\0';
	}
   
/*   if( ch == '\r' )
/   {
   		SkipChar( HandleArch );
   } 

   ch =	SkipChar( HandleArch );
*/	
   return ch;
}


char SkipChar( HFILE HandleArch )
{
 	char ch;
	
	if( _lread(HandleArch, &ch, 1) == 0 )
	{
		Error( "Fim de arquivo não esperado!");
		return '\0';
	}                         
	else
	{
	   	return ch;
	}
}

// le a String até encontrar o caracter EndOfStr
BOOL ReadStr( HFILE HandleArch, char *Buffer, char EndOfStr )
{
	char ch;
    int i = 0;
    
	for(;;)
	{	 
    	if( _lread(HandleArch, &ch, 1) == 0 )
    	{
    		return Error("Fim de arquivo não esperado!");
    	}
		if(ch != EndOfStr)
		{                        
		   	if(!is_space(ch)) 
		   	{               
		   		Buffer[i++] = tolower(ch);
	   	   	}                 
	   	}
	   	else
	   	{   
			Buffer[i] = '\0';
			break;
		}   	   	
	}   	   	          

	return TRUE;
}


BOOL SearchLine(HFILE HandleArch, char * NameLine)
{                               
	char  buffer[255];
	char  ch;
//	long  offset;  
          
//	offset = FindSectionOffset(NameSection);

//	_lseek(HandleArch, offset, SEEK_SET);  	
	FColchetes = FALSE;
	FNameLine = TRUE;
	
	for(;;)
	{   
		ch = SkipSeparators( HandleArch );

		if( ch == '[' )
		{   
			FNameLine = FALSE;
			FColchetes = TRUE;
			return FALSE; //Error( "Linha %s não encontrada na sessão", NameLine );
		}				
		_lseek(HandleArch, -1L, SEEK_CUR); // posiciono o ponteiro uma pos atras  		
		
		if(NameLine[0] != FirstChar) 
		{
			FNameLine = FALSE;
			return FALSE;
		}

		ReadStr( HandleArch, buffer, '=' );
		
		if( stricmp(buffer, NameLine) == 0 )
		{
			break;
		}		                           
		else
		{   
		 	SkipLine( HandleArch );
		}		                                   
	}
	    
	return TRUE;
    
}


// Abre o arquivo e posiciona o ponteiro na sessão requisitada
HFILE AbreArquivo(char * name)
{ 
	char 				szPath[_MAX_PATH];
    HFILE               fh;
    OFSTRUCT            of;    
    
	  // lê qual é o drive do cd-rom                  
	_fullpath(szPath, name, sizeof(szPath));
			  
    fh = OpenFile(szPath, &of, OF_READ); 

    if (fh == -1)
    {
	    _lclose(fh);
        return NULL;
    }

    return (fh);
}

void FechaArquivo(HFILE fh)
{
    _lclose(fh);
}

// Posiciona o ponteiro na proxima sessão
BOOL  SeekScene(HFILE HandleArch, char* NameSection)                  
{                                  
	long offset;
	
	offset = FindSectionOffset(NameSection);
	if(offset == -1L)
	{
		Error( "Não consegui encontrar a sessão procurada");
		return FALSE;
	}
	_lseek(HandleArch, offset, SEEK_SET);  	
	
	return TRUE;
}


// Acrescenta um número no final de uma palavra                           
char* MontaNome(char* Nome,int Num)
{   
	static char NomeResult[20];

    if ( Num == -1 ) 	
    {
		sprintf(NomeResult,"%s.bmp",Nome);
    }
	else
	{
		sprintf(NomeResult,"%s%d.bmp",Nome,Num);
	}
	
	return (NomeResult);
}
                           
char LookChar(HFILE HandleArch )
{
	char ch;

	ch = SkipSeparators( HandleArch );
	_lseek(HandleArch, -1L, SEEK_CUR); // posiciono o ponteiro uma pos atras  		

	return ch;
}
                           
// Lê o conteúdo da linha Player=
BOOL ReadPlayer(HFILE HandleArch,int *Number,int *X,int *Y,int *NumSprites,char* NomeBMP,int *_3DOriginX,int *_3DOriginY,
				int *_3Dw,int *_3Dh,int *_3Dd,int *NumTimer,int *PerTimer,int *DeltaX,int *DeltaY)
{
	char buffer[256];
	BYTE i;
	

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "Player"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
    
	i = sscanf(buffer,"%d,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d",
						Number,X,Y,NumSprites,NomeBMP,_3DOriginX,_3DOriginY,
						_3Dw,_3Dh,_3Dd,NumTimer,PerTimer,DeltaX,DeltaY);

	if( i != 14 )
	{
		Error( "Não consegui ler todos os campos do Player!");
		return FALSE;
	}
	
	return TRUE;							
	    
}

// Lê o conteúdo da linha Sprite=
BOOL ReadSprite(HFILE HandleArch,int *NumFrames,int *FrameW,int *FrameH,int *BoundX,int *BoundY,int *BoundW,int *BoundH)
{            
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "Sprite"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
                                             
	i = sscanf(buffer,"%d,%d,%d,%d,%d,%d,%d",NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH);

	if( i != 7 )
	{
		Error( "Não consegui ler todos os campos do Sprite!");
		return FALSE;
	}
	
	return TRUE;							
}

// Lê o conteúdo da linha ControlPanel=
BOOL ReadControlPanel(HFILE HandleArch,int *X,int *Y,char* NomeBMP,int *NumFrames,int *FrameW,int *FrameH,int *NumTimer,int *PerTimer)
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "ControlPanel"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
    
	i = sscanf(buffer,"%d,%d,%s ,%d,%d,%d,%d,%d",X,Y,NomeBMP,NumFrames,FrameW,FrameH,NumTimer,PerTimer);

	if( i != 8 )
	{
		Error( "Não consegui ler todos os campos do ControlPanel!");
		return FALSE;
	}
	
	return TRUE;							

}

// Lê o conteúdo da linha StatusBar=
BOOL ReadStatusBar(HFILE HandleArch,int *X,int *Y,int *Cor,char* NomeBMP,int *FrameW,int *FrameH)
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "StatusBar"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
    
	i = sscanf(buffer,"%d,%d,%d,%s ,%d,%d",X,Y,Cor,NomeBMP,FrameW,FrameH);

	if( i != 6 )
	{
		Error( "Não consegui ler todos os campos do StatusBar!");
		return FALSE;
	}
	
	return TRUE;
}

// Lê o conteúdo da linha FirstScene=
BOOL ReadFirstScene(HFILE HandleArch,char* Name,BOOL *HasPlayer,BOOL *HasControlPanel,BOOL *HasStatusBar,
											BOOL *Is_1Animation,BOOL *Is_ClickExit )
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "FirstScene"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
    
	i = sscanf(buffer,"%s ,%d,%d,%d,%d,%d",Name,HasPlayer,HasControlPanel,HasStatusBar,Is_1Animation,Is_ClickExit);

	if( i != 6 )
	{
		Error( "Não consegui ler todos os campos da FirstScene!");
		return FALSE;
	}
	
	return TRUE;
}    


// Lê o conteúdo da linha Portable=
BOOL ReadPortable(HFILE HandleArch,int *Number,char* InitialScene,int *X,int *Y,char* NomeBMP,int *FrameW,int *FrameH,int *BoundX,
				  int *BoundY,int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dw,int *_3Dh,
				  int *_3Dd,int *_3Dz0,int *NumTimer,int *PerTimer)
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "Portable"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
                                                                
	i = sscanf(buffer,"%d,%s ,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",Number,InitialScene,
				X,Y,NomeBMP,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,_3DOriginX,_3DOriginY,
				_3Dw,_3Dh,_3Dd,_3Dz0,NumTimer,PerTimer);

	if( i != 19 )
	{
		Error( "Não consegui ler todos os campos do Portable!");
		return FALSE;
	}
	
	return TRUE;							
	    
}				  


BOOL ReadLimits(HFILE HandleArch,int *LinhaSup,int *ColunaSup,int *LinhaLatEsq,int *ColunaLatEsq,
					  int *DeltaLatEsq,int *LinhaLatDir,int *ColunaLatDir,int *DeltaLatDir)
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "Limits"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
                                                                
	i = sscanf(buffer,"%d,%d,%d,%d,%d,%d,%d,%d",LinhaSup,ColunaSup,LinhaLatEsq,ColunaLatEsq,
					  		DeltaLatEsq,LinhaLatDir,ColunaLatDir,DeltaLatDir);

	if( i != 8 )
	{
		Error( "Não consegui ler todos os campos do Limits!");
		return FALSE;
	}
	
	return TRUE;							


}					 		
                     
// Lê o conteúdo da linha Screen=
BOOL ReadScreen(HFILE HandleArch,int *Number,char* ScreenBMP,int *ScreenX,int *ScreenY,int *ScreenW,int *ScreenH, 
				int *VanishX, int *VanishY,int *ViewX,int *ViewY,int *View_x,int *View_y,int *View_z,
				int *AxisX,int *AxisY )
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "Screen"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
                                                                
	i = sscanf(buffer,"%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",Number,ScreenBMP,ScreenX,ScreenY,
				ScreenW,ScreenH,VanishX,VanishY,ViewX,ViewY,View_x,View_y,View_z,AxisX,AxisY);

	if( i != 15 )
	{
		Error( "Não consegui ler todos os campos do Screen!");
		return FALSE;
	}
	
	return TRUE;							

}				


// Lê o conteúdo da linha Local=
BOOL ReadObject(HFILE HandleArch,int *Number,int *X,int *Y,char* NomeBMP,int *FrameW,int *FrameH,int *BoundX,int *BoundY,
				int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dx,int *_3Dy,int *_3Dz)
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "Local"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
                                                                
	i = sscanf(buffer,"%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",Number,X,Y,NomeBMP,FrameW,FrameH,BoundX,
				BoundY,BoundW,BoundH,_3DOriginX,_3DOriginY,_3Dx,_3Dy,_3Dz);

	if( i != 15 )
	{
		Error( "Não consegui ler todos os campos do Local!");
		return FALSE;
	}
	
	return TRUE;							

}		   


// Lê o conteúdo da linha Animated=
BOOL ReadAnimated(HFILE HandleArch,int *Number,int *X,int *Y,char* NomeBMP,int *NumFrames,int *FrameW,int *FrameH,int *BoundX,
			 int *BoundY,int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dx,int *_3Dy,int *_3Dz,
			 int *NumTimer,int *PerTimer)
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "Animated"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
                                                                
	i = sscanf(buffer,"%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",Number,X,Y,NomeBMP,NumFrames,
				FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,_3DOriginX,_3DOriginY,_3Dx,_3Dy,
				_3Dz,NumTimer,PerTimer);

	if( i != 18 )
	{
		Error( "Não consegui ler todos os campos do Animated!");
		return FALSE;
	}
	
	return TRUE;							
}			 

// Lê o conteúdo da linha Static
BOOL ReadStatic(HFILE HandleArch,int *Number,int *X,int *Y,char* NomeBMP,int *NumFrames,int *FrameW,int *FrameH,int *BoundX,
			 int *BoundY,int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dx,int *_3Dy,int *_3Dz,
			 int *NumTimer,int *PerTimer)
{
	char buffer[256];
	BYTE i;

	buffer[0] = '\0';		
	                
	if(!SearchLine(HandleArch, "Static"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
                                                                
	i = sscanf(buffer,"%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",Number,X,Y,NomeBMP,NumFrames,
				FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,_3DOriginX,_3DOriginY,_3Dx,_3Dy,
				_3Dz,NumTimer,PerTimer);

	if( i != 18 )
	{
		Error( "Não consegui ler todos os campos do Static!");
		return FALSE;
	}
	
	return TRUE;							
}			 



// Lê o conteúdo da linha Exit=
BOOL ReadExit(HFILE HandleArch,int *Number,int *X,int *Y,char* NomeBMP,int *NumFrames,int *FrameW,int *FrameH,int *BoundX,
			  int *BoundY,int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dx,int *_3Dy,int *_3Dz,
			  int *NumTimer,int *PerTimer,char* SceneInName,int *PlayerX,int *PlayerY,BOOL *HasPlayer,
			  BOOL *HasControlPanel,BOOL *HasStatusBar,BOOL *Is_1Animation,BOOL *Is_ClickExit)
{
	char buffer[256];                                   
	BYTE i;

	buffer[0] = '\0';		
	                
		                
	if(!SearchLine(HandleArch, "Exit"))
	{
		return FALSE;
	}	                

    SkipLine( HandleArch, buffer );
                                                                
	i = sscanf(buffer,"%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d",
				Number,X,Y,NomeBMP,NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,_3DOriginX,
				_3DOriginY,_3Dx,_3Dy,_3Dz,NumTimer,PerTimer,SceneInName,PlayerX,PlayerY,
				HasPlayer,HasControlPanel,HasStatusBar,Is_1Animation,Is_ClickExit);

	if( i != 26 )
	{
		Error( "Não consegui ler todos os campos do Exit!");
		return FALSE;
	}
	
	return TRUE;							

}			                                                       
/*
// diz se a linha seguinte ainda se inicia pelo mesmo nome
BOOL BeginPortable(void)
{   
	return FNameLine;
}
BOOL BeginAnimated(void)
{   
	return FNameLine;
}
BOOL BeginExit(void)
{   
	return FNameLine;
}
BOOL BeginStatic(void)
{   
	return FNameLine;
}
BOOL BeginObject(void)
{   
	return FNameLine;
}
// Verifica se terminou a sessão
BOOL EndScene(void)
{
	return FColchetes;	
}
void SetOutBlock(void)
{
	FNameLine = TRUE;
}
void SetOutScene(void)
{
	FColchetes = FALSE;
}
*/
long  SavePos(HFILE HandleArch)
{
	return _tell(HandleArch);
}

void  RestPos(HFILE HandleArch, long pos)
{
	_lseek(HandleArch, pos, SEEK_SET);
}
