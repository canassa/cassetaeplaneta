

#ifdef __cplusplus
extern "C" {
#endif 


BOOL TransparentDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void const far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int iUsage, char unsigned TransparentColor );

BOOL CopyDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void const far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int iUsage );
                                                            
BOOL TranspDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int SourceWidth , int SourceHeight, 
  int iUsage, char unsigned TransparentColor );
  
BOOL PutDIBits( BITMAPINFO far *pBufferHeader,
  void huge *pBufferBits,
  int nXOriginDest, int nYOriginDest, void far *pBits,
  BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
  int SourceWidth , int SourceHeight, 
  int iUsage );


#ifdef __cplusplus
		}
#endif 
                                                                        

                                                            