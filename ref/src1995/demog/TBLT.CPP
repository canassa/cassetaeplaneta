/**************************************************************************

    TBLT.C - transparent blt

 **************************************************************************/
/**************************************************************************

    (C) Copyright 1994 Microsoft Corp.  All rights reserved.

    You have a royalty-free right to use, modify, reproduce and 
    distribute the Sample Files (and/or any modified version) in 
    any way you find useful, provided that you agree that 
    Microsoft has no warranty obligations or liability for any 
    Sample Application Files which are modified. 

 **************************************************************************/

#include <stdlib.h>
#include <windows.h>
#include <windowsx.h>
#include <wing.h>

#include "utils.h"   
#include "tblt.h"

#if defined(__cplusplus)
extern "C" {
#endif


extern  void PASCAL far TransCopyDIBBits( WORD DestSelector, DWORD DestOffset,
  void const far *pSource, DWORD Width, DWORD Height, long DestWidth,
  long SourceWidth, char unsigned TransparentColor );

extern  void PASCAL far CopyDIBBits( WORD DestSelector, DWORD DestOffset,
  void const far *pSource, DWORD Width, DWORD Height, long DestWidth,
  long SourceWidth);


#if defined(__cplusplus)
	}
#endif 


/*------------------------------------------------------------------------------

	This function takes into account the size and origin of the source. 
	It assumes that the source is a bottom-up DIB and the destiny may be either
	a top-down or bottom-up DDB.

*/
 
BOOL TranspDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int Width , int Height, 
  int iUsage, char unsigned TransparentColor )
{
  BOOL ReturnValue = FALSE;

  int NewDestinationXOrigin;
  int NewDestinationYOrigin;
  int DestinationDeltaX;
  int DestinationDeltaY;
//  int Width;
//  int Height;
  int NewSourceXOrigin;
  int NewSourceYOrigin;
  int Orientation = 1;
  int DestinationHeight = DibHeight(&pBufferHeader->bmiHeader);
  int SourceWidth = DibWidth(&pBitmapInfo->bmiHeader);
  int SourceHeight = DibHeight(&pBitmapInfo->bmiHeader);
  
  char unsigned huge *pSource;

  WORD DestSelector;
  DWORD DestOffset;
                 
  if( nXOriginSrc+Width > SourceWidth )
  {
  	Width = SourceWidth-nXOriginSrc;
  }
                 
  if( nYOriginSrc+Height > SourceHeight )
  {
  	Height = SourceHeight-nYOriginSrc;
  }
                 
  RECT SourceRectangle = { nXOriginDest, nYOriginDest,
    nXOriginDest + Width, nYOriginDest + Height };

  RECT DestinationRectangle;

  RECT ClippedRectangle;
  
  
  if(DestinationHeight < 0)   // check for top-down DIB
  {
    Orientation = -1;
    DestinationHeight = -DestinationHeight;
  }

  DestinationRectangle.top = 0;
  DestinationRectangle.left = 0;
  DestinationRectangle.bottom = DestinationHeight;
  DestinationRectangle.right = DibWidth(&pBufferHeader->bmiHeader);

  // intersect the destination rectangle with the destination DIB

  if(IntersectRect(&ClippedRectangle,&SourceRectangle,
    &DestinationRectangle))
  {
    // default delta scan to width in bytes
    long DestinationScanDelta = DibWidthBytes(&pBufferHeader->bmiHeader);


    NewDestinationXOrigin = ClippedRectangle.left;
    NewDestinationYOrigin = ClippedRectangle.top;

    DestinationDeltaX = NewDestinationXOrigin - nXOriginDest;
    DestinationDeltaY = NewDestinationYOrigin - nYOriginDest;

    Width = ClippedRectangle.right - ClippedRectangle.left;
    Height = ClippedRectangle.bottom - ClippedRectangle.top;

    pSource = (char unsigned huge *)pBits;

    NewSourceXOrigin = DestinationDeltaX+nXOriginSrc;
    NewSourceYOrigin = DestinationDeltaY+nYOriginSrc;

    pSource += ((long)SourceHeight - (NewSourceYOrigin + Height)) *
      (long)DibWidthBytes(&pBitmapInfo->bmiHeader)
      + NewSourceXOrigin;

    // now we'll calculate the starting destination pointer taking into
    // account we may have a top-down destination

    DestSelector = HIWORD(pBufferBits);

    if(Orientation < 0)
    {
      // destination is top-down

      DestinationScanDelta *= -1;

      DestOffset = (long)(NewDestinationYOrigin + Height - 1) *
        (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }
    else
    {
      // destination is bottom-up

      DestOffset = ((long)DestinationHeight -
        (NewDestinationYOrigin + Height))
        * (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }

    TransCopyDIBBits(DestSelector,DestOffset,pSource,Width,Height,
      DestinationScanDelta,
      DibWidthBytes(&pBitmapInfo->bmiHeader),
      TransparentColor);

    ReturnValue = TRUE;
  }

  return ReturnValue;
}
            
            
/*----------------------------------------------------------------------------

This function ignores the source origin and blts the entire source.
                     
*/

BOOL TransparentDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void const far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int iUsage, char unsigned TransparentColor )
{
  BOOL ReturnValue = FALSE;

  int NewDestinationXOrigin;
  int NewDestinationYOrigin;
  int DestinationDeltaX;
  int DestinationDeltaY;
  int Width;
  int Height;
  int NewSourceXOrigin;
  int NewSourceYOrigin;
  int Orientation = 1;
  int DestinationHeight = DibHeight(&pBufferHeader->bmiHeader);
  int SourceWidth = DibWidth(&pBitmapInfo->bmiHeader);
  int SourceHeight = DibHeight(&pBitmapInfo->bmiHeader);

  char unsigned huge *pSource;
  WORD DestSelector;
  DWORD DestOffset;

  RECT SourceRectangle = { nXOriginDest, nYOriginDest,
    nXOriginDest + SourceWidth, nYOriginDest + SourceHeight };

  RECT DestinationRectangle;

  RECT ClippedRectangle;

  if(DestinationHeight < 0)   // check for top-down DIB
  {
    Orientation = -1;
    DestinationHeight = -DestinationHeight;
  }

  DestinationRectangle.top = 0;
  DestinationRectangle.left = 0;
  DestinationRectangle.bottom = DestinationHeight;
  DestinationRectangle.right = DibWidth(&pBufferHeader->bmiHeader);

  // intersect the destination rectangle with the destination DIB

  if(IntersectRect(&ClippedRectangle,&SourceRectangle,
    &DestinationRectangle))
  {
    // default delta scan to width in bytes
    long DestinationScanDelta = DibWidthBytes(&pBufferHeader->bmiHeader);


    NewDestinationXOrigin = ClippedRectangle.left;
    NewDestinationYOrigin = ClippedRectangle.top;

    DestinationDeltaX = NewDestinationXOrigin - nXOriginDest;
    DestinationDeltaY = NewDestinationYOrigin - nYOriginDest;

    Width = ClippedRectangle.right - ClippedRectangle.left;
    Height = ClippedRectangle.bottom - ClippedRectangle.top;

    pSource = (char unsigned huge *)pBits;

    NewSourceXOrigin = DestinationDeltaX;
    NewSourceYOrigin = DestinationDeltaY;

    pSource += ((long)SourceHeight - (DestinationDeltaY + Height)) *
      (long)DibWidthBytes(&pBitmapInfo->bmiHeader)
      + DestinationDeltaX;

    // now we'll calculate the starting destination pointer taking into
    // account we may have a top-down destination

    DestSelector = HIWORD(pBufferBits);

    if(Orientation < 0)
    {
      // destination is top-down

      DestinationScanDelta *= -1;

      DestOffset = (long)(NewDestinationYOrigin + Height - 1) *
        (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }
    else
    {
      // destination is bottom-up

      DestOffset = ((long)DestinationHeight -
        (NewDestinationYOrigin + Height))
        * (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }

    TransCopyDIBBits(DestSelector,DestOffset,pSource,Width,Height,
      DestinationScanDelta,
      DibWidthBytes(&pBitmapInfo->bmiHeader),
      TransparentColor);

    ReturnValue = TRUE;
  }

  return ReturnValue;
}
            
/*------------------------------------------------------------------------------

	This function takes into account the size and origin of the source. 
	It assumes that the source is a bottom-up DIB and the destiny may be either
	a top-down or bottom-up DDB.

*/
 
BOOL PutDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int Width , int Height, 
  int iUsage )
{
  BOOL ReturnValue = FALSE;

  int NewDestinationXOrigin;
  int NewDestinationYOrigin;
  int DestinationDeltaX;
  int DestinationDeltaY;
//  int Width;
//  int Height;
  int NewSourceXOrigin;
  int NewSourceYOrigin;
  int Orientation = 1;
  int DestinationHeight = DibHeight(&pBufferHeader->bmiHeader);
  int SourceWidth = DibWidth(&pBitmapInfo->bmiHeader);
  int SourceHeight = DibHeight(&pBitmapInfo->bmiHeader);
  
  char unsigned huge *pSource;

  WORD DestSelector;
  DWORD DestOffset;
                 
  if( nXOriginSrc+Width > SourceWidth )
  {
  	Width = SourceWidth-nXOriginSrc;
  }
                 
  if( nYOriginSrc+Height > SourceHeight )
  {
  	Height = SourceHeight-nYOriginSrc;
  }
                 
  RECT SourceRectangle = { nXOriginDest, nYOriginDest,
    nXOriginDest + Width, nYOriginDest + Height };

  RECT DestinationRectangle;

  RECT ClippedRectangle;
  
  
  if(DestinationHeight < 0)   // check for top-down DIB
  {
    Orientation = -1;
    DestinationHeight = -DestinationHeight;
  }

  DestinationRectangle.top = 0;
  DestinationRectangle.left = 0;
  DestinationRectangle.bottom = DestinationHeight;
  DestinationRectangle.right = DibWidth(&pBufferHeader->bmiHeader);

  // intersect the destination rectangle with the destination DIB

  if(IntersectRect(&ClippedRectangle,&SourceRectangle,
    &DestinationRectangle))
  {
    // default delta scan to width in bytes
    long DestinationScanDelta = DibWidthBytes(&pBufferHeader->bmiHeader);


    NewDestinationXOrigin = ClippedRectangle.left;
    NewDestinationYOrigin = ClippedRectangle.top;

    DestinationDeltaX = NewDestinationXOrigin - nXOriginDest;
    DestinationDeltaY = NewDestinationYOrigin - nYOriginDest;

    Width = ClippedRectangle.right - ClippedRectangle.left;
    Height = ClippedRectangle.bottom - ClippedRectangle.top;

    pSource = (char unsigned huge *)pBits;

    NewSourceXOrigin = DestinationDeltaX+nXOriginSrc;
    NewSourceYOrigin = DestinationDeltaY+nYOriginSrc;

    pSource += ((long)SourceHeight - (NewSourceYOrigin + Height)) *
      (long)DibWidthBytes(&pBitmapInfo->bmiHeader)
      + NewSourceXOrigin;

    // now we'll calculate the starting destination pointer taking into
    // account we may have a top-down destination

    DestSelector = HIWORD(pBufferBits);

    if(Orientation < 0)
    {
      // destination is top-down

      DestinationScanDelta *= -1;

      DestOffset = (long)(NewDestinationYOrigin + Height - 1) *
        (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }
    else
    {
      // destination is bottom-up

      DestOffset = ((long)DestinationHeight -
        (NewDestinationYOrigin + Height))
        * (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }

    CopyDIBBits(DestSelector,DestOffset,pSource,Width,Height,
      DestinationScanDelta,
      DibWidthBytes(&pBitmapInfo->bmiHeader));

    ReturnValue = TRUE;
  }

  return ReturnValue;
}
            
            

BOOL CopyDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void const far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int iUsage )
{
  BOOL ReturnValue = FALSE;

  int NewDestinationXOrigin;
  int NewDestinationYOrigin;
  int DestinationDeltaX;
  int DestinationDeltaY;
  int Width;
  int Height;
  int NewSourceXOrigin;
  int NewSourceYOrigin;
  int Orientation = 1;
  int DestinationHeight = DibHeight(&pBufferHeader->bmiHeader);
  int SourceWidth = DibWidth(&pBitmapInfo->bmiHeader);
  int SourceHeight = DibHeight(&pBitmapInfo->bmiHeader);

  char unsigned huge *pSource;
  WORD DestSelector;
  DWORD DestOffset;

  RECT SourceRectangle = { nXOriginDest, nYOriginDest,
    nXOriginDest + SourceWidth, nYOriginDest + SourceHeight };

  RECT DestinationRectangle;

  RECT ClippedRectangle;

  if(DestinationHeight < 0)   // check for top-down DIB
  {
    Orientation = -1;
    DestinationHeight = -DestinationHeight;
  }

  DestinationRectangle.top = 0;
  DestinationRectangle.left = 0;
  DestinationRectangle.bottom = DestinationHeight;
  DestinationRectangle.right = DibWidth(&pBufferHeader->bmiHeader);

  // intersect the destination rectangle with the destination DIB

  if(IntersectRect(&ClippedRectangle,&SourceRectangle,
    &DestinationRectangle))
  {
    // default delta scan to width in bytes
    long DestinationScanDelta = DibWidthBytes(&pBufferHeader->bmiHeader);


    NewDestinationXOrigin = ClippedRectangle.left;
    NewDestinationYOrigin = ClippedRectangle.top;

    DestinationDeltaX = NewDestinationXOrigin - nXOriginDest;
    DestinationDeltaY = NewDestinationYOrigin - nYOriginDest;

    Width = ClippedRectangle.right - ClippedRectangle.left;
    Height = ClippedRectangle.bottom - ClippedRectangle.top;

    pSource = (char unsigned huge *)pBits;

    NewSourceXOrigin = DestinationDeltaX;
    NewSourceYOrigin = DestinationDeltaY;

    pSource += ((long)SourceHeight - (NewSourceYOrigin + Height)) *
      (long)DibWidthBytes(&pBitmapInfo->bmiHeader)
      + NewSourceXOrigin;

    // now we'll calculate the starting destination pointer taking into
    // account we may have a top-down destination

    DestSelector = HIWORD(pBufferBits);

    if(Orientation < 0)
    {
      // destination is top-down

      DestinationScanDelta *= -1;

      DestOffset = (long)(NewDestinationYOrigin + Height - 1) *
        (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }
    else
    {
      // destination is bottom-up

      DestOffset = ((long)DestinationHeight -
        (NewDestinationYOrigin + Height))
        * (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }

    CopyDIBBits(DestSelector,DestOffset,pSource,Width,Height,
      DestinationScanDelta,
      DibWidthBytes(&pBitmapInfo->bmiHeader) );
      

    ReturnValue = TRUE;
  }

  return ReturnValue;
}


            
/*
BOOL PutDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int SourceWidth , int SourceHeight, 
  int iUsage )
{
  BOOL ReturnValue = FALSE;

  int NewDestinationXOrigin;
  int NewDestinationYOrigin;
  int DestinationDeltaX;
  int DestinationDeltaY;
  int Width;
  int Height;
  int NewSourceXOrigin;
  int NewSourceYOrigin;
  int Orientation = 1;
  int DestinationHeight = DibHeight(&pBufferHeader->bmiHeader);
//  int SourceWidth = DibWidth(&pBitmapInfo->bmiHeader);
//  int SourceHeight = DibHeight(&pBitmapInfo->bmiHeader);

  char unsigned huge *pSource;
  WORD DestSelector;
  DWORD DestOffset;                                       
  
  SourceHeight = DibHeight(&pBitmapInfo->bmiHeader) > 0 ? SourceHeight : -SourceHeight;

  RECT SourceRectangle = { nXOriginDest, nYOriginDest,
    nXOriginDest + SourceWidth, nYOriginDest + SourceHeight };

  RECT DestinationRectangle;

  RECT ClippedRectangle;
  
  
  pSource = (char unsigned huge *)pBits;
  
  pSource += (((long) nYOriginSrc) * (long)DibWidthBytes(&pBitmapInfo->bmiHeader) +
  				 ((long) nXOriginSrc));
      		
  pBits = (void far *) pSource;
  
  
  if(DestinationHeight < 0)   // check for top-down DIB
  {
    Orientation = -1;
    DestinationHeight = -DestinationHeight;
  }

  DestinationRectangle.top = 0;
  DestinationRectangle.left = 0;
  DestinationRectangle.bottom = DestinationHeight;
  DestinationRectangle.right = DibWidth(&pBufferHeader->bmiHeader);

  // intersect the destination rectangle with the destination DIB

  if(IntersectRect(&ClippedRectangle,&SourceRectangle,
    &DestinationRectangle))
  {
    // default delta scan to width in bytes
    long DestinationScanDelta = DibWidthBytes(&pBufferHeader->bmiHeader);


    NewDestinationXOrigin = ClippedRectangle.left;
    NewDestinationYOrigin = ClippedRectangle.top;

    DestinationDeltaX = NewDestinationXOrigin - nXOriginDest;
    DestinationDeltaY = NewDestinationYOrigin - nYOriginDest;

    Width = ClippedRectangle.right - ClippedRectangle.left;
    Height = ClippedRectangle.bottom - ClippedRectangle.top;

    pSource = (char unsigned huge *)pBits;

    NewSourceXOrigin = DestinationDeltaX;
    NewSourceYOrigin = DestinationDeltaY;

    pSource += ((long)SourceHeight - (DestinationDeltaY + Height)) *
      (long)DibWidthBytes(&pBitmapInfo->bmiHeader)
      + DestinationDeltaX;

    // now we'll calculate the starting destination pointer taking into
    // account we may have a top-down destination

    DestSelector = HIWORD(pBufferBits);

    if(Orientation < 0)
    {
      // destination is top-down

      DestinationScanDelta *= -1;

      DestOffset = (long)(NewDestinationYOrigin + Height - 1) *
        (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }
    else
    {
      // destination is bottom-up

      DestOffset = ((long)DestinationHeight -
        (NewDestinationYOrigin + Height))
        * (long)DibWidthBytes(&pBufferHeader->bmiHeader) +
        NewDestinationXOrigin;
    }

    CopyDIBBits(DestSelector,DestOffset,pSource,Width,Height,
      DestinationScanDelta,
      DibWidthBytes(&pBitmapInfo->bmiHeader) 
      );

    ReturnValue = TRUE;
  }

  return ReturnValue;
}
            


BOOL PutDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void const far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int SourceWidth , int SourceHeight, 
  int iUsage )
{
  BOOL ReturnValue = FALSE;

  int NewDestinationXOrigin;
  int NewDestinationYOrigin;
  int DestinationDeltaX;
  int DestinationDeltaY;
  int Width;
  int Height;
  int NewSourceXOrigin;
  int NewSourceYOrigin;
  int Orientation = 1;
  int DestinationHeight = DibHeight(&pBufferHeader->bmiHeader);
//  int SourceWidth = DibWidth(&pBitmapInfo->bmiHeader);
//  int SourceHeight = DibHeight(&pBitmapInfo->bmiHeader);

  char unsigned huge *pSource;
  WORD DestSelector;
  DWORD DestOffset;

  RECT SourceRectangle = { nXOriginDest, nYOriginDest,
    nXOriginDest + SourceWidth, nYOriginDest + SourceHeight };

  RECT DestinationRectangle;

  RECT ClippedRectangle;

  
  pSource = (char unsigned huge *)pBits;
  
  pSource += (((long) nYOriginSrc) * (long)DibWidthBytes(&pBitmapInfo->bmiHeader) +
  				 ((long) nXOriginSrc));
      		
  pBits = (void far *) pSource;
  
  
  if(DestinationHeight < 0)   // check for top-down DIB
  {
    Orientation = -1;
    DestinationHeight = -DestinationHeight;
  }

  DestinationRectangle.top = 0;
  DestinationRectangle.left = 0;
  DestinationRectangle.bottom = SourceHeight; // DestinationHeight;
  DestinationRectangle.right = SourceWidth; // DibWidth(&pBufferHeader->bmiHeader);

  // intersect the destination rectangle with the destination DIB

  if(IntersectRect(&ClippedRectangle,&SourceRectangle,
    &DestinationRectangle))
  {
    // default delta scan to width in bytes
    long DestinationScanDelta = DibWidthBytes(&pBufferHeader->bmiHeader);


    NewDestinationXOrigin = ClippedRectangle.left;
    NewDestinationYOrigin = ClippedRectangle.top;

    DestinationDeltaX = NewDestinationXOrigin - nXOriginDest;
    DestinationDeltaY = NewDestinationYOrigin - nYOriginDest;

    Width = ClippedRectangle.right - ClippedRectangle.left;
    Height = ClippedRectangle.bottom - ClippedRectangle.top;

    pSource = (char unsigned huge *)pBits;

    NewSourceXOrigin = DestinationDeltaX;
    NewSourceYOrigin = DestinationDeltaY;

    pSource += ((long)SourceHeight - (NewSourceYOrigin + Height)) *
      (long)DibWidthBytes(&pBitmapInfo->bmiHeader)
      + NewSourceXOrigin;

    // now we'll calculate the starting destination pointer taking into
    // account we may have a top-down destination

    DestSelector = HIWORD(pBufferBits);

    if(Orientation < 0)
    {
      // destination is top-down

      DestinationScanDelta *= -1;

      DestOffset = (long)(NewDestinationYOrigin + Height - 1) *
        (long)DibWidthBytes(&pBufferHeader->bmiHeader) 
        + NewDestinationXOrigin;
    }
    else
    {
      // destination is bottom-up

      DestOffset = ((long)DestinationHeight -
        (NewDestinationYOrigin + Height))
        * (long)DibWidthBytes(&pBufferHeader->bmiHeader) 
        + NewDestinationXOrigin;
    }

    CopyDIBBits(DestSelector,DestOffset,pSource,Width,Height,
      DestinationScanDelta,
      DibWidthBytes(&pBitmapInfo->bmiHeader) 
      );
      

    ReturnValue = TRUE;
  }

  return ReturnValue;
}

*/